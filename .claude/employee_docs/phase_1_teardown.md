# Phase 1 — Teardown

Suppression complète des modules **Équipe** (`lib/features/team/`) et **Personnel**
(`lib/features/employees/`) et de tout ce qui en dépendait. Aucune fonctionnalité ajoutée :
c'est une soustraction pure, relisable seule. Contrat : `.claude/phase_gestion_employee.md`.

À la fin de cette phase : `flutter analyze` propre, **311 tests passent**, `python
tool/ux_audit.py` → **0 violation**.

---

## 1. Fichiers supprimés

| Catégorie | Fichiers |
|---|---|
| Features | `lib/features/team/` (dossier entier), `lib/features/employees/` (dossier entier) |
| Modèles | `models/team_member.dart`, `models/time_entry.dart`, `models/employee.dart` |
| Données mock | `mock_data/mock_team.dart`, `mock_data/mock_employees.dart`, `mock_data/mock_time_entries.dart` |
| Mutations | `mock_data/mutations/employee_mutations.dart`, `mock_data/mutations/timeclock_mutations.dart` |
| Dérivations | `core/utils/employee_status.dart`, `core/utils/timeclock_status.dart` |
| Widgets partagés | `shared/widgets/time_entry_status_badge.dart` |
| Tests | `test/employees_test.dart`, `test/timeclock_test.dart` |
| Docs | `docs/page_personelle.md` → déplacé vers `.claude/employee_docs/_archive/page_personelle_v1.md` |

Total : **~8 000 lignes retirées**, ~1 300 ajoutées (surtout le brief `phase_gestion_employee.md`).

---

## 2. Références nettoyées

- **Barrels** — `models/models.dart` et `mock_data/mock_data.dart` : exports retirés.
- **`mock_write.dart`** — `mockTeam` / `mockEmployees` / `mockTimeEntries` retirés de
  `_Seed` (constructeur, `capture()`, champs, `restore()`).
- **`account_mutations.dart`** — toute la section **Team** supprimée (`invite`,
  `updateMember`, `removeMember`, `isLastOwner`) + l'appel à `clearTeamMemberLink`.
  Sections **Stores** et **Notifications** intactes.
- **`mock_queries.dart`** — supprimés : `teamForStore`, `teamMemberById`,
  `teamMemberByEmail`, `ownerCount`, et les blocs **Employees** + **Pointage**
  (`employeesForStore`, `activeEmployeesForStore`, `employeeById`, `employeeByEmail`,
  `timeEntriesForEmployee`, `timeEntryForToday`, `timeEntriesForStore`). Imports
  `employee_status.dart` / `mock_employees` / `mock_team` / `mock_time_entries` /
  `mock_reference` retirés.
- **`routes.dart`** — constantes + builders `toTeam` / `toRoles` / `to*TeamMember` /
  `toEmployees` / `toAddEmployee` / `toEmployee` / `toEditEmployee` / `toLinkTeamAccess` /
  `toTimeclock` / `toTimeclockHistory` supprimés.
- **`router.dart`** — imports des 9 pages + blocs `GoRoute` Team et Employees supprimés.
- **`app_sidebar.dart`** — réécrit. L'accordéon « Gestion des employés » (avec
  `_ChildDestination`, `_EmployeesParentLabel`, `_EmployeesChildLabel`,
  `_TreeBranchPainter`, `_showFlyout`, l'état `_employeesExpanded`, les `GlobalKey`) et
  l'entrée **Équipe** ont disparu. Le rail redevient une **liste plate de 9 destinations
  directes** ; `AppSidebar` redevient un `StatelessWidget`.
