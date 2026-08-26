import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/timeclock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'employees_list_page.dart' show employeeInitials;

/// A rolling window for the period filter — a page-local equivalent of
/// `stock_history_page.dart`'s `HistoryPeriod`, duplicated rather than
/// imported so this feature does not reach sideways into `stock_movement/`.
enum _HistoryPeriod {
  last7(7),
  last30(30),
  last90(90),
  all(null);

  const _HistoryPeriod(this.days);

  final int? days;
}

/// The filterable attendance log across every employee and day.
///
/// Reached via the sidebar's "Gestion des employés" flyout, so — like
/// [EmployeesListPage] and [TimeclockBoardPage] — it is a `goSection`
/// destination and carries no back control. Split out from the timeclock
/// board into its own page so Historique gets its own sidebar entry instead
/// of living behind a tab.
///
/// Built on [MockQueries.timeEntriesForStore] — a stat-tile header,
/// `stock_history_page.dart`-style filter pills plus removable active-filter
/// chips, a [DataTableWrapper] grid, and a detail side panel opened per row.
class TimeclockHistoryPage extends ConsumerStatefulWidget {
  const TimeclockHistoryPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<TimeclockHistoryPage> createState() =>
      _TimeclockHistoryPageState();
}

class _TimeclockHistoryPageState extends ConsumerState<TimeclockHistoryPage> {
  _HistoryPeriod _period = _HistoryPeriod.last30;
  TimeEntryStatus? _status;
  String _employeeQuery = '';
  TimeEntry? _selectedEntry;

  @override
  Widget build(BuildContext context) {
    // Written to directly by the timeclock board, so this page has to redraw
    // when a card's status changes elsewhere in the app.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.timeclockHistoryTitle,
      subtitle: l10n.timeclockHistorySubtitle,
      scrollable: false,
      child: _buildHistory(l10n),
    );
  }

  Widget _buildHistory(AppLocalizations l10n) {
    final allEntries = MockQueries.timeEntriesForStore(widget.storeId);
    final entries = _filteredHistory();
    final employees = MockQueries.employeesForStore(widget.storeId)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HistoryStatRow(entries: allEntries),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: SearchField(
                hint: l10n.employeesSearchHint,
                initialValue: _employeeQuery,
                onChanged: (value) => setState(() => _employeeQuery = value),
              ),
            ),
            _Menu<String?>(
              label: l10n.timeclockFilterEmployee,
              selectedLabel: employees.any((e) => e.fullName == _employeeQuery)
                  ? _employeeQuery
                  : null,
              entries: {
                null: l10n.timeclockFilterAllEmployees,
                for (final employee in employees)
                  employee.fullName: employee.fullName,
              },
              onSelected: (value) =>
                  setState(() => _employeeQuery = value ?? ''),
            ),
            _Menu<_HistoryPeriod>(
              label: l10n.movementsFilterPeriod,
              selectedLabel: _periodLabel(l10n, _period),
              entries: {
                for (final period in _HistoryPeriod.values)
                  period: _periodLabel(l10n, period),
              },
              onSelected: (value) => setState(() => _period = value),
            ),
            _Menu<TimeEntryStatus?>(
              label: l10n.ordersFilterStatus,
              selectedLabel: _status == null
                  ? null
                  : timeEntryStatusLabel(l10n, _status!),
              entries: {
                null: l10n.ordersFilterAllStatuses,
                for (final status in TimeEntryStatus.values)
                  status: timeEntryStatusLabel(l10n, status),
              },
              onSelected: (value) => setState(() => _status = value),
            ),
          ],
        ),
        if (_hasActiveHistoryFilters) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_period != _HistoryPeriod.all)
                _ActiveFilterChip(
                  label: _periodLabel(l10n, _period),
                  onRemove: () =>
                      setState(() => _period = _HistoryPeriod.all),
                ),
              if (_status != null)
                _ActiveFilterChip(
                  label: timeEntryStatusLabel(l10n, _status!),
                  onRemove: () => setState(() => _status = null),
                ),
              if (_employeeQuery.trim().isNotEmpty)
                _ActiveFilterChip(
                  label: _employeeQuery.trim(),
                  onRemove: () => setState(() => _employeeQuery = ''),
                ),
              TextButton(
                onPressed: _clearHistoryFilters,
                child: Text(l10n.inventoryClearFilters),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.timeclockHistoryCount(entries.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: LucideIcons.history,
                  title: allEntries.isEmpty
                      ? l10n.timeclockHistoryEmpty
                      : l10n.emptyStateNoResultsTitle,
                  message: allEntries.isEmpty
                      ? l10n.timeclockHistoryEmptyBody
                      : l10n.emptyStateNoResultsBody,
                  actionLabel: allEntries.isEmpty
                      ? null
                      : l10n.inventoryClearFilters,
                  onAction: allEntries.isEmpty ? null : _clearHistoryFilters,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HistoryTable(
                        entries: entries,
                        selectedEntry: _selectedEntry,
                        onSelect: (entry) =>
                            setState(() => _selectedEntry = entry),
                      ),
                    ),
                    if (_selectedEntry != null) ...[
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(
                        width: 320,
                        child: _HistoryDetailPanel(
                          entry: _selectedEntry!,
                          onClose: () =>
                              setState(() => _selectedEntry = null),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  bool get _hasActiveHistoryFilters =>
      _period != _HistoryPeriod.all ||
      _status != null ||
      _employeeQuery.trim().isNotEmpty;

  List<TimeEntry> _filteredHistory() => MockQueries.timeEntriesForStore(
    widget.storeId,
    withinDays: _period.days,
    status: _status,
    employeeQuery: _employeeQuery.trim().isEmpty ? null : _employeeQuery,
  );

  void _clearHistoryFilters() {
    setState(() {
      _period = _HistoryPeriod.all;
      _status = null;
      _employeeQuery = '';
    });
  }

  String _periodLabel(AppLocalizations l10n, _HistoryPeriod period) =>
      switch (period) {
        _HistoryPeriod.last7 => l10n.periodLast7Days,
        _HistoryPeriod.last30 => l10n.periodLast30Days,
        _HistoryPeriod.last90 => l10n.periodLast90Days,
        _HistoryPeriod.all => l10n.periodAll,
      };
}

/// A chip-shaped dropdown filter — the same pairing `stock_history_page.dart`
/// uses: [FilterPill] as the [PopupMenuButton]'s `child`, not its menu.
class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.label,
    required this.selectedLabel,
    required this.entries,
    required this.onSelected,
  });

  final String label;
  final String? selectedLabel;
  final Map<T, String> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (index) => onSelected(entries.keys.elementAt(index)),
      itemBuilder: (context) => [
        for (var i = 0; i < entries.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(entries.values.elementAt(i)),
          ),
      ],
      child: FilterPill(label: label, selectedLabel: selectedLabel),
    );
  }
}

