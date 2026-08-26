import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/timeclock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'employees_list_page.dart' show employeeInitials;

/// A rolling window for the Historique tab's period filter — a page-local
/// equivalent of `stock_history_page.dart`'s `HistoryPeriod`, duplicated
/// rather than imported so this feature does not reach sideways into
/// `stock_movement/`.
enum _HistoryPeriod {
  last7(7),
  last30(30),
  last90(90),
  all(null);

  const _HistoryPeriod(this.days);

  final int? days;
}

/// The pointage board — *Aujourd'hui* / *Historique*.
///
/// Reached via the sidebar's Employés flyout, so — like [EmployeesListPage] —
/// it is a `goSection` destination and carries no back control.
///
/// The two tabs are views of one screen, not two routes, so they switch in
/// place through local state exactly like `order_detail_page.dart`'s
/// Lignes/Réceptions — per the brief's assumption 5.
///
/// *Aujourd'hui*: one card per **active** employee only — archived employees
/// have nothing to punch, per `docs/page_personelle.md` §2. Cards with
/// nothing to do yet (`notClockedIn`) sort first, so someone finding their
/// own card at the start of a shift does not have to scan the whole list.
///
/// *Historique*: the filterable attendance log across every employee and
/// day, built on [MockQueries.timeEntriesForStore] — a stat-tile header,
/// `stock_history_page.dart`-style filter pills plus removable active-filter
/// chips, a [DataTableWrapper] grid, and a detail side panel opened per row.
class TimeclockBoardPage extends ConsumerStatefulWidget {
  const TimeclockBoardPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<TimeclockBoardPage> createState() => _TimeclockBoardPageState();
}

class _TimeclockBoardPageState extends ConsumerState<TimeclockBoardPage> {
  static const String _tabToday = 'today';
  static const String _tabHistory = 'history';

  String _tab = _tabToday;

  String _todayQuery = '';

  _HistoryPeriod _period = _HistoryPeriod.last30;
  TimeEntryStatus? _status;
  String _employeeQuery = '';
  TimeEntry? _selectedEntry;

