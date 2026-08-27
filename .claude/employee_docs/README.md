# employee_docs

Completion docs for the **Gestion Employée** rebuild. The plan/contract is
[`.claude/phase_gestion_employee.md`](../phase_gestion_employee.md).

**One file per phase, written at the end of that phase** — a plain overview so whoever picks
the code up next does not have to recompose it from the commits. Same purpose and French style
as the archived [`_archive/page_personelle_v1.md`](./_archive/page_personelle_v1.md).

| File | Phase | Status |
|---|---|---|
| `phase_1_teardown.md` | 1 — Teardown | **done** — analyze clean, 311 tests, ux_audit 0 |
| `phase_2_employee_page.md` | 2 — Foundations + page Employée | **done** — analyze clean, 364 tests, ux_audit 0 |
| `phase_3_timeclock_board.md` | 3 — Tableau de bord | **done** — analyze clean, 383 tests, ux_audit 0 |
| `phase_4_attendance_history.md` | 4 — Historique de pointage | **done** — analyze clean, 391 tests, ux_audit 0 |
| `phase_5_payroll.md` | 5 — Historique de paiement | not started |
| `phase_6_auth_permissions.md` | 6 — Auth + permissions | not started |

Each completion doc should cover, at minimum:

- **Ce qui existe** — the screens, models, mutations, queries added or changed
- **Modèle de données** — the shapes, with the reasoning behind any non-obvious choice
- **Couche d'écriture** — which mutation owns what, the refused-state rules
- **Routes et navigation** — new paths, sidebar changes
- **Widgets partagés** — what landed in `lib/shared/widgets/` and why
- **Tests** — what is pinned, and where
- **Hypothèses / écarts** — decisions taken during implementation, and anything left for later
- **État de la qualité** — `flutter analyze` / `flutter test` / `ux_audit.py` at phase close