/// The KPI header — four counts read off the store's **entire** attendance
/// log, independent of whatever the filters below currently narrow the table
/// to (same split the reference design uses: "1,248 total" next to a
/// filtered "248 résultats"). Every number here is a plain count over real
/// fields — no fabricated "vs last period" comparison, since nothing in the
/// model tracks a previous period to compare against.
class _HistoryStatRow extends StatelessWidget {
  const _HistoryStatRow({required this.entries});

  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final late = entries.where((e) => e.isLate).length;
    final finished = entries
        .where((e) => e.status == TimeEntryStatus.clockedOut)
        .length;
    final inProgress = entries
        .where(
          (e) =>
              e.status == TimeEntryStatus.onShift ||
              e.status == TimeEntryStatus.onBreak,
        )
        .length;

    // A fixed row rather than `context.gridColumns`-driven wrapping: that
    // helper sizes off the whole screen, not this column's actual width
    // beside the rail, so at a short viewport (1024x600) it can pick a
    // column count that wraps these four tiles onto a second row — fine on
    // a scrollable page, but this one sits above a fixed-height table and
    // has no slack to give a surprise extra row. Four compact KPI tiles
    // always fit one row at the tablet widths this app targets.
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.timeclockStatTotal,
            value: '${entries.length}',
            icon: LucideIcons.clipboardList,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _StatTile(
            label: l10n.timeclockStatInProgress,
            value: '$inProgress',
            icon: LucideIcons.clock,
            accent: AppColors.inStock,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _StatTile(
            label: l10n.timeclockStatLate,
            value: '$late',
            icon: LucideIcons.triangleAlert,
            accent: late == 0 ? null : AppColors.lowStock,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _StatTile(
            label: l10n.timeclockStatFinished,
            value: '$finished',
            icon: LucideIcons.circleCheck,
          ),
        ),
      ],
    );
  }
}

/// One KPI card — built the same way `SummaryTile` is on the dashboard, but
/// kept local rather than imported so this feature doesn't reach sideways
/// into `features/dashboard/`, same reasoning as `_HistoryPeriod` above.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final StockStatusColors? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = accent?.foreground ?? AppColors.textPrimary;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent?.container ?? AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconMd,
              color: accent?.foreground ?? AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: foreground,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One active filter, shown as a removable pill under the filter row so it's