- **`widgets.dart`** — export `time_entry_status_badge` retiré.
- **`app_scaffold.dart`** — `isFullScreenProvider` / `FullScreenMode` **conservés**
  (câblage intact, aucune page ne le déclenche pour l'instant) ; commentaires qui
  citaient `TimeclockBoardPage` reformulés. Phase 3 n'aura qu'à réajouter le bouton.
- **l10n** — **140 clés mortes** (`team*`, `member*`, `role*`, `permission*`,
  `a11yPermission*`, `nav{Team,Employees}`, `employees*`, `employee*`, `payType*`,
  `linkTeamAccess*`, `timeclock*`, `timeEntryStatus*`) + leurs `@métadonnées` retirées de
  `app_fr.arb`, puis `flutter gen-l10n` (retire 840 + 484 lignes des fichiers générés).
- **Comment** — `mock_reference.dart` (`dayOnly` doc), `models/store.dart`, `README.md`
  (tableau des mutations, description `account_test.dart`).

---

## 3. Le seam `mockCurrentUser` → `mock_session.dart`

`mockCurrentUser` était un `TeamMember` de `mock_team.dart`, lu par trois endroits :
`app_top_bar.dart` (avatar + menu compte), `store_dashboard_page.dart` (salutation),
`account_settings_page.dart` (profil).

Remplacé par un **stub** `lib/mock_data/mock_session.dart` :

```dart
const String mockSignedInFullName = 'Marc Delvaux';
const String mockSignedInEmail = 'marc.delvaux@brasserie-sablon.be';
```

- Les mutations `movement_` / `order_` / `supplier_` qui utilisaient
  `mockCurrentUser.fullName` comme nom d'acteur par défaut pointent maintenant sur
  `mockSignedInFullName`.
- `account_settings_page.dart` : la ligne du rôle a été retirée (plus de `roleLabel`).

**Phase 2** remplace ce stub par un vrai `Employee` (`mockCurrentEmployee`, rôle `owner`)
et restaure la ligne du rôle. **Phase 6** en fait le résultat d'un login.

---

## 4. Tests touchés

| Fichier | Changement |
|---|---|
| `test/employees_test.dart`, `test/timeclock_test.dart` | supprimés |
| `test/account_test.dart` | groupe `team` retiré ; ne garde que `stores` + `notifications` |
| `test/mock_data_test.dart` | assertion « team members point at real stores » retirée |
| `test/mock_write_test.dart` | `mockTeam` / `mockEmployees` / `mockTimeEntries` retirés de `_mutableLists` et `_snapshotCounts` |
| `test/navigation_test.dart` | routes team/employees retirées de `_rootScreens` et `_pushedScreens` ; test « highlights Gestion des employés » et groupe « accordéon » retirés |
| `test/router_test.dart` | routes team/employees retirées de `_allRoutes()` |

Le contrat de navigation reste vérifié aux 3 tailles de tablette (1280×800, 1024×600,
portrait) — `router_test.dart` continue de passer, rail plat compris.

---

## 5. Ce que Phase 2 récupère (les seams)

1. **`mock_session.dart`** → devient `mockCurrentEmployee` (un `Employee`).
2. **Rail plat** → une entrée `_Destination` « Gestion Employée » + l'accordéon 4-enfants
   (à restaurer depuis l'historique git, désormais 4 items).
3. **Espace de routes libéré** sous `/store/:storeId/employees` et `.../team` — Phase 2
   rebranche `employees` / `employees/new` / `employees/:id` / `.../edit`, Phases 3-5
   ajoutent `timeclock` / `attendance-history` / `payroll`.
4. **`isFullScreenProvider`** intact dans `app_scaffold.dart` — Phase 3 ajoute juste le
   bouton.
5. **`account_settings_page.dart`** — un `// TODO`-équivalent (commentaire) marque où la
   ligne du rôle revient en Phase 6.

---

## 6. État de la qualité

- `flutter analyze` — **No issues found**.
- `flutter test` — **311 tests passent** (0 échec). (332 avant : 21 en moins = les
  fichiers `employees_test` + `timeclock_test` supprimés et les groupes retirés.)
- `python tool/ux_audit.py` — **0 violation** sur les 12 contrôles.
- `flutter gen-l10n` — propre, `app_fr.arb` valide (725 → 585 clés).
