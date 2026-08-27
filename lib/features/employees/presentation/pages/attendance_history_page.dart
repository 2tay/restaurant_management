import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// A rolling window for the period filter — the same shape
/// `stock_history_page.dart` and the reports pages use, kept local rather
/// than imported so this feature does not reach sideways into another.
enum _Period {
  last7(7),
  last30(30),
  last90(90),
  all(null);

  const _Period(this.days);
  final int? days;
}

const int _pageSize = 25;

/// The filterable attendance log across every employee and day — reached from
/// the Gestion Employée dropdown, so a `goSection` destination with no back
/// control.
class AttendanceHistoryPage extends ConsumerStatefulWidget {
  const AttendanceHistoryPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<AttendanceHistoryPage> createState() =>
      _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState
    extends ConsumerState<AttendanceHistoryPage> {
  _Period _period = _Period.last30;
  AttendanceStatus? _status;
  String _employeeQuery = '';
  int _page = 0;
  Attendance? _selected;

  @override
  Widget build(BuildContext context) {
    // Written to directly by the pointage board, so this page redraws when a
    // card's status changes elsewhere.
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.attendanceHistoryTitle,
      subtitle: l10n.attendanceHistorySubtitle,
      scrollable: false,
      child: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final stats = MockQueries.attendanceStatsForStore(
      widget.storeId,
      withinDays: _period.days,
    );
    final result = MockQueries.attendancesForStore(
      widget.storeId,
      withinDays: _period.days,
      status: _status,
      employeeQuery: _employeeQuery.trim().isEmpty ? null : _employeeQuery,
      page: _page,
      pageSize: _pageSize,
    );
    // The clamp inside the query can move us; keep local state in step.
    if (result.page != _page) _page = result.page;

    final storeEmpty =
        MockQueries.attendancesForStore(widget.storeId).totalCount == 0;
    final settings = MockQueries.storeSettings(widget.storeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        _Filters(
          period: _period,
          status: _status,
          employeeQuery: _employeeQuery,
          onPeriod: (p) => setState(() {
            _period = p;
            _page = 0;
          }),
          onStatus: (s) => setState(() {
            _status = s;
            _page = 0;
          }),
          onEmployee: (q) => setState(() {
            _employeeQuery = q;
            _page = 0;
          }),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(height: AppSpacing.sm),
          _ActiveFilters(
            period: _period,
            status: _status,
            employeeQuery: _employeeQuery,
            onClear: _clearFilters,
            onRemovePeriod: () => setState(() => _period = _Period.all),
            onRemoveStatus: () => setState(() => _status = null),
            onRemoveEmployee: () => setState(() => _employeeQuery = ''),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.attendanceHistoryCount(result.totalCount),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: result.rows.isEmpty
              ? _emptyState(l10n, storeEmpty)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: _HistoryTable(
                                rows: result.rows,
                                settings: settings,
                                selected: _selected,
                                onSelect: (a) =>
                                    setState(() => _selected = a),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Paginator(
                            page: result.page,
                            pageCount: result.pageCount,
                            totalCount: result.totalCount,
                            pageSize: _pageSize,
                            onChanged: (p) => setState(() {
                              _page = p;
                              _selected = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(
                        width: 320,
                        child: _DetailPanel(
                          attendance: _selected!,
                          settings: settings,
                          onClose: () => setState(() => _selected = null),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  bool get _hasActiveFilters =>
      _period != _Period.all ||
      _status != null ||
      _employeeQuery.trim().isNotEmpty;

  void _clearFilters() => setState(() {
    _period = _Period.all;
    _status = null;
    _employeeQuery = '';
    _page = 0;
  });

  Widget _emptyState(AppLocalizations l10n, bool storeEmpty) => EmptyState(
    icon: LucideIcons.history,
    title: storeEmpty
        ? l10n.attendanceHistoryEmpty
        : l10n.emptyStateNoResultsTitle,
    message: storeEmpty
        ? l10n.attendanceHistoryEmptyBody
        : l10n.emptyStateNoResultsBody,
    actionLabel: storeEmpty ? null : l10n.inventoryClearFilters,
    onAction: storeEmpty ? null : _clearFilters,
  );
}

String _periodLabel(AppLocalizations l10n, _Period period) => switch (period) {
  _Period.last7 => l10n.periodLast7Days,
  _Period.last30 => l10n.periodLast30Days,
  _Period.last90 => l10n.periodLast90Days,
  _Period.all => l10n.periodAll,
};

// -----------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});

  final ({
    int days,
    Duration worked,
    int lateArrivals,
    Duration overtime,
    int lateBreaks,
  })
  stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.attendanceStatDays,
            value: '${stats.days}',
            icon: LucideIcons.clipboardList,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.attendanceStatWorked,
            value: Formatters.duration(stats.worked),
            icon: LucideIcons.clock,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.attendanceStatLate,
            value: '${stats.lateArrivals}',
            icon: LucideIcons.triangleAlert,
            accent: stats.lateArrivals == 0 ? null : AppColors.lowStock,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.attendanceStatOvertime,
            value: Formatters.duration(stats.overtime),
            icon: LucideIcons.hourglass,
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.period,
    required this.status,
    required this.employeeQuery,
    required this.onPeriod,
    required this.onStatus,
    required this.onEmployee,
  });

  final _Period period;
  final AttendanceStatus? status;
  final String employeeQuery;
  final ValueChanged<_Period> onPeriod;
  final ValueChanged<AttendanceStatus?> onStatus;
  final ValueChanged<String> onEmployee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: SearchField(
            hint: l10n.employeesSearchHint,
            initialValue: employeeQuery,
            onChanged: onEmployee,
          ),
        ),
        _Menu<_Period>(
          label: l10n.movementsFilterPeriod,
          selectedLabel: _periodLabel(l10n, period),
          entries: {
            for (final p in _Period.values) p: _periodLabel(l10n, p),
          },
          onSelected: onPeriod,
        ),
        _Menu<AttendanceStatus?>(
          label: l10n.ordersFilterStatus,
          selectedLabel: status == null
              ? null
              : attendanceStatusLabel(l10n, status!),
          entries: {
            null: l10n.ordersFilterAllStatuses,
            for (final s in const [
              AttendanceStatus.working,
              AttendanceStatus.onBreak,
              AttendanceStatus.done,
            ])
              s: attendanceStatusLabel(l10n, s),
          },
          onSelected: onStatus,
        ),
      ],
    );
  }
}

/// [FilterPill] as a [PopupMenuButton]'s child — the pairing every filterable
/// list in the app uses.
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

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.period,
    required this.status,
    required this.employeeQuery,
    required this.onClear,
    required this.onRemovePeriod,
    required this.onRemoveStatus,
    required this.onRemoveEmployee,
  });

  final _Period period;
  final AttendanceStatus? status;
  final String employeeQuery;
  final VoidCallback onClear;
  final VoidCallback onRemovePeriod;
  final VoidCallback onRemoveStatus;
  final VoidCallback onRemoveEmployee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (period != _Period.all)
          _Chip(label: _periodLabel(l10n, period), onRemove: onRemovePeriod),
        if (status != null)
          _Chip(
            label: attendanceStatusLabel(l10n, status!),
            onRemove: onRemoveStatus,
          ),
        if (employeeQuery.trim().isNotEmpty)
          _Chip(label: employeeQuery.trim(), onRemove: onRemoveEmployee),
        TextButton(
          onPressed: onClear,
          child: Text(l10n.inventoryClearFilters),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});

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

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.rows,
    required this.settings,
    required this.selected,
    required this.onSelect,
  });

  final List<Attendance> rows;
  final StoreSettings settings;
  final Attendance? selected;
  final ValueChanged<Attendance> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 1000,
      columns: [
        DataColumn(label: Text(l10n.attendanceColumnDate)),
        DataColumn(label: Text(l10n.attendanceColumnEmployee)),
        DataColumn(label: Text(l10n.attendanceColumnArrival)),
        DataColumn(label: Text(l10n.attendanceColumnDeparture)),
        DataColumn(label: Text(l10n.attendanceColumnBreaks)),
        DataColumn(label: Text(l10n.attendanceColumnWorked)),
        DataColumn(label: Text(l10n.attendanceColumnOvertime)),
        DataColumn(label: Text(l10n.attendanceColumnStatus)),
        DataColumn(label: Text(l10n.attendanceColumnFlags)),
        DataColumn(label: Text(l10n.attendanceColumnActions)),
      ],
      rows: [
        for (final a in rows) _row(context, l10n, a),
      ],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Attendance a) {
    final employee = MockQueries.employeeById(a.employeeId);
    final schedule = employee == null
        ? (startMinutes: settings.openMinutes, endMinutes: settings.closeMinutes)
        : resolvedSchedule(
            employee,
            storeOpenMinutes: settings.openMinutes,
            storeCloseMinutes: settings.closeMinutes,
          );
    final worked = workedDuration(a);
    final overtime = overtimeBy(a, schedule.endMinutes);
    final late = isLate(a, schedule.startMinutes);
    final lateBreak = hasLateBreak(a, settings.maxBreakMinutes);

    return DataRow(
      selected: a.id == selected?.id,
      cells: [
        DataCell(Text(Formatters.date(a.date))),
        DataCell(
          Text(
            employee == null ? '—' : employeeDisplayName(employee),
          ),
        ),
        DataCell(Text(_time(a.clockInAt))),
        DataCell(Text(_time(a.clockOutAt))),
        DataCell(Text('${a.pauses.length}')),
        DataCell(
          Text(worked == null ? '—' : Formatters.duration(worked)),
        ),
        DataCell(
          Text(
            overtime == null || overtime == Duration.zero
                ? '—'
                : Formatters.duration(overtime),
          ),
        ),
        DataCell(AttendanceStatusBadge(status: a.status)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (late)
                Tooltip(
                  message: l10n.attendanceLate,
                  child: Icon(
                    LucideIcons.triangleAlert,
                    size: AppSizing.iconSm,
                    color: AppColors.lowStock.foreground,
                  ),
                ),
              if (lateBreak) ...[
                if (late) const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: l10n.attendanceBreakOverrun,
                  child: Icon(
                    LucideIcons.coffee,
                    size: AppSizing.iconSm,
                    color: AppColors.lowStock.foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
        DataCell(
          IconButton(
            tooltip: l10n.attendanceViewDetail,
            icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
            onPressed: () => onSelect(a),
          ),
        ),
      ],
    );
  }

  String _time(DateTime? at) => at == null ? '—' : Formatters.time(at);
}

/// The slide-in "Détail du pointage" column beside the table — a single day
/// has no page of its own, so its full pause list is shown here.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.attendance,
    required this.settings,
    required this.onClose,
  });

  final Attendance attendance;
  final StoreSettings settings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = MockQueries.employeeById(attendance.employeeId);
    final worked = workedDuration(attendance);

    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.attendanceDetailTitle,
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
                  EmployeeAvatar(employee: employee),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employeeDisplayName(employee),
                          style: theme.textTheme.titleSmall,
                        ),
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
            _Field(
              label: l10n.attendanceColumnDate,
              value: Formatters.date(attendance.date),
            ),
            _Field(
              label: l10n.attendanceColumnStatus,
              value: attendanceStatusLabel(l10n, attendance.status),
            ),
            _Field(
              label: l10n.attendanceColumnArrival,
              value: _time(attendance.clockInAt),
            ),
            _Field(
              label: l10n.attendanceColumnDeparture,
              value: _time(attendance.clockOutAt),
            ),
            _Field(
              label: l10n.attendanceColumnWorked,
              value: worked == null ? '—' : Formatters.duration(worked),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.attendanceDetailBreaks(attendance.pauses.length),
              style: theme.textTheme.bodyMedium,
            ),
            for (final pause in attendance.pauses)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: _BreakLine(
                  pause: pause,
                  over:
                      breakOverrun(pause, settings.maxBreakMinutes) >
                      Duration.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime? at) => at == null ? '—' : Formatters.time(at);
}

class _BreakLine extends StatelessWidget {
  const _BreakLine({required this.pause, required this.over});

  final AttendancePause pause;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = pause.endAt;
    final label = end == null
        ? '${Formatters.time(pause.startAt)} – …'
        : '${Formatters.time(pause.startAt)} – ${Formatters.time(end)}'
              ' (${Formatters.duration(end.difference(pause.startAt))})';

    return Row(
      children: [
        Icon(
          over ? LucideIcons.triangleAlert : LucideIcons.coffee,
          size: AppSizing.iconSm,
          color: over
              ? AppColors.lowStock.foreground
              : AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: over
                ? AppColors.lowStock.foreground
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