  @override
  Widget build(BuildContext context) {
    // The board is written to directly, so it has to redraw when a card's
    // status changes — including the one currently on screen — and the
    // Historique tab has to pick up the same writes immediately.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.timeclockBoardTitle,
      subtitle: l10n.timeclockBoardSubtitle,
      scrollable: false,
      actions: const [_LiveClock()],
      tabs: SectionTabs(
        currentPath: _tab,
        onSelected: (value) => setState(() => _tab = value),
        tabs: [
          SectionTab(label: l10n.timeclockTabToday, path: _tabToday),
          SectionTab(label: l10n.timeclockTabHistory, path: _tabHistory),
        ],
      ),
      child: _tab == _tabToday ? _buildToday(l10n) : _buildHistory(l10n),
    );
  }

  Widget _buildToday(AppLocalizations l10n) {
    final all = MockQueries.activeEmployeesForStore(widget.storeId)
      ..sort((a, b) {
        final rankA = _statusRank(MockQueries.timeEntryForToday(a.id));
        final rankB = _statusRank(MockQueries.timeEntryForToday(b.id));
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.fullName.compareTo(b.fullName);
      });
    final employees = _filteredToday(all);

    if (all.isEmpty) {
      return EmptyState(
        icon: LucideIcons.idCard,
        title: l10n.timeclockBoardEmpty,
        message: l10n.timeclockBoardEmptyBody,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchField(
          hint: l10n.employeesSearchHint,
          initialValue: _todayQuery,
          onChanged: (value) => setState(() => _todayQuery = value),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: employees.isEmpty
              ? EmptyState.noResults(
                  l10n,
                  onClearFilters: () => setState(() => _todayQuery = ''),
                )
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: context.gridColumns(max: 4),
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: 300,
                  ),
                  itemCount: employees.length,
                  itemBuilder: (context, index) => _EmployeeCard(
                    employee: employees[index],
                    storeId: widget.storeId,
                  ),
                ),
        ),
      ],
    );
  }

  List<Employee> _filteredToday(List<Employee> employees) {
    final query = _todayQuery.trim().toLowerCase();
    if (query.isEmpty) return employees;
    return employees
        .where(
          (employee) =>
              employee.fullName.toLowerCase().contains(query) ||
              employee.cin.toLowerCase().contains(query),
        )
        .toList();
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

  /// Not-yet-clocked-in first, finished last — see the class doc.
  static int _statusRank(TimeEntry? entry) {
    switch (entry?.status ?? TimeEntryStatus.notClockedIn) {
      case TimeEntryStatus.notClockedIn:
        return 0;
      case TimeEntryStatus.onShift:
      case TimeEntryStatus.onBreak:
        return 1;
      case TimeEntryStatus.clockedOut:
        return 2;
    }
  }
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

/// The Historique tab's KPI header — four counts read off the store's
/// **entire** attendance log, independent of whatever the filters below
/// currently narrow the table to (same split the reference design uses:
/// "1,248 total" next to a filtered "248 résultats"). Every number here is a
/// plain count over real fields — no fabricated "vs last period" comparison,
/// since nothing in the model tracks a previous period to compare against.
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: context.gridColumns(max: 4),
      crossAxisSpacing: AppSpacing.lg,
      mainAxisSpacing: AppSpacing.lg,
      childAspectRatio: 2.1,
      children: [
        _StatTile(
          label: l10n.timeclockStatTotal,
          value: '${entries.length}',
          icon: LucideIcons.clipboardList,
        ),
        _StatTile(
          label: l10n.timeclockStatInProgress,
          value: '$inProgress',
          icon: LucideIcons.clock,
          accent: AppColors.inStock,
        ),
        _StatTile(
          label: l10n.timeclockStatLate,
          value: '$late',
          icon: LucideIcons.triangleAlert,
          accent: late == 0 ? null : AppColors.lowStock,
        ),
        _StatTile(
          label: l10n.timeclockStatFinished,
          value: '$finished',
          icon: LucideIcons.circleCheck,
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

/// The Historique grid — one row per [TimeEntry], every timestamp broken into
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

/// Today's date and a ticking clock.
///
/// Isolated in its own [StatefulWidget] with its own [Timer.periodic] so the
/// once-a-second tick redraws only this small header, not the employee list
/// beneath it — that only needs to redraw on [mockDataRevisionProvider]
/// changes, same as every other screen in the app.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.dateLong(_now),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(Formatters.time(_now), style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

/// A vertical pointage card: identity, status, the day's timestamp log, and
/// one full-width action button — mirrors the "Pointage RH" board reference
/// design rather than the earlier row layout.
class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.storeId});

  final Employee employee;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = MockQueries.timeEntryForToday(employee.id);
    final status = entry?.status ?? TimeEntryStatus.notClockedIn;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(employee: employee),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      l10n.employeeCinLabel(employee.cin),
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
          const SizedBox(height: AppSpacing.sm),
          TimeEntryStatusBadge(status: status),
          const SizedBox(height: AppSpacing.sm),
          if (entry != null) _TimestampLog(entry: entry),
          const Spacer(),
          _ActionArea(entry: entry, employee: employee, storeId: storeId),
        ],
      ),
    );
  }
}

