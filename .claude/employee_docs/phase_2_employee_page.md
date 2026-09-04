# Phase 2 — Fondations + page Employée

Le socle du module **Gestion Employée** reconstruit, plus le premier écran : la liste du
personnel, l'ajout/modification et la fiche employé. Contrat :
`.claude/phase_gestion_employee.md`.

Fin de phase : `flutter analyze` propre, **364 tests passent**, `python tool/ux_audit.py`
→ **0 violation**.

---

## 1. Modèle de données — `lib/models/employee.dart`

Un seul modèle « personne » qui fusionne l'ancien `Employee` **et** l'ancien `TeamMember`
(décision 1). Immuable, Dart pur (pas de `TimeOfDay` — les horaires sont des `int` minutes
depuis minuit).

```dart
enum EmployeeRole { owner, manager, staff }     // Owner / Gérant / Employé
enum ContractType { fixed, extra }              // Salarié fixe / Extra

class Employee {
  final String id;
  final String storeId;                          // un seul établissement (décision 2)
  final String firstName;
  final String lastName;
  final String cin;                              // unique compte-wide, futur identifiant de login
  final String phone;
  final String email;                            // unique compte-wide
  final String? photoAsset;                      // simulé, comme Store.imageAsset
  final DateTime hireDate;
  final EmployeeRole role;
  final ContractType contractType;
  final double pay;                              // mensuel si fixed, horaire si extra
  final int? scheduledStartMinutes;              // null → horaires de l'établissement
  final int? scheduledEndMinutes;
  final DateTime createdAt;
  final DateTime? archivedAt;                    // null = actif. Seule source de vérité.
}
```

`student` a été supprimé (décision 5). Le rôle n'applique encore **aucune** permission —
Phase 6.

### Dérivations — `lib/core/utils/employee_status.dart`

`isEmployeeActive(e)`, `employeeDisplayName(e)` (« Prénom Nom »), `employeeInitials(e)`.

### `lib/core/utils/formatters.dart`

Ajout de `minutesToClock(int)` → `08:30` et `clockToMinutes(String)` → minutes | null
(accepte `8:30`, `08h30`). Nécessaire au formulaire ; réutilisé en Phase 3 pour le retard.

---

## 2. Données de démonstration — `lib/mock_data/mock_employees.dart`

