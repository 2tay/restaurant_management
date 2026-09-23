# Plan — Refonte pointage & employés (sans type de contrat, sans horaires fixes)

Plan de travail, pas un doc de complétion — à mettre à jour au fil de l'avancement, et à
archiver ou transformer en doc de complétion par phase une fois chaque phase terminée (voir
`README.md`).

## Contexte / demande initiale

- Retirer le type d'employé (Fixe / Extra) : chaque employé a un tarif €/h, payé à l'heure
  réellement travaillée.
- Pas de calcul d'heures supplémentaires.
- Pas d'heure de début / fin fixée, ni par employé ni par établissement.
- Pas d'alerte de dépassement d'heure de départ.
- Garder uniquement la durée max par pause (déjà existant, `StoreSettings.maxBreakMinutes` +
  l'anomalie `pauseDepassee`) — pas de limite sur le nombre de pauses dans la journée.
- Renommer CIN → PIN, et le code PIN actuel (identifiant de connexion complet) → Password.
- Vérification d'identité au clic sur un bouton de pointage : tentatives illimitées, pas de
  verrouillage.
- Une journée peut contenir plusieurs cycles Pointer → Pause → Reprendre → Fin de journée.
- UI :
  - Tableau de pointage (Historique) : plus de colonne horaire/pause dans le tableau, le détail
    passe par le drawer déjà existant.
  - Page Personnel : garder les cartes + ajouter une vue liste (tableau), avec un switch entre
    les deux vues.
  - Formulaire d'ajout d'employé : retirer l'assignation du rôle Propriétaire ; formulaire
    simplifié une fois les champs contrat/horaires retirés.
  - Clic sur un employé : ouvre un drawer de détail (remplace la page `EmployeeDetailPage`).

## Décisions prises

- **Cycles multiples** : modélisés en table relationnelle normalisée (voir Phase 2), pas en JSON
  embarqué ni en lignes `Attendances` multiples par jour.
- **Renommage CIN/PIN/Password** : renommage pur de vocabulaire, la mécanique de vérification ne
  change pas.
- **Détail employé** : le drawer remplace entièrement la page `EmployeeDetailPage` (pas de double
  affichage aperçu + page complète).

Schéma actuel : `schemaVersion = 9` (au départ du plan : v5). Chaque phase qui touche la DB avance la version (v6, v7, …).

---

## Phase 1 — Employé : suppression du type de contrat ✅

- `lib/models/employee.dart` : retirer `ContractType` / `contractType`. `pay` devient
  uniformément un tarif €/h.
- `lib/data/database/tables/employees.dart` : drop colonne `contractType` (schema v6).
- `lib/core/utils/payroll_math.dart` : `hourlyRate` retourne directement `employee.pay`, plus de
  branche fixe/mensuelle.
- `add_edit_employee_page.dart` : retrait du dropdown contrat, libellé de paie fixe
  ("Tarif horaire (€/h)").
- `employees_list_page.dart` (KPI split fixed/extra), `employee_detail_page.dart` (ligne
  contrat), seed `employees.dart` : mise à jour.

## Phase 2 — Pointage : cycles multiples par jour (modèle à 3 niveaux) ✅

Une journée peut contenir plusieurs cycles Pointer → Fin de journée. Modélisé en suivant le
pattern déjà en place pour les collections ordonnées enfants (`PurchaseOrderLine`,
`AttendancePause`) : table relationnelle normalisée avec colonne `position`, pas un blob JSON ni
une liste embarquée directement sur `Attendances`.

```
Attendances (1 ligne / employé / jour, inchangé dans sa fonction de clé)
  └─ AttendanceSessions (n lignes, FK attendanceId cascade, position)
       ├─ clockInAt, clockOutAt
       └─ AttendancePauses (n lignes, FK → sessionId cascade, position)
```

- **Nouvelle table** `AttendanceSessions` : `id`, `attendanceId` (FK cascade), `position`,
  `clockInAt`, `clockOutAt`.
- **Table** `AttendancePauses` : la FK passe de `attendanceId` à `sessionId` (FK cascade) — une
  pause appartient à une session précise, pas à la journée entière.
- **Modèle Dart** (immutable, sans logique, comme le reste) :
  `Attendance.sessions: List<AttendanceSession>`,
  `AttendanceSession { clockInAt, clockOutAt, pauses: List<AttendancePause> }`.
- **`status` dérivé de la dernière session**, plus un état terminal de la journée :
  - aucune session → `notClockedIn`
  - dernière session ouverte (pas de `clockOutAt`) → `working` / `onBreak` selon ses pauses
  - dernière session fermée → `done`, mais le bouton `Pointer` reste actif pour ouvrir une
    nouvelle session le même jour (contrairement au comportement actuel où la journée était
    verrouillée après `Fin de journée`).
- `attendance_repository.dart` : `clockIn` ouvre une nouvelle session (au lieu de refuser quand
  une ligne `Attendances` existe déjà pour le jour) ; `startPause` / `endPause` / `clockOut`
  opèrent sur la dernière session ouverte.
- `attendance_status.dart` : `workedDuration` / `totalBreak` somment sur toutes les sessions du
  jour.
- Board de pointage (`timeclock_board_page.dart`), historique (table/cards), timeline, drawer :
  afficher plusieurs blocs Arrivée→Départ dans la même journée au lieu d'un seul.
- Schema v7.

## Phase 3 — Suppression horaires fixes & heures supplémentaires ✅

- Retirer `scheduledStartMinutes` / `scheduledEndMinutes` (employé et store), `overtimeMultiplier`,
  `workingDaysPerMonth`, `openMinutes` / `closeMinutes` du `StoreSettings` — à vérifier au
  démarrage de la phase qu'ils ne sont pas réutilisés ailleurs (dashboard, rapports) avant de les
  retirer.
- `attendance_status.dart` : suppression de `isLate`, `lateBy`, `overtimeBy`, l'anomalie
  `retard`.
- `payroll_math.dart` : plus de prime heures supp, juste `heures travaillées × tarif`.
- `store_settings_page.dart` : retrait de la section "Horaires" (ouverture/fermeture) et des
  champs payroll devenus inutiles.
- Schema v8.

## Phase 4 — Pauses : rien à faire ✅

Seule la durée max par pause est gérée, et c'est déjà en place (`StoreSettings.maxBreakMinutes`,
`hasLateBreak`, l'anomalie `pauseDepassee`) — pas de limite sur le nombre de pauses par jour.
Aucun changement nécessaire ; phase conservée dans la numérotation pour la traçabilité de la
décision.

## Phase 5 — Identité au pointage : tentatives illimitées ✅

- `credential_repository.verifyCin` (renommé en Phase 6) : suppression du lockout pour la
  confirmation d'identité au pointage/paiement — tentatives illimitées. Le lockout du login
  complet propriétaire/gérant (`authenticate`) reste inchangé (périmètre différent).
- `IdentityPromptDialog` : simplifié, plus de countdown de verrouillage.

## Phase 6 — Renommage CIN→PIN, code PIN→Password ✅

- `Employee.cin` → `Employee.pin` (colonne, mapper, repository, l10n, tous les libellés UI).
- `EmployeeCredential.pinHash` / `AuthRules.pinLength` / `isValidPin` / `fakePinHash` →
  vocabulaire "Password" (`passwordHash`, etc.), UI login + formulaire employé +
  `credential_status.dart`.
- Mise à jour de tous les tests qui référencent `cin` / `pin` par leur nom.
- Schema v9 (rename colonne).

## Phase 7 — Formulaire d'ajout/édition employé ✅

- Retirer l'option de rôle "Propriétaire" de `_RoleOption` (seuls Gérant / Employé restent
  sélectionnables).
