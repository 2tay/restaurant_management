import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

/// A deliberate "bientôt disponible" screen for the Gestion Employée section
/// not built yet — the payroll history, which lands in Phase 5 of the rebuild
/// (see `.claude/phase_gestion_employee.md`).
///
/// It exists so the sidebar dropdown can carry all four items from Phase 2 —
/// the section is real and routed, the screen is just not built yet. Honest,
/// not a half-feature: the message says exactly what it is.
class EmployeeSectionPlaceholderPage extends StatelessWidget {
  const EmployeeSectionPlaceholderPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.employeesNavPayroll,
      scrollable: false,
      child: EmptyState(
        icon: LucideIcons.hardHat,
        title: l10n.employeeSectionComingSoonTitle,
        message: l10n.employeeSectionComingSoonPayroll,
      ),
    );
  }
}
