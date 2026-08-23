import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A bordered, horizontally scrollable container for a [DataTable].
///
/// Wide tables are unavoidable on the pricing and comparison screens. This
/// keeps the horizontal overflow *inside* the table — the page itself must
/// never scroll sideways, which on a tablet is disorienting and easy to trigger
/// by accident with a stray thumb.
class DataTableWrapper extends StatelessWidget {
  const DataTableWrapper({
    required this.columns,
    required this.rows,
    this.minWidth = 720,
    this.sortColumnIndex,
    this.sortAscending = true,
    super.key,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;

  /// Below this the table scrolls rather than squeezing its columns.
  final double minWidth;

  final int? sortColumnIndex;
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final table = ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth < minWidth
                  ? minWidth
                  : constraints.maxWidth,
            ),
            child: DataTable(
              columns: columns,
              rows: rows,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.surfaceVariant,
              ),
              dividerThickness: 1,
              showCheckboxColumn: false,
            ),
          );

          if (constraints.maxWidth >= minWidth) return table;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          );
        },
      ),
    );
  }
}

/// A right-aligned numeric cell.
///
/// Money and quantities belong on the right so digits line up by place value —
/// with the tabular figures from the type scale, columns become comparable at a
/// glance instead of requiring the user to read every row.
class NumericCell extends StatelessWidget {
  const NumericCell(this.text, {this.style, this.emphasis = false, super.key});

  final String text;
  final TextStyle? style;

  /// Bold, for the value the row is actually about.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: (style ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
          fontWeight: emphasis ? FontWeight.w700 : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
