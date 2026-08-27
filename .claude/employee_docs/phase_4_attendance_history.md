# Phase 4 — Historique de pointage

Le journal de pointage filtrable sur tout l'établissement : un bandeau KPI, des filtres
(période / statut / employé), un tableau paginé, un panneau de détail par ligne. Contrat :
`.claude/phase_gestion_employee.md`.

Fin de phase : `flutter analyze` propre, **391 tests passent**, `python tool/ux_audit.py`
→ **0 violation**.

Aucun nouveau modèle — la phase lit et présente `mockAttendances`.

---

## 1. Requêtes — `lib/mock_data/mock_queries.dart`

### `attendancesForStore(...)`

```dart
static ({List<Attendance> rows, int totalCount, int page, int pageCount})
attendancesForStore(
  String storeId, {
  int? withinDays,          // fenêtre glissante ; null = "Tout"
  AttendanceStatus? status,
  String? employeeQuery,     // nom, _normalise (casse/espaces insensibles)
  int page = 0,
  int pageSize = 25,
})
```

Filtres combinés en **ET**, tri jour le plus récent d'abord (puis heure d'arrivée), puis
découpe en page. `page` est **borné** dans l'intervalle valide — l'appelant relit `result.page`
et remet son état local en phase. Le nom d'employé est résolu dans la requête (l'UI ne fait
jamais de lookup).

### `attendanceStatsForStore(storeId, {withinDays})`

Renvoie `({int days, Duration worked, int lateArrivals, Duration overtime, int lateBreaks})`
— **sur toute la fenêtre**, indépendamment des filtres statut/employé/page (même principe
que « 1 248 total » vs « 248 résultats »). Retard et heures sup mesurés contre l'horaire
résolu de **chaque** employé (`resolvedSchedule` + `StoreSettings`).

> Décision : filtre de **période** = fenêtre glissante 7 / 30 / 90 jours / Tout, comme
> `stock_history_page.dart` et les rapports — pas de sélecteur de plage personnalisée (le
> brief l'évoquait, mais aucun écran du projet n'en a un, et c'est le seul précédent de
> filtre de période).
>
> Décision : le filtre de **statut** n'offre que `working` / `onBreak` / `done`
> (`notClockedIn` n'est jamais stocké). Pas d'absences (décision client Phase 3).

---

## 2. Écran — `lib/features/employees/presentation/pages/attendance_history_page.dart`

Remplace le placeholder de la route `/employees/attendance-history` (l'enum
`EmployeeSection` disparaît — le placeholder ne sert plus qu'à la paie).

- `goSection`, pas de contrôle retour.
- **Bandeau KPI** (`StatTile` partagé) : Jours pointés · Heures travaillées · Retards ·
  Heures supplémentaires. « Retards » se teinte en ambre s'il y en a.
- **Filtres** (`Wrap`) : `SearchField` employé, `_Menu` période, `_Menu` statut — la paire
  `FilterPill` + `PopupMenuButton` de tout le reste de l'app. Puces de filtre actif
  retirables + « Effacer les filtres ». Tout changement de filtre remet `page` à 0.
- Ligne « X résultats ».
- **Tableau** (`DataTableWrapper`, `minWidth: 1000`, dans un `SingleChildScrollView`
  vertical pour que les 25 lignes défilent) : Date, Employé, Arrivée, Départ, Pauses,
  Durée travail, Heures sup, Statut (`AttendanceStatusBadge`), Alertes (icônes retard /
  pause dépassée), Détail.
- **`Paginator`** (widget partagé) sous le tableau — ne s'affiche que s'il y a plus d'une
  page. Changer de page ferme le panneau de détail.
- **Panneau de détail** latéral (320 px) ouvert par ligne : identité, date, statut,
  arrivée/départ, durée travaillée, et **la liste complète des segments de pause**
  (`12:00 – 12:20 (0h20)`), chaque segment trop long marqué en ambre.
- Deux états vides : rien du tout (`attendanceHistoryEmpty`) vs aucun résultat pour les
  filtres (générique + action « Effacer les filtres »).

---

## 3. Widget partagé — `lib/shared/widgets/paginator.dart`

`Paginator({page, pageCount, totalCount, pageSize, onChanged})` — « X–Y sur Z » +
Précédent / Suivant + « page / total ». Rend `SizedBox.shrink()` si `pageCount <= 1`.

---

## 4. Traductions

~30 clés ajoutées à `app_fr.arb` (`paginator*`, `attendanceHistory*`, `attendanceStat*`,
`attendanceColumn*`, `attendanceViewDetail`, `attendanceDetail*`), régénérées. Réutilise
`periodLast7Days`/`30`/`90`/`periodAll`, `movementsFilterPeriod`, `ordersFilterStatus`/
`AllStatuses`, `emptyStateNoResults*`, `inventoryClearFilters`, `employeesSearchHint`.

---

## 5. Tests

- **`test/attendance_test.dart`** — nouveau groupe **`attendancesForStore (Historique)`** :
  coupure de période (exclut/inclut), `withinDays: null` renvoie tout, filtre statut seul,
  filtre nom (casse/espaces, partiel), les trois combinés en ET + tri, **pagination**
  (découpe, `pageCount`, page hors intervalle bornée, pas de chevauchement première/dernière
  page), résultat vide = une page, et `attendanceStatsForStore` (forme + calcul par horaire
  résolu).
- **`test/router_test.dart` / `test/navigation_test.dart`** — la route
  `attendance-history` rend désormais le vrai écran (déjà couverte aux 3 tailles).

---

## 6. Hypothèses / écarts

1. **Fenêtre glissante, pas de plage de dates personnalisée** — cohérent avec le seul
   précédent du projet.
2. **KPI** : « nombre d'absences » et « taux de présence » du brief remplacés par
   « Heures supplémentaires » (pas d'absences dans le modèle).
3. **`AttendanceRow` non utilisé ici** — le tableau dense a besoin de colonnes séparées, pas
   de la ligne récapitulative de la fiche employé. `AttendanceRow` reste pour la fiche
   (Phase 3) et pourra servir à une vue « cartes » plus tard.
4. **Le panneau de détail n'est pas une route** — un pointage n'a pas de page propre, comme
   le panneau de l'ancien module.

---

## 7. État de la qualité

- `flutter analyze` — **No issues found**.
- `flutter test` — **391 tests passent** (0 échec).
- `python tool/ux_audit.py` — **0 violation** sur les 12 contrôles.
