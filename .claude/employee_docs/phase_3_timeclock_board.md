# Phase 3 — Tableau de pointage

Le kiosque de pointage du jour : une carte par employé actif, N pauses par jour, horloge en
direct, mode plein écran. Contrat : `.claude/phase_gestion_employee.md`.

Fin de phase : `flutter analyze` propre, **383 tests passent**, `python tool/ux_audit.py`
→ **0 violation**.

> **Décision client 1** : **pas de gestion des absences** ni de justification. Les statuts
> `absent` / `absentJustified`, le bouton « Marquer absent », le dialog de justification et
> le champ `Attendance.comment` ont été retirés. Une journée non pointée reste « Non
> pointé ». Impact Phase 5 : la paie n'a plus de retenue pour absence (un salarié fixe est
> payé son mensuel).
>
> **Décision client 2** : les réglages du magasin deviennent un **vrai modèle**
> (`StoreSettings`), pas un sac de globales statiques. `MockSettings` est supprimé. Le
> modèle porte les horaires d'ouverture, la **pause maximale** (`maxBreakMinutes`) et le
> seuil de commande en souffrance, par magasin. Un segment de pause plus long que
> `maxBreakMinutes` est signalé **« Pause dépassée »** (badge + marque sur la carte, la
> ligne d'historique et le journal horodaté).

---

## 1. Modèle de données — `lib/models/attendance.dart`

```dart
enum AttendanceStatus {
  notClockedIn,   // jamais stocké — c'est l'absence de ligne
  working, onBreak, done,
}
enum PaymentStatus { unpaid, paid }

class AttendancePause {
  final DateTime startAt;
  final DateTime? endAt;   // null tant que la pause est en cours
}

class Attendance {
  final String id;
  final String storeId;
  final String employeeId;
  final DateTime date;              // minuit — le jour concerné
  final AttendanceStatus status;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final List<AttendancePause> pauses;   // embarquées, comme PurchaseOrder.lines
  final PaymentStatus paymentStatus;
  final String? payrollPeriodId;        // posé quand la paie verrouille le jour (Phase 5)
}
```

Une ligne par employé et par jour, créée au premier `Pointer`. Les pauses sont
**multiples** (l'ancien `TimeEntry` n'en avait qu'une).

### Dérivations — `lib/core/utils/attendance_status.dart`

- `AttendanceRules` : `defaultOpenMinutes` (08:00), `defaultCloseMinutes` (17:00),
  `defaultMaxBreakMinutes` (30), `lateGrace` (5 min), `standardWorkDay` (8 h, paie Phase 5)
  — **seulement les valeurs par défaut** d'un magasin neuf.
- `totalBreak(a)` — somme des pauses **terminées** ; `hasOpenBreak(a)`.
- `workedDuration(a)` — `clockOut − clockIn − totalBreak`, null tant que pas de `clockOut`,
  plancher à 0.
- `resolvedSchedule(employee, {storeOpenMinutes, storeCloseMinutes})` — l'horaire perso de
  l'employé, sinon les heures du magasin.
- `lateBy(a, start)` / `isLate(a, start)` — retard de l'arrivée au-delà de la tolérance.
- `overtimeBy(a, end)` — temps pointé après l'heure de fin résolue, plancher à 0.
- **`breakOverrun(pause, maxBreakMinutes)`** — de combien **une** pause terminée a dépassé
  l'allocation, plancher à 0. **`hasLateBreak(a, max)`** — vrai si un segment quelconque a
  dépassé (par segment, pas sur le total). **`totalBreakOverrun(a, max)`** — la somme, pour
  la Phase 5.

### Réglages du magasin — `lib/models/store_settings.dart` (nouveau modèle)

```dart
class StoreSettings {
  final String storeId;
  final int openMinutes;
  final int closeMinutes;
  final int maxBreakMinutes;
  final int stalePartialOrderDays;
}
```

Un vrai modèle immuable, un par magasin — il correspond 1:1 à la ligne `settings` de la
Phase 2, il est éditable par un gérant, et le pointage a besoin d'un endroit où lire les
horaires et l'allocation de pause.

- `lib/mock_data/mock_store_settings.dart` — une ligne par magasin (Sablon fait 09:00–23:00,
  pause 45 min ; les autres gardent les défauts) + `storeSettingsOrDefault(storeId)`.
- `MockQueries.storeSettings(storeId)` — la ligne, ou un défaut synthétisé.
- `AccountMutations.updateStoreSettings(storeId, {openMinutes, closeMinutes,
  maxBreakMinutes, stalePartialOrderDays})` — une valeur absurde est ignorée, pas refusée.
  `createStore` ajoute désormais une ligne de réglages par défaut.
- `mockStoreSettings` dans `MockWrite.captureSeed()/reset()` — **`MockSettings` est
  supprimé** ; `stalePartialOrderDays` a migré ici (consommateurs : `order_row`,
  `staleOrders`, le dashboard, `orders_test` — tous mis à jour).
- Section **« Horaires de l'établissement »** sur `store_settings_page.dart` : ouverture,
  fermeture, **pause max (minutes)**, le tout via le modèle + la mutation.

---

## 2. Données de démonstration — `lib/mock_data/mock_attendances.dart`

Étalées sur plusieurs jours. Seul **aujourd'hui** est laissé en cours :

- **Karim** — en service (pointé 07:45)
- **Amélie** — en service, une pause déjà terminée
- **Fatima** — en pause : une pause terminée + une **en cours** (prouve les N pauses)
- **Noah**, **Julien**, **Marc** — aucune ligne → « Non pointé »

Jours passés (tous terminés) : un **retard** (Fatima hier, 08:20 vs 08:00), des **heures
sup** réelles (Amélie hier, sortie 18:30 vs 17:00), et deux jours de **Karim déjà payés**
(`paymentStatus: paid`, `payrollPeriodId: 'payroll-seed-karim'` — la période elle-même est
seedée en Phase 5).

---

## 3. Couche d'écriture — `lib/mock_data/mutations/attendance_mutations.dart`

**Le seul fichier qui écrit une `Attendance`.** Chaque méthode prend un `{now}` optionnel
et refuse le mauvais état antérieur ; toutes refusent aussi un jour verrouillé
(`paymentStatus == paid`).

| Méthode | Refuse si | Effet |
|---|---|---|
| `clockIn(employeeId, storeId, {now})` | une ligne existe déjà aujourd'hui | ligne `working`, `clockInAt` |
| `startPause(id, {now})` | statut ≠ `working` | ajoute `AttendancePause(startAt: now)`, statut `onBreak` — **aucune limite** de pauses |
| `endPause(id, {now})` | statut ≠ `onBreak` / pas de pause ouverte | ferme la pause, statut `working` |
| `clockOut(id, {now})` | statut ≠ `working` (donc refusé en pause) | `clockOutAt`, statut `done` |

`mockAttendances` ajouté à `MockWrite.captureSeed()/reset()` et à `mock_write_test.dart`.

### Requêtes

`attendanceById(id)`, `attendanceForToday(employeeId)` (via `dayOnly(0)`),
`attendancesForEmployee(employeeId)` (jour le plus récent d'abord).

---

## 4. Écrans

### `lib/features/employees/presentation/pages/timeclock_board_page.dart`

Remplace le placeholder de la route `/employees/timeclock`.

- En-tête : date + **horloge en direct** (`_LiveClock`, `Timer.periodic` isolé). Bouton
  **plein écran** (`isFullScreenProvider` — câblage resté intact depuis la Phase 1 ; remis
  à `false` dans `dispose` via microtask).
- **Pas de KPI** (kiosque = rapidité).
- Recherche nom + CIN (clé l10n `employeesSearchHint` réutilisée).
- Grille (`context.gridColumns(max: 4)`, `mainAxisExtent: 320`), employés **actifs**
  seulement, « non pointé » triés en premier.
- Carte : `EmployeeAvatar`, nom, CIN, `AttendanceStatusBadge` (+ icône **« Pause
  dépassée »** si `hasLateBreak`), **journal horodaté horizontal** (`_TimestampLog` — un
  `Wrap` de puces « • 07:45 Arrivée », « • 12:00 Pause », « • 12:20 Reprise »… qui passe à
  la ligne seulement quand la carte manque de largeur ; la puce « Reprise » d'un segment
  trop long est en ambre), zone d'action.
- **Zone d'action** — avant pointage : bouton « Pointer ». Quand `working` : **deux
  contrôles** — bouton principal « Pause » + bouton texte « Fin de journée ». Quand
  `onBreak` : « Reprendre ». Une fois `done` : résumé (durée travaillée, heures sup,
  marque retard, ligne **« Pause dépassée »**) + bouton « Terminé » désactivé.
- Snackbar de succès à chaque action.

### `lib/features/employees/presentation/pages/employee_detail_page.dart`

La section **Historique de pointage** (placeholder en Phase 2) affiche désormais les vraies
lignes via le widget partagé `AttendanceRow`, avec le compteur dans le `SectionHeader`. La
section **Historique de paiement** reste en placeholder (Phase 5).

### `employee_section_placeholder_page.dart`

`EmployeeSection.timeclock` retiré de l'enum. Restent `attendanceHistory` et `payroll`.

---

## 5. Widgets partagés — `lib/shared/widgets/`

- **`attendance_status_badge.dart`** — `AttendanceStatusBadge` (couleur + icône distincte +
  libellé) + `attendanceStatusLabel(l10n, status)`. Teintes : `working` vert, `onBreak`
  ambre, `done` gris, `notClockedIn` neutre.
- **`attendance_row.dart`** — `AttendanceRow({attendance, scheduledStartMinutes,
  maxBreakMinutes, employeeName?, asCard?})` : une ligne (date, horaires, durée travaillée,
  badge, marque **retard** ET marque **« Pause dépassée »**). Utilisée par la fiche employé
  (Phase 3) et l'Historique (Phase 4).

---

## 6. Traductions

~40 clés ajoutées à `app_fr.arb` (`attendanceStatus*` hors absences, `attendanceLate`,
`attendanceBreakOverrun`, `timeclock*` hors absences,
`storeSettings{Hours,MaxBreak}*`, `employeeHistoryEmpty`), régénérées.

---

## 7. Tests

- **`test/attendance_test.dart`** (nouveau) — pointage double refusé ; pause avant
  pointage / reprise avant pause / sortie en pause refusées ; **deux pauses dans la
  journée** (`totalBreak`/`workedDuration` corrects) ; retard au-delà de la tolérance ;
  heures sup vs fin résolue ; horaire perso > réglages magasin ; **dépassement de pause
  par segment** (deux pauses de 20 min ne déclenchent pas ; une de 45 min oui ; pause en
  cours jamais) ; **jour verrouillé refuse toute écriture** ; le seed couvre chaque état
  en cours ; `reset` restaure `mockAttendances`.
- **`test/orders_test.dart` / `test/mock_write_test.dart`** — `stalePartialOrderDays` lu
  via `MockQueries.storeSettings` et écrit via `AccountMutations.updateStoreSettings` ;
  `mockStoreSettings` dans la restauration intégrale ; nouveau test « chaque magasin a une
  ligne de réglages saine » dans `mock_data_test.dart`.
- **`test/mock_data_test.dart`** — intégrité (employé + magasin réels, `payrollPeriodId`
  présent si payé, une ligne max par employé/jour) + propriétés démo (pauses multiples,
  pause en cours, statuts en cours).
- **`test/mock_write_test.dart`** — `mockAttendances` dans `_mutableLists` /
  `_snapshotCounts`.
- **`test/navigation_test.dart` / `test/router_test.dart`** — la route `timeclock` rend
  désormais le vrai tableau (aucune nouvelle route).

---

## 8. Hypothèses / écarts

1. **Pas d'absences** (décision client, voir l'encadré en tête). Retiré du modèle, des
   mutations, de l'UI, du seed, des traductions et des tests.
2. **Deux boutons quand `working`** — avec N pauses il faut « Pause » **et** « Fin de
   journée » disponibles en même temps. Bouton principal « Pause » + bouton texte discret
   « Fin de journée ».
3. **`lateGrace` = 5 min** — arrivée dans les 5 minutes de l'horaire = pas de retard.
4. **Heures sup mesurées vs l'heure de fin résolue**, pas vs les heures travaillées.
5. **`payrollPeriodId` du seed** pointe vers une période qui n'existe pas encore — Phase 5
   crée `mockPayrollPeriods` avec l'id `'payroll-seed-karim'`.

---

## 9. État de la qualité

- `flutter analyze` — **No issues found**.
- `flutter test` — **383 tests passent** (0 échec).
- `python tool/ux_audit.py` — **0 violation** sur les 12 contrôles.