Brasserie du Sablon, 8 personnes : **Marc** (owner, fixe — c'est `mockCurrentEmployee`),
**Amélie** (gérant, fixe), Karim/Fatima (staff, fixe), Élise (staff, extra, **avec horaires
perso** 16:00–23:30), Noah/Julien (staff, extra), **Camille** (staff, extra, **archivée**).
Taverne Saint-Gilles reste vide.

`lib/mock_data/mock_session.dart` — le stub `mockSignedInFullName/Email` de la Phase 1 est
remplacé par `final Employee mockCurrentEmployee = mockEmployees.firstWhere(... EmployeeIds.marc)`.
Consommé par `app_top_bar.dart`, `store_dashboard_page.dart` (salutation → `firstName`),
`account_settings_page.dart` (ligne du rôle **restaurée** via `employeeRoleLabel`), et les
mutations `movement_` / `order_` / `supplier_` (nom d'acteur par défaut →
`employeeDisplayName(mockCurrentEmployee)`).

---

## 3. Couche d'écriture — `lib/mock_data/mutations/employee_mutations.dart`

| Méthode | Rôle |
|---|---|
| `create({...})` | Refuse un champ requis vide, un **CIN** ou un **e-mail** déjà utilisé *n'importe où sur le compte* (`_normalise`, insensible casse/espaces). |
| `update(id, {...})` | Mêmes gardes d'unicité avec `excludingId`. **N'accepte pas `archivedAt`.** `clearSchedule: true` remet les horaires perso à null. |
| `archive(id)` | Pose `archivedAt`. `false` si déjà archivé. Ne touche à rien d'autre. |
| `restore(id)` | Remet `archivedAt` à null. `false` si pas archivé. |

Pas de suppression dure. `archive`/`restore` partagent `_setArchivedAt`.

`mockEmployees` est ajouté à `MockWrite.captureSeed()/reset()` et au test de restauration
intégrale de `mock_write_test.dart`.

### Requêtes — `lib/mock_data/mock_queries.dart`

`employeesForStore`, `activeEmployeesForStore` (via `isEmployeeActive`), `employeeById`,
`employeeByCin(cin, {excludingId})`, `employeeByEmail(email, {excludingId})` — les deux
lookups sont **compte-wide** (plus de paramètre `storeId`, contrairement à l'ancien lookup
d'équipe).

---

## 4. Routes et navigation

### `lib/app/routes.dart` / `router.dart`

```
/store/:storeId/employees                       Personnel (liste)
/store/:storeId/employees/new                    Ajouter
/store/:storeId/employees/timeclock              Tableau de pointage   → placeholder
/store/:storeId/employees/attendance-history     Historique pointage   → placeholder
/store/:storeId/employees/payroll                Historique de paiement → placeholder
/store/:storeId/employees/payroll/new            Nouveau paiement      → placeholder
/store/:storeId/employees/:employeeId            Fiche employé
/store/:storeId/employees/:employeeId/edit       Modifier
```

Les segments littéraux sont déclarés **avant** `:employeeId` (même raison d'ordre go_router
que `orders`). Les 4 routes non encore construites pointent sur
`EmployeeSectionPlaceholderPage` — un écran « Bientôt disponible » honnête (pas une
demi-fonctionnalité), swappé pour le vrai écran à chaque phase.

### Barre latérale — `lib/shared/widgets/app_sidebar.dart`

L'accordéon supprimé en Phase 1 est **restauré**, désormais avec **4 enfants** :
Personnel / Tableau de pointage / Historique pointage / Historique de paiement.
`matchSegment: 'employees'` — le rail met en surbrillance « Gestion Employée » depuis
n'importe quel écran de la famille. Rail replié → flyout `showMenu`. Connecteurs d'arbre au
`CustomPainter`. `_Destination` garde l'`assert` « navigue OU s'étend, jamais les deux ».

> **Note de nommage** : l'enfant pointage s'appelle **« Tableau de pointage »**, pas
> « Tableau de bord » (le doc `gestion_personnelle.md` disait « Tableau de bord » mais ça
> entre en collision avec l'entrée Dashboard `navDashboard` — `navigation_test` l'a
> attrapé).

En Phases 2–5 les 4 enfants sont toujours visibles ; Phase 6 les filtrera par rôle.

---

## 5. Écrans — `lib/features/employees/presentation/pages/`

| Fichier | Rôle |
|---|---|
| `employees_list_page.dart` | Racine. Bandeau **KPI** (`StatTile` : actifs / Fixes·Extras / Gérants / embauches ce mois). Recherche **nom + CIN**. Bascule « Afficher les personnels retirés ». Cartes : avatar, nom, CIN, `EmployeeRoleBadge`, chip de contrat, pastille « Retiré ». Deux états vides. |
| `add_edit_employee_page.dart` | Un `FormScaffold` pour créer/modifier. Prénom/nom, CIN, téléphone, e-mail, photo simulée (snackbar), sélecteur de rôle en cartes (nom + description), type de contrat, rémunération (libellé réactif « Salaire mensuel (€) » ↔ « Tarif horaire (€/h) »), horaires perso `HH:MM` optionnels (vide → horaires de l'établissement). Échecs d'unicité affichés sous le champ. **Pas de section identifiants** — Phase 6. |
| `employee_detail_page.dart` | Fiche poussée. En-tête (avatar, badge rôle, date d'embauche), bandeau « Retiré le … » + action **Restaurer** si archivé, sections Coordonnées / Contrat et rémunération (dont horaires résolus). Historique de pointage et de paiement = **cartes placeholder** (remplies Phases 3 et 5). Actions : Modifier, Retirer (`ConfirmDialog` nommant la personne) / Restaurer. |
| `employee_section_placeholder_page.dart` | L'écran « Bientôt disponible » partagé pour les 3 sections à venir. |

---

## 6. Widgets partagés — `lib/shared/widgets/`

Déplacés dans `shared/` (plus de copies privées par écran, comme demandé) :

- **`employee_avatar.dart`** — `EmployeeAvatar({employee, size, dimmed})` : photo ou
  initiales. Remplace les 4 copies privées de l'ancien module.
- **`employee_role_badge.dart`** — `EmployeeRoleBadge` + les helpers de nommage partagés
  `employeeRoleLabel`, `employeeRoleDescription`, `contractTypeLabel`.
- **`stat_tile.dart`** — `StatTile({label, value, icon, accent?})` : la carte KPI compacte
  (horizontale). Le `SummaryTile` du dashboard (vertical, grand) reste tel quel.

---

## 7. Traductions

~70 clés ajoutées à `app_fr.arb` (préfixes `navEmployees`, `employeesNav*`,
`employeeSectionComingSoon*`, `employeeRole*`, `contractType*`, `employees*`, `employee*`),
chacune avec `@description`, régénérées via `flutter gen-l10n`.

---

## 8. Tests

- **`test/employees_test.dart`** (nouveau) — création (champs requis, CIN/e-mail uniques
  compte-wide y compris cross-store), édition (pas de collision avec soi-même, collision
  avec un autre refusée, `clearSchedule`), archive/restore (double appel refusé, `update`
  ne change jamais `archivedAt`, archivé hors roster actif mais résolvable), reset.
- **`test/mock_data_test.dart`** — intégrité (store réel, CIN/e-mail uniques,
  `mockCurrentEmployee` owner sur le roster) + propriétés démo (Taverne vide, tous les
  rôles, les deux contrats, un archivé, un avec horaires perso).
- **`test/mock_write_test.dart`** — `mockEmployees` dans `_mutableLists` et
  `_snapshotCounts`.
- **`test/navigation_test.dart`** — 4 routes racine + 3 routes poussées ; test de
  surbrillance depuis une fiche employé ; groupe « dropdown Gestion Employée » (les 4
  enfants apparaissent et naviguent).
- **`test/router_test.dart`** — les 8 routes employés (dont fiche d'un archivé) aux 3
  tailles de tablette.

---

## 9. Hypothèses / écarts

1. **Identifiants de connexion** — non collectés au formulaire en Phase 2 (le doc les y
   mettait). Phase 6 les ajoute avec `EmployeeCredential`.
2. **Pas de menu d'actions sur la ligne** de la liste — la fiche porte les actions
   (Modifier / Retirer / Restaurer), comme les modules items/suppliers. Le doc évoquait un
   menu par carte ; la convention du projet l'emporte.
3. **Horaires résolus** sur la fiche — affiche les horaires perso ou « Horaires de
   l'établissement ». Les vraies heures d'ouverture (et le calcul retard/heures sup)
   arrivent en Phase 3.
4. **`Employee.hireDate`** — posé à `DateTime.now()` à la création (pas de champ au
   formulaire), paramètre optionnel pour les tests.

---

## 10. État de la qualité

- `flutter analyze` — **No issues found**.
- `flutter test` — **364 tests passent** (0 échec).
- `python tool/ux_audit.py` — **0 violation** sur les 12 contrôles.
