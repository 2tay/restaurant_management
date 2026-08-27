# Phase 5 — Historique de paiement

La paie : le calcul jour par jour, le flux « Nouveau paiement » qui verrouille les jours
payés, et l'historique des paiements effectués. Contrat :
`.claude/phase_gestion_employee.md`.

Fin de phase : `flutter analyze` propre, **402 tests passent**, `python tool/ux_audit.py`
→ **0 violation**.

> **Sans absences** (décision client Phase 3) : un salarié fixe est payé son taux journalier
> par jour **réellement travaillé**, plus une prime sur les heures sup — aucune retenue pour
> absence, `PayrollPeriod` n'a pas de `absenceDays`.

---

## 1. Modèle — `lib/models/payroll_period.dart`

```dart
enum PayrollStatus { computed, paid }

class PayrollPeriod {
  final String id;
  final String storeId;
  final String employeeId;
  final DateTime startDate;      // premier / dernier jour couvert
  final DateTime endDate;
  final int workedDays;
  final double totalWorkedHours;
  final double totalOvertimeHours;
  final double appliedRate;      // snapshot du taux au moment du paiement
  final double computedAmount;
  final PayrollStatus status;
  final String? paidByEmployeeId;
  final DateTime? paidAt;
  final DateTime createdAt;
}
```

Même permanence qu'une réception confirmée : une fois `paid`, jamais modifié ni supprimé,
`appliedRate` fige le taux (une augmentation ultérieure ne déplace pas un paiement passé),
et les jours couverts ne peuvent plus être touchés par `AttendanceMutations`.

### Dérivations — `lib/core/utils/payroll_math.dart`

- `PayrollRules` : `defaultOvertimeMultiplier` (1.25), `defaultWorkingDaysPerMonth` (26).
- `hourlyRate(employee, settings)` — `extra` : `pay` (déjà €/h) ; `fixed` :
  `pay ÷ workingDaysPerMonth ÷ 8h`.
- `dayAmount(day, employee, settings, {scheduledEndMinutes})` — 0 si le jour n'est pas
  `done` ; sinon `taux × heures travaillées + (multiplicateur − 1) × taux × heures sup`.
- `periodTotals(days, …)` → `({days, workedHours, overtimeHours})`.
- `periodAmount(days, …)` → la somme des `dayAmount`.

### `StoreSettings` gagne deux champs

`overtimeMultiplier` (double) et `workingDaysPerMonth` (int), défauts depuis `PayrollRules`.
Répercutés dans `mock_store_settings`, `AccountMutations.updateStoreSettings`, la section
**« Paie »** de `store_settings_page.dart` (majoration + jours ouvrés). Sablon utilise une
majoration de **1,5** pour rendre la personnalisation par magasin démoable.

---

## 2. Données de démonstration — `lib/mock_data/mock_payroll_periods.dart`

**Un** `PayrollPeriod` payé (id `payroll-seed-karim`) : Marc a payé Karim pour ses deux
jours terminés d'il y a 2 et 3 jours — ces lignes portent déjà `paymentStatus: paid` et cet
id depuis le seed du pointage. Assez pour que l'historique ait une ligne réelle et que la
règle « un jour payé est verrouillé » soit démoable.

---

## 3. Couche d'écriture — `lib/mock_data/mutations/payroll_mutations.dart`

**Le seul fichier qui écrit un `PayrollPeriod`, et le seul chemin qui passe une
`Attendance` à `paid`** (via `AttendanceMutations.lockForPayroll`, comme la réception de
commande passe par `MovementMutations` plutôt que d'écrire les quantités elle-même).

| Méthode | Rôle |
|---|---|
| `preview(employeeId, storeId)` | Tout ce qui est dû *maintenant* : les jours `done` non payés de l'employé + les totaux + le montant. **Ne persiste rien** (comme un brouillon de réception). Renvoie un `PayrollPreview`. |
| `pay(employeeId, storeId, {paidByEmployeeId, now})` | Paie tout ce que `preview` montre : crée le `PayrollPeriod` (statut `paid`, `appliedRate` figé) **et** verrouille ses jours, en une écriture atomique (un seul `MockWrite.changed()`). Renvoie `null` si rien à payer, employé introuvable, ou un jour est passé en `paid` entre-temps. |

`AttendanceMutations.lockForPayroll(ids, payrollPeriodId)` — pose `paid` + l'id sur chaque
jour ; refuse (rien touché) si un id manque ou est déjà payé ; n'émet pas le signal (le
caller le fait). Garde un seul writer pour `mockAttendances`.

