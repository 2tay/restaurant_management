import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// One line of a [DaySummaryTable].
class DaySummaryRow {
  const DaySummaryRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Lets a test find this value without matching its text.
  final Key? valueKey;

  /// Sets the value in the tabular money style — the day's amount.
  final bool emphasis;
}

/// The bordered label / value table that closes a day's drawer — the
/// pointage drawers' worked time and breaks, the payment drawer's same two
/// plus the rate and the amount. Labels on the left, values right-aligned.
class DaySummaryTable extends StatelessWidget {
  const DaySummaryTable({required this.rows, super.key});

  final List<DaySummaryRow> rows;

  static const EdgeInsets _cellPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    return Table(
      border: TableBorder.all(
        color: AppColors.border,
        borderRadius: AppRadius.smAll,
      ),
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: _cellPadding,
                child: Text(row.label, style: labelStyle),
              ),
              Padding(
                padding: _cellPadding,
                child: Text(
                  row.value,
                  key: row.valueKey,
                  style: row.emphasis
                      ? AppTypography.numeric
                      : theme.textTheme.titleSmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