/// The card's timestamp log — one dot-marked line per timestamp the day's
/// entry has recorded so far, oldest first. A day with fewer events (e.g.
/// still on the first shift, no break yet) simply shows fewer lines; the
/// [Spacer] above the action button absorbs the difference so every card in
/// the grid still lines up.
class _TimestampLog extends StatelessWidget {
  const _TimestampLog({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final rows = <Widget>[];
    void addRow(DateTime? at, String label, Color dotColor) {
      if (at == null) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(_LogLine(time: at, label: label, dotColor: dotColor));
    }

    addRow(entry.clockInAt, l10n.timeclockLogClockIn, AppColors.inStock.solid);
    addRow(
      entry.breakStartAt,
      l10n.timeclockLogBreakStart,
      AppColors.lowStock.solid,
    );
    addRow(
      entry.breakEndAt,
      l10n.timeclockLogBreakEnd,
      AppColors.inStock.solid,
    );
    addRow(
      entry.clockOutAt,
      l10n.timeclockLogClockOut,
      AppColors.textSecondary,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.time, required this.label, required this.dotColor});

  final DateTime time;
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(Formatters.time(time), style: theme.textTheme.bodySmall),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

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

/// The 4-state button, or a read-only summary once the day is finished.
///
/// Reflects whatever [TimeEntryStatus] today's entry reports rather than
/// tracking its own state — the one-break-per-day rule is enforced by
/// `TimeclockMutations`, and this widget just renders the result. "No break
/// yet" versus "break already taken" is told apart by whether `breakEndAt`
/// is set, per the brief.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.entry,
    required this.employee,
    required this.storeId,
  });

  final TimeEntry? entry;
  final Employee employee;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = entry;

    if (current == null) {
      return _TimeclockActionButton(
        label: l10n.timeclockButtonClockIn,
        icon: LucideIcons.circle,
        color: AppColors.inStock.solid,
        onPressed: () {
          final created = TimeclockMutations.clockIn(employee.id, storeId);
          if (created == null) return;
          AppSnackBar.success(
            context,
            l10n.timeclockClockInSuccess(employee.fullName),
          );
        },
      );
    }

    switch (current.status) {
      // Never actually stored on a real entry — see the TimeEntry model doc.
      // Kept only so this switch is exhaustive.
      case TimeEntryStatus.notClockedIn:
        return const SizedBox.shrink();

      case TimeEntryStatus.onShift:
        if (current.breakEndAt == null) {
          return _TimeclockActionButton(
            label: l10n.timeclockButtonStartBreak,
            icon: LucideIcons.pause,
            color: AppColors.inStock.solid,
            onPressed: () {
              final updated = TimeclockMutations.startBreak(current.id);
              if (updated == null) return;
              AppSnackBar.success(
                context,
                l10n.timeclockBreakStartSuccess(employee.fullName),
              );
            },
          );
        }
        return _TimeclockActionButton(
          label: l10n.timeclockButtonClockOut,
          icon: LucideIcons.circleCheck,
          color: AppColors.steel700,
          onPressed: () {
            final updated = TimeclockMutations.clockOut(current.id);
            if (updated == null) return;
            AppSnackBar.success(
              context,
              l10n.timeclockClockOutSuccess(employee.fullName),
            );
          },
        );

      case TimeEntryStatus.onBreak:
        return _TimeclockActionButton(
          label: l10n.timeclockButtonEndBreak,
          icon: LucideIcons.play,
          color: AppColors.lowStock.solid,
          onPressed: () {
            final updated = TimeclockMutations.endBreak(current.id);
            if (updated == null) return;
            AppSnackBar.success(
              context,
              l10n.timeclockBreakEndSuccess(employee.fullName),
            );
          },
        );

      case TimeEntryStatus.clockedOut:
        return _ClockedOutSummary(entry: current);
    }
  }
}

/// The full-width, status-coloured button one card offers at a time — never
/// more than one per card, so the "at most one call to action" rule still
/// holds locally even though the grid shows many cards at once. Colours are
/// existing palette tokens, not new ones: green for the two "keep going"
/// actions ([AppColors.inStock]), amber for "on a break" ([AppColors.lowStock]),
/// and the chrome [AppColors.steel700] for the one action that ends the day.
class _TimeclockActionButton extends StatelessWidget {
  const _TimeclockActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: AppSizing.iconSm),
        label: Text(label.toUpperCase()),
      ),
    );
  }
}

/// A finished day's card: a disabled "Terminé" button, plus what happened
/// above it when there is something worth flagging (a late break, overtime).
class _ClockedOutSummary extends StatelessWidget {
  const _ClockedOutSummary({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final worked = workedDuration(entry);
    final over = overtime(entry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entry.isLate || (over != null && over > Duration.zero)) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.isLate) ...[
                Tooltip(
                  message: l10n.employeeHistoryLate,
                  child: Icon(
                    LucideIcons.triangleAlert,
                    size: AppSizing.iconSm,
                    color: AppColors.lowStock.foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (worked != null)
                Text(
                  l10n.timeclockWorkedDuration(Formatters.duration(worked)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
              foregroundColor: AppColors.textSecondary,
              disabledBackgroundColor: AppColors.surfaceVariant,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            onPressed: null,
            icon: const Icon(LucideIcons.circleCheck, size: AppSizing.iconSm),
            label: Text(l10n.timeEntryStatusClockedOut.toUpperCase()),
          ),
        ),
      ],
    );
  }
}
