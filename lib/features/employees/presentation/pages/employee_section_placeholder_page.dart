import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// Which not-yet-built Gestion Employée section this stands in for.
enum EmployeeSection { timeclock, attendanceHistory, payroll }

/// A deliberate "bientôt disponible" screen for the three Gestion Employée
/// sub-pages whose real implementation lands in Phases 3–5 of the rebuild
/// (see `.claude/phase_gestion_employee.md`).
///
/// It exists so the sidebar dropdown can carry all four items from Phase 2 —
/// the section is real and routed, the screen is just not built yet. Each
/// phase swaps its placeholder for the real page. Honest, not a half-feature:
/// the message says exactly what it is.
class EmployeeSectionPlaceholderPage extends StatelessWidget {
  const EmployeeSectionPlaceholderPage({
    required this.storeId,
    required this.section,
    super.key,
  });

  final String storeId;
  final EmployeeSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final (title, message) = switch (section) {
      EmployeeSection.timeclock => (
        l10n.employeesNavTimeclock,
        l10n.employeeSectionComingSoonTimeclock,
      ),
      EmployeeSection.attendanceHistory => (
        l10n.employeesNavAttendanceHistory,
        l10n.employeeSectionComingSoonAttendanceHistory,
      ),
      EmployeeSection.payroll => (
        l10n.employeesNavPayroll,
        l10n.employeeSectionComingSoonPayroll,
      ),
    };

    return ShellPage(
      title: title,
      scrollable: false,
      child: EmptyState(
        icon: LucideIcons.hardHat,
        title: l10n.employeeSectionComingSoonTitle,
        message: message,
      ),
    );
  }
}
