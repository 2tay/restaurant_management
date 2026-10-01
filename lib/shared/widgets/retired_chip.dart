import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'status_pill.dart';

/// « Retiré », the small red chip after a retired employee's name — on the
/// Personnel table, and wherever a retired person still shows up (the payroll
/// screen, while they are owed days).
class RetiredChip extends StatelessWidget {
  const RetiredChip({super.key});

  @override
  Widget build(BuildContext context) => LabelChip(
    label: AppLocalizations.of(context).employeesArchivedPill,
    background: AppColors.outOfStock.container,
    foreground: AppColors.outOfStock.foreground,
    dense: true,
    borderRadius: AppRadius.smAll,
  );
}