/// obvious at a glance why the list looks the way it does — same instinct
/// [FilterPill] follows, but closable since several of these can stack.
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
      backgroundColor: AppColors.primaryContainer,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.onPrimaryContainer),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: AppColors.primary600),
      ),
      side: BorderSide.none,
    );
  }
}

/// The history grid — one row per [TimeEntry], every timestamp broken into
/// its own column so the whole day reads left to right without decoding a
/// joined string, plus a detail button that opens [_HistoryDetailPanel].
class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.entries,
    required this.selectedEntry,
    required this.onSelect,
  });

  final List<TimeEntry> entries;
  final TimeEntry? selectedEntry;
  final ValueChanged<TimeEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 900,
      columns: [
        DataColumn(label: Text(l10n.timeclockHistoryColumnDate)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnEmployee)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnCin)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnArrival)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnBreakStart)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnBreakEnd)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnDeparture)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnDuration)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnStatus)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnLate)),
        DataColumn(label: Text(l10n.timeclockHistoryColumnActions)),
      ],
      rows: [
        for (final entry in entries)
          DataRow(
            selected: entry.id == selectedEntry?.id,
            cells: [
              DataCell(Text(Formatters.date(entry.date))),
              DataCell(
                Text(
                  MockQueries.employeeById(entry.employeeId)?.fullName ?? '—',
                ),
              ),
              DataCell(
                Text(MockQueries.employeeById(entry.employeeId)?.cin ?? '—'),
              ),
              DataCell(Text(_time(entry.clockInAt))),
              DataCell(Text(_time(entry.breakStartAt))),
              DataCell(Text(_time(entry.breakEndAt))),
              DataCell(Text(_time(entry.clockOutAt))),
              DataCell(
                Text(
                  workedDuration(entry) == null
                      ? '—'
                      : Formatters.duration(workedDuration(entry)!),
                ),
              ),
              DataCell(TimeEntryStatusBadge(status: entry.status)),
              DataCell(
                entry.isLate
                    ? Tooltip(
                        message: l10n.employeeHistoryLate,
                        child: Icon(
                          LucideIcons.triangleAlert,
                          size: AppSizing.iconSm,
                          color: AppColors.lowStock.foreground,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              DataCell(
                IconButton(
                  tooltip: l10n.timeclockHistoryViewDetail,
                  icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
                  onPressed: () => onSelect(entry),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _time(DateTime? at) => at == null ? '—' : Formatters.time(at);
}

/// The slide-in "Détails du pointage" panel — a fixed-width column beside the
/// table, opened per row rather than as a separate route, since a single time
/// entry has no page of its own to push to.
class _HistoryDetailPanel extends StatelessWidget {
  const _HistoryDetailPanel({required this.entry, required this.onClose});

  final TimeEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = MockQueries.employeeById(entry.employeeId);
    final worked = workedDuration(entry);
    final over = overtime(entry);

    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.timeclockDetailTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.actionClose,
                  icon: const Icon(LucideIcons.x, size: AppSizing.iconSm),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (employee != null) ...[
              Row(
                children: [
                  _Avatar(employee: employee),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee.fullName, style: theme.textTheme.titleSmall),
                        Text(
                          l10n.employeeCinLabel(employee.cin),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _DetailField(
              label: l10n.timeclockHistoryColumnDate,
              value: Formatters.date(entry.date),
            ),
            _DetailField(
              label: l10n.timeclockHistoryColumnStatus,
              value: timeEntryStatusLabel(l10n, entry.status),
            ),
            _DetailField(
              label: l10n.timeclockHistoryColumnArrival,
              value: _time(entry.clockInAt),
            ),
            _DetailField(
              label: l10n.timeclockHistoryColumnBreakStart,
              value: _time(entry.breakStartAt),
            ),
            _DetailField(
              label: l10n.timeclockHistoryColumnBreakEnd,
              value: _time(entry.breakEndAt),
            ),
            _DetailField(
              label: l10n.timeclockHistoryColumnDeparture,
              value: _time(entry.clockOutAt),
            ),
            _DetailField(
              label: l10n.timeclockHistoryColumnDuration,
              value: worked == null ? '—' : Formatters.duration(worked),
            ),
            _DetailField(
              label: l10n.timeclockDetailOvertimeLabel,
              value: over == null || over == Duration.zero
                  ? '—'
                  : Formatters.duration(over),
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime? at) => at == null ? '—' : Formatters.time(at);
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Same small circular photo/initials tile every employee-facing page draws
/// locally rather than sharing — see `employees_list_page.dart`'s own
/// `_Avatar` for the precedent this follows.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = employee.photoAsset;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: photo != null
          ? Image.asset(photo, fit: BoxFit.cover, width: 48, height: 48)
          : Text(
              employeeInitials(employee.fullName),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
    );
  }
}