`mockPayrollPeriods` dans `MockWrite.captureSeed()/reset()` + `mock_write_test.dart`.

### Requêtes

`payrollPeriodById(id)`, `payrollPeriodsForEmployee(employeeId)`,
`payrollPeriodsForStore(storeId, {withinDays, employeeQuery, page, pageSize})` (paginé,
plus-récent-d'abord, même forme que `attendancesForStore`).

---

## 4. Écrans

### `payroll_history_page.dart` (route `/employees/payroll`)

`goSection`. Bandeau KPI (`StatTile`) : Paiements · Masse salariale · Employés payés ·
Heures sup payées — sur la fenêtre filtrée. Filtres : employé (`SearchField`), période
(`FilterMenu` : 30 / 90 jours / 12 mois / Tout). Tableau `DataTableWrapper` (Employé,
Période, Jours, Heures, Heures sup, Montant, Payé le, Par) dans un scroll vertical,
`Paginator`. Bouton **« Nouveau paiement »** → `payrollNew`. Deux états vides.

### `payroll_new_page.dart` (route `/employees/payroll/new`, poussée)

Écran poussé (contrôle retour « Historique de paiement »). `AppDropdown` employé actif →
`PayrollMutations.preview` → liste jour par jour + totaux (travaillé / heures sup /
**montant**) → bouton **« Payer »** → `ConfirmDialog` nommant l'employé et le montant →
`PayrollMutations.pay(paidByEmployeeId: mockCurrentEmployee.id)` → snackbar → retour à
l'historique. Si rien dû : message « tous les jours pointés sont déjà réglés ».

### Nettoyage

`employee_section_placeholder_page.dart` et l'enum `EmployeeSection` **supprimés** — les
quatre sous-pages de « Gestion Employée » sont maintenant toutes réelles.

---

## 5. Widget partagé — `lib/shared/widgets/filter_menu.dart`

`FilterMenu<T>({label, selectedLabel, entries, onSelected})` — la paire `FilterPill` +
`PopupMenuButton` extraite du `_Menu` privé de l'historique de pointage, désormais partagée
par les deux historiques.

---

## 6. Traductions

~50 clés ajoutées à `app_fr.arb` (`storeSettingsPayroll*`, `payrollHistory*`, `payrollStat*`,
`payrollColumn*`, `payrollNew*`, `payrollPeriodLastYear`), régénérées.

---

## 7. Tests

- **`test/payroll_test.dart`** (nouveau) — le taux horaire fixe vs extra ; la prime heures
  sup ; un jour non `done` vaut 0 ; `preview` somme et ne persiste rien ; `pay` crée la
  période, verrouille chaque jour, fige `appliedRate` (une augmentation ultérieure ne
  bouge pas la période) ; un jour verrouillé refuse toute écriture de pointage ; payer
  sans rien dû renvoie `null` ; le seed est cohérent ; `reset` restaure période + verrous.
- **`test/mock_data_test.dart`** — chaque `PayrollPeriod` pointe sur un magasin/employé
  réel et ses jours couverts sont tous `paid` ; `StoreSettings` a des coefficients de paie
  sains.
- **`test/mock_write_test.dart`** — `mockPayrollPeriods` dans la restauration intégrale.
- **`test/router_test.dart`** — les routes `payroll` et `payroll/new` rendent les vrais
  écrans (déjà couvertes aux 3 tailles).

---

## 8. Hypothèses / écarts

1. **Pas de sélecteur de plage pour le paiement** — le flux « Nouveau paiement » paie
   *tout ce qui est dû* à un employé (ses jours `done` non payés). `startDate`/`endDate`
   sont calculés depuis ces jours. Plus simple et sans ambiguïté qu'un sélecteur de mois.
2. **`PayrollStatus.computed` n'est jamais persisté** — le preview n'est pas stocké ; le
   seul statut qui atterrit dans la liste est `paid`. L'enum garde `computed` pour la
   Phase 2.
3. **Heures sup mesurées vs l'heure de fin résolue** (cohérent avec la Phase 3), pas vs un
   seuil de 8h/jour.
4. **Prime heures sup** = `(multiplicateur − 1) × taux` en plus des heures déjà comptées
   dans les heures travaillées — pas un remplacement du taux.

---

## 9. État de la qualité

- `flutter analyze` — **No issues found**.
- `flutter test` — **402 tests passent** (0 échec).
- `python tool/ux_audit.py` — **0 violation** sur les 12 contrôles.