- Section credentials relabellisée (Phase 6), section contrat/horaires supprimée (Phases 1 & 3).
- Réorganisation des sections restantes pour un formulaire plus resserré.

## Phase 8 — Personnel : vue liste + drawer de détail

- Toggle carte/liste sur `EmployeesListPage`, avec une vue tableau (`DataTableWrapper`, même
  pattern que l'historique de pointage) en alternative à la grille de cartes actuelle.
- Le clic sur un employé (carte ou ligne) ouvre un `DetailDrawer` (infos + historique) au lieu de
  naviguer vers `EmployeeDetailPage`, qui est retirée.

## Phase 9 — Historique de pointage : nettoyage du tableau

- `_HistoryTable` : retrait de la colonne "Horaire" (arrivée→départ + résumé pause) ; le tableau
  garde Date / Employé / Travaillé / Statut / Alertes / Détail. Le détail complet (sessions,
  pauses) reste dans le drawer déjà existant (`AttendanceTimeline`).

## Phase 10 — Tests & régression

- Réécriture des tests unitaires (`attendance_status_test`, `payroll_math_test`,
  `credential_status_test`), tests de repository, tests de schéma/migration pour chaque version
  v6→v10, tests widgets impactés.
- Suite complète verte avant merge.

---

Ordre recommandé : 1 → 10, chaque phase se commite et se teste séparément.
