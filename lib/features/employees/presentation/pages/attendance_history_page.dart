import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

const int _pageSize = 25;

/// How far back the range picker opens on first load.
const int _defaultRangeDays = 30;

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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

class _AttendanceHistoryPageState extends ConsumerState<AttendanceHistoryPage> {
  Employee? _selectedEmployee;
  late final DateTime _defaultTo;
  late final DateTime _defaultFrom;
  late DateTime _from;
  late DateTime _to;
  AttendanceStatus? _status;
  int _page = 0;

  String? get _employeeId => _selectedEmployee?.id;

  @override
  void initState() {
    super.initState();
    _defaultTo = _dayOnly(DateTime.now());
    _defaultFrom = _defaultTo.subtract(const Duration(days: _defaultRangeDays));
    _from = _defaultFrom;
    _to = _defaultTo;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = asyncAll2(
      ref.watch(employeesProvider(widget.storeId)),
      ref.watch(storeSettingsProvider(widget.storeId)),
      (employees, settings) => (employees: employees, settings: settings),
    );

    return ShellPage(
      title: l10n.attendanceHistoryTitle,
      subtitle: l10n.attendanceHistorySubtitle,
      child: AsyncContent<
        ({List<Employee> employees, StoreSettings settings})
      >(
        value: base,
        onRetry: () {
          ref.invalidate(employeesProvider(widget.storeId));
          ref.invalidate(storeSettingsProvider(widget.storeId));
        },
        builder: (context, b) {
          final employees = [...b.employees]
            ..sort(
              (x, y) =>
                  employeeDisplayName(x).compareTo(employeeDisplayName(y)),
            );
          return _buildBody(l10n, employees, b.settings);
        },
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    List<Employee> employees,
    StoreSettings settings,
  ) {
    final employeesById = {for (final e in employees) e.id: e};
    final key = (
      storeId: widget.storeId,
      from: _from,
      to: _to,
      status: _status,
      employeeId: _employeeId,
      page: _page,
    );
    final statsAsync = ref.watch(attendanceStatsProvider(key));
    final pageAsync = ref.watch(attendancePageProvider(key));

    return AsyncContent<AttendancePage>(
      value: pageAsync,
      skeleton: const SkeletonList(rows: 6, rowHeight: 64),
      onRetry: () => ref.invalidate(attendancePageProvider(key)),
      builder: (context, result) {
        if (result.page != _page) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _page != result.page) {
              setState(() => _page = result.page);
            }
          });
        }
        final stats =
            statsAsync.value ??
            (
              days: 0,
              worked: Duration.zero,
              lateArrivals: 0,
              overtime: Duration.zero,
              lateBreaks: 0,
            );
        final storeEmpty = !_hasActiveFilters && result.totalCount == 0;

        return _content(
          l10n,
          employees,
          employeesById,
          settings,
          stats,
          result,
          storeEmpty,
        );
      },
    );
  }

  Widget _content(
    AppLocalizations l10n,
    List<Employee> employees,
    Map<String, Employee> employeesById,
    StoreSettings settings,
    AttendanceStats stats,
    AttendancePage result,
    bool storeEmpty,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Filters(
          selectedEmployee: _selectedEmployee,
          employees: employees,
          from: _from,
          to: _to,
          status: _status,
          canReset: _hasActiveFilters,
          onReset: _clearFilters,
          onEmployee: (e) => setState(() {
            _selectedEmployee = e;
            _page = 0;
          }),
          onFrom: (d) => setState(() {
            _from = _dayOnly(d);
            if (_to.isBefore(_from)) _to = _from;
            _page = 0;
          }),
          onTo: (d) => setState(() {
            _to = _dayOnly(d);
            if (_from.isAfter(_to)) _from = _to;
            _page = 0;
          }),
          onStatus: (s) => setState(() {
            _status = s;
            _page = 0;
          }),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(height: AppSpacing.sm),
          _ActiveFilters(
            l10n: l10n,
            dateRange: _dateRangeIsDefault
                ? null
                : l10n.attendanceFilterDateRange(
                    Formatters.date(_from),
                    Formatters.date(_to),
                  ),
            status: _status,
            employeeName: _employeeId == null
                ? null
                : employeeDisplayName(employeesById[_employeeId!]!),
            onClear: _clearFilters,
            onRemoveDateRange: () => setState(() {
              _from = _defaultFrom;
              _to = _defaultTo;
            }),
            onRemoveStatus: () => setState(() => _status = null),
            onRemoveEmployee: () => setState(() => _selectedEmployee = null),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _StatRow(stats: stats),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.attendanceHistoryCount(result.totalCount),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (result.rows.isEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 360),
            child: _emptyState(l10n, storeEmpty),
          )
        else ...[
          _HistoryTable(
            rows: result.rows,
            employeesById: employeesById,
            settings: settings,
            onOpen: (a) => _openDrawer(
              l10n,
              a,
              employeesById[a.employeeId],
              settings,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Paginator(
            page: result.page,
            pageCount: result.pageCount,
            totalCount: result.totalCount,
            pageSize: _pageSize,
            onChanged: (p) => setState(() => _page = p),
          ),
        ],
      ],
    );
  }

  Future<void> _openDrawer(
    AppLocalizations l10n,
    Attendance a,
    Employee? employee,
    StoreSettings settings,
  ) {
    final schedule = employee == null
        ? (startMinutes: settings.openMinutes, endMinutes: settings.closeMinutes)
        : resolvedSchedule(
            employee,
            storeOpenMinutes: settings.openMinutes,
            storeCloseMinutes: settings.closeMinutes,
          );
    final ctx = evaluationContext(
      a,
      fallbackStartMinutes: schedule.startMinutes,
      fallbackEndMinutes: schedule.endMinutes,
      fallbackMaxBreakMinutes: settings.maxBreakMinutes,
    );
    final worked = workedDuration(a);
    final overtime = overtimeBy(a, ctx.endMinutes) ?? Duration.zero;

    return DetailDrawer.show(
      context,
      title: l10n.attendanceDetailTitle,
      children: [
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
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      l10n.employeeCinLabel(employee.cin),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        DrawerRow(
          label: l10n.attendanceColumnDate,
          value: Formatters.date(a.date),
        ),
        DrawerRow(
          label: l10n.attendanceColumnStatus,
          valueWidget: Align(
            alignment: Alignment.centerLeft,
            child: AttendanceStatusBadge(status: a.status),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: l10n.attendanceColumnSchedule),
        DrawerRow(
          label: l10n.attendanceColumnArrival,
          value: a.clockInAt == null ? '—' : Formatters.time(a.clockInAt!),
        ),
        DrawerRow(
          label: l10n.attendanceColumnDeparture,
          value: a.clockOutAt == null ? '—' : Formatters.time(a.clockOutAt!),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(
          title: l10n.attendanceDetailBreaks(a.pauses.length),
        ),
        for (final pause in a.pauses)
          _BreakLine(
            pause: pause,
            over:
                breakOverrun(pause, ctx.maxBreakMinutes) > Duration.zero,
          ),
        DrawerRow(
          label: l10n.attendanceDetailBreakTotal,
          value: Formatters.duration(totalBreak(a)),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: l10n.attendanceDetailWorkTime),
        DrawerRow(
          label: l10n.attendanceColumnWorked,
          value: worked == null ? '—' : Formatters.duration(worked),
        ),
        DrawerRow(
          label: l10n.attendanceColumnOvertime,
          value: overtime == Duration.zero
              ? '—'
              : l10n.attendanceDetailOvertimeInfo(
                  Formatters.duration(overtime),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: l10n.attendanceColumnFlags),
        AttendanceAlerts(
          entry: a,
          startMinutes: ctx.startMinutes,
          maxBreakMinutes: ctx.maxBreakMinutes,
          detailed: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: l10n.attendanceDetailTimeline),
        AttendanceTimeline(entry: a, maxBreakMinutes: ctx.maxBreakMinutes),
      ],
    );
  }

  bool get _dateRangeIsDefault => _from == _defaultFrom && _to == _defaultTo;

  bool get _hasActiveFilters =>
      !_dateRangeIsDefault || _status != null || _employeeId != null;

  void _clearFilters() => setState(() {
    _from = _defaultFrom;
    _to = _defaultTo;
    _status = null;
    _selectedEmployee = null;
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
    required this.selectedEmployee,
    required this.employees,
    required this.from,
    required this.to,
    required this.status,
    required this.canReset,
    required this.onReset,
    required this.onEmployee,
    required this.onFrom,
    required this.onTo,
    required this.onStatus,
  });

  final Employee? selectedEmployee;
  final List<Employee> employees;
  final DateTime from;
  final DateTime to;
  final AttendanceStatus? status;
  final bool canReset;
  final VoidCallback onReset;
  final ValueChanged<Employee?> onEmployee;
  final ValueChanged<DateTime> onFrom;
  final ValueChanged<DateTime> onTo;
  final ValueChanged<AttendanceStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = _dayOnly(DateTime.now());
    final floor = DateTime(2000);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        LabeledField(
          label: l10n.attendanceFilterEmployee,
          child: SizedBox(
            width: 260,
            child: EmployeeSelector(
              employees: employees,
              value: selectedEmployee,
              showCin: true,
              hint: l10n.attendanceFilterAllEmployees,
              onChanged: onEmployee,
            ),
          ),
        ),
        LabeledField(
          label: l10n.attendanceFilterFrom,
          child: SizedBox(
            width: 165,
            child: DateField(
              value: from,
              compact: true,
              firstDate: floor,
              lastDate: to,
              onChanged: onFrom,
            ),
          ),
        ),
        LabeledField(
          label: l10n.attendanceFilterTo,
          child: SizedBox(
            width: 165,
            child: DateField(
              value: to,
              compact: true,
              firstDate: from,
              lastDate: today,
              onChanged: onTo,
            ),
          ),
        ),
        LabeledField(
          label: l10n.ordersFilterStatus,
          child: FilterMenu<AttendanceStatus?>(
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
        ),
        if (canReset)
          FilterResetButton(
            label: l10n.attendanceFilterReset,
            onPressed: onReset,
          ),
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.l10n,
    required this.dateRange,
    required this.status,
    required this.employeeName,
    required this.onClear,
    required this.onRemoveDateRange,
    required this.onRemoveStatus,
    required this.onRemoveEmployee,
  });

  final AppLocalizations l10n;
  final String? dateRange;
  final AttendanceStatus? status;
  final String? employeeName;
  final VoidCallback onClear;
  final VoidCallback onRemoveDateRange;
  final VoidCallback onRemoveStatus;
  final VoidCallback onRemoveEmployee;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (employeeName != null)
          RemovableFilterChip(
            label: employeeName!,
            onRemove: onRemoveEmployee,
          ),
        if (dateRange != null)
          RemovableFilterChip(
            label: dateRange!,
            onRemove: onRemoveDateRange,
          ),
        if (status != null)
          RemovableFilterChip(
            label: attendanceStatusLabel(l10n, status!),
            onRemove: onRemoveStatus,
          ),
        TextButton(onPressed: onClear, child: Text(l10n.inventoryClearFilters)),
      ],
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.rows,
    required this.employeesById,
    required this.settings,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final StoreSettings settings;
  final ValueChanged<Attendance> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 940,
      columns: [
        DataColumn(label: Text(l10n.attendanceColumnDate)),
        DataColumn(label: Text(l10n.attendanceColumnEmployee)),
        DataColumn(label: Text(l10n.attendanceColumnSchedule)),
        DataColumn(label: Text(l10n.attendanceColumnWorked)),
        DataColumn(label: Text(l10n.attendanceColumnStatus)),
        DataColumn(label: Text(l10n.attendanceColumnFlags)),
        DataColumn(label: Text(l10n.attendanceColumnActions)),
      ],
      rows: [for (final a in rows) _row(context, l10n, a)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Attendance a) {
    final theme = Theme.of(context);
    final employee = employeesById[a.employeeId];
    final schedule = employee == null
        ? (startMinutes: settings.openMinutes, endMinutes: settings.closeMinutes)
        : resolvedSchedule(
            employee,
            storeOpenMinutes: settings.openMinutes,
            storeCloseMinutes: settings.closeMinutes,
          );
    final ctx = evaluationContext(
      a,
      fallbackStartMinutes: schedule.startMinutes,
      fallbackEndMinutes: schedule.endMinutes,
      fallbackMaxBreakMinutes: settings.maxBreakMinutes,
    );
    final worked = workedDuration(a);
    final arrival = a.clockInAt == null ? '—' : Formatters.time(a.clockInAt!);
    final departure = a.clockOutAt == null
        ? '…'
        : Formatters.time(a.clockOutAt!);
    final totalPause = totalBreak(a);

    return DataRow(
      onSelectChanged: (_) => onOpen(a),
      cells: [
        DataCell(Text(Formatters.date(a.date))),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(employee == null ? '—' : employeeDisplayName(employee)),
              if (employee != null)
                Text(
                  l10n.employeeCinLabel(employee.cin),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$arrival → $departure'),
              if (a.pauses.isNotEmpty)
                Text(
                  l10n.attendanceBreakSummary(
                    a.pauses.length,
                    Formatters.duration(totalPause),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        DataCell(Text(worked == null ? '—' : Formatters.duration(worked))),
        DataCell(AttendanceStatusBadge(status: a.status)),
        DataCell(
          AttendanceAlerts(
            entry: a,
            startMinutes: ctx.startMinutes,
            maxBreakMinutes: ctx.maxBreakMinutes,
          ),
        ),
        DataCell(
          IconButton(
            tooltip: l10n.attendanceViewDetail,
            icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
            onPressed: () => onOpen(a),
          ),
        ),
      ],
    );
  }
}

/// One break line in the detail drawer — start – end (duration), amber when it
/// ran past the allowance.
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: over ? AppColors.lowStock.foreground : null,
            ),
          ),
        ],
      ),
    );
  }
}
