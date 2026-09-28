import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The coloured edge down a row's left side.
const double _accentWidth = 3;

/// One column of an [AppTable].
@immutable
class AppTableColumn {
  const AppTableColumn({
    required this.label,
    this.flex = 1,
    this.width,
    this.numeric = false,
    this.minTableWidth = 0,
    this.sortKey,
  });

  final String label;

  /// Share of the leftover width, when [width] is not set.
  final int flex;

  /// A fixed width — for figures, badges and icons, which should line up
  /// from row to row whatever the name beside them.
  final double? width;

  /// Right-aligned, header included, so the digits line up.
  final bool numeric;

  /// The column is shown only when the table is at least this wide. Narrow
  /// screens drop the less important columns rather than scrolling the table
  /// sideways — a table you have to pan to read is a table nobody reads.
  final double minTableWidth;

  /// Set when tapping the header sorts by this column.
  final Object? sortKey;
}

/// The app's data table: a pinned header, then one line per row.
///
/// Built rather than taken from Flutter's `DataTable`, which lays out every
/// row up front and scrolls its header away with them. This one builds rows
/// lazily (a catalogue of a few hundred products stays smooth), keeps the
/// header in place, highlights the row under the pointer, marks a selected
/// row, and can draw a coloured edge per row — the movement type, the stock
/// status.
///
/// [shrinkWrap] lays every row out inline instead, for a short table inside a
/// scrolling page (the dashboard's panels).
class AppTable<T> extends StatelessWidget {
  const AppTable({
    required this.columns,
    required this.rows,
    required this.cell,
    this.onRowTap,
    this.isSelected,
    this.rowAccent,
    this.sortKey,
    this.sortAscending = true,
    this.onSort,
    this.shrinkWrap = false,
    this.bordered = true,
    this.rowHeight = 56,
    this.headerColor = AppColors.surfaceVariant,
    super.key,
  });

  final List<AppTableColumn> columns;
  final List<T> rows;

  /// The content of [row]'s cell in `columns[column]`. Only called for the
  /// columns shown at the current width.
  final Widget Function(BuildContext context, T row, int column) cell;

  final ValueChanged<T>? onRowTap;
  final bool Function(T row)? isSelected;

  /// A 3px edge down the row's left side, in this colour — or none.
  final Color? Function(T row)? rowAccent;

  /// The column the rows are sorted by, matched against
  /// [AppTableColumn.sortKey], and in which direction.
  final Object? sortKey;
  final bool sortAscending;
  final ValueChanged<Object>? onSort;

  final bool shrinkWrap;

  /// Draws the table's own rounded frame. Off inside a card that has one.
  final bool bordered;

  /// The minimum height of a row; a row grows if its content needs more.
  final double rowHeight;

  /// The header's background. Grey on a full page, where it marks the top of
  /// a long table; the page's own white inside a card, where a grey band
  /// would read as a second surface stacked on the first.
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final visible = [
          for (final (i, column) in columns.indexed)
            if (width >= column.minTableWidth) i,
        ];

        final header = _HeaderRow(
          color: headerColor,
          columns: [for (final i in visible) columns[i]],
          sortKey: sortKey,
          sortAscending: sortAscending,
          onSort: onSort,
        );

        Widget line(BuildContext context, int index) {
          final row = rows[index];
          return _DataRow(
            columns: [for (final i in visible) columns[i]],
            cells: [for (final i in visible) cell(context, row, i)],
            minHeight: rowHeight,
            selected: isSelected?.call(row) ?? false,
            accent: rowAccent?.call(row),
            last: index == rows.length - 1,
            onTap: onRowTap == null ? null : () => onRowTap!(row),
          );
        }

        final body = shrinkWrap
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  for (var i = 0; i < rows.length; i++) line(context, i),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      itemBuilder: line,
                    ),
                  ),
                ],
              );

        if (!bordered) return body;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: body,
        );
      },
    );
  }
}

/// Lays [cells] out under [columns]: fixed widths where set, the rest shared
/// by flex.
class _Cells extends StatelessWidget {
  const _Cells({required this.columns, required this.cells});

  final List<AppTableColumn> columns;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, column) in columns.indexed)
          if (column.width != null)
            SizedBox(width: column.width, child: _pad(column, cells[i]))
          else
            Expanded(flex: column.flex, child: _pad(column, cells[i])),
      ],
    );
  }

  Widget _pad(AppTableColumn column, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Align(
      alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.color,
    required this.columns,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
  });

  final Color color;
  final List<AppTableColumn> columns;
  final Object? sortKey;
  final bool sortAscending;
  final ValueChanged<Object>? onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: color,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      // Lines the headings up with the cells, which sit past the accent edge.
      padding: const EdgeInsets.only(left: _accentWidth),
      child: _Cells(
        columns: columns,
        cells: [
          for (final column in columns)
            _HeaderCell(
              column: column,
              style: style,
              active: column.sortKey != null && column.sortKey == sortKey,
              ascending: sortAscending,
              onTap: column.sortKey == null || onSort == null
                  ? null
                  : () => onSort!(column.sortKey!),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.style,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final AppTableColumn column;
  final TextStyle? style;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Flexible(
      child: Text(
        column.label.toUpperCase(),
        style: active ? style?.copyWith(color: AppColors.textPrimary) : style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final arrow = Icon(
      active
          ? (ascending ? LucideIcons.arrowUp : LucideIcons.arrowDown)
          : LucideIcons.arrowUpDown,
      size: 14,
      color: active ? AppColors.textPrimary : AppColors.textDisabled,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        if (onTap != null) ...[const SizedBox(width: AppSpacing.xs), arrow],
      ],
    );
    if (onTap == null) return content;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: content,
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.columns,
    required this.cells,
    required this.minHeight,
    required this.selected,
    required this.accent,
    required this.last,
    required this.onTap,
  });

  final List<AppTableColumn> columns;
  final List<Widget> cells;
  final double minHeight;
  final bool selected;
  final Color? accent;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryContainer : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.neutral50,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: _accentWidth,
                color: accent ?? Colors.transparent,
              ),
              bottom: last
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.hairline),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: _Cells(columns: columns, cells: cells),
        ),
      ),
    );
  }
}
