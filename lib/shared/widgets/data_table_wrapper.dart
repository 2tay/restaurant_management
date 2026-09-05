import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A bordered, horizontally scrollable container for a [DataTable].
///
/// Wide tables are unavoidable on the pricing and comparison screens. This
/// keeps the horizontal overflow *inside* the table — the page itself must
/// never scroll sideways, which on a tablet is disorienting and easy to trigger
/// by accident with a stray thumb.
class DataTableWrapper extends StatefulWidget {
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
  State<DataTableWrapper> createState() => _DataTableWrapperState();
}

class _DataTableWrapperState extends State<DataTableWrapper> {
  /// Owned here rather than left implicit: a `Scrollbar` and the view it
  /// controls must share one controller, and an inherited `PrimaryScrollController`
  /// belongs to the page's vertical scroll, not this horizontal one.
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    final rows = widget.rows;
    final minWidth = widget.minWidth;
    final sortColumnIndex = widget.sortColumnIndex;
    final sortAscending = widget.sortAscending;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Floor the table at the wider of the available width and [minWidth],
          // then always allow horizontal scrolling. A DataTable sizes itself to
          // its content, and content can exceed the pane at any width — French
          // product names are long and the pricing table has four columns — so
          // "only scroll when narrow" is not a safe assumption.
          final floor = constraints.maxWidth < minWidth
              ? minWidth
              : constraints.maxWidth;

          final table = ConstrainedBox(
            constraints: BoxConstraints(minWidth: floor),
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

          // A visible scrollbar rather than the platform default, which on
          // desktop only fades in once the pointer moves. A table that scrolls
          // sideways with no sign that it does reads as a table with missing
          // columns — and on the pricing screens the columns off the right are
          // the ones the user came for.
          return Scrollbar(
            controller: _controller,
            thumbVisibility: constraints.maxWidth < floor,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: table,
            ),
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
