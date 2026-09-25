import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// How far back the range picker opens on first load.
const int _defaultRangeDays = 30;

/// Below this width the table would have to scroll horizontally to show its
/// six columns — a card per day reads better on a touch screen than a
/// sideways-scrolling table, so the history switches to cards instead.
const double _tableMinWidth = 740;

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// The filterable attendance log across every employee and day — reached from
/// the Gestion Employée dropdown, so a `goSection` destination with no back
/// control.
class AttendanceHistoryPage extends ConsumerStatefulWidget {
  const AttendanceHistoryPage({
    required this.storeId,
    this.initialEmployeeId,
    super.key,
  });

  final String storeId;

  /// Opens filtered to this employee — "Historique" from the staff roster.
  /// Ignored when the id is not on the list.
  final String? initialEmployeeId;

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
  int _pageSize = Paginator.defaultPageSizes.first;

  String? get _employeeId => _selectedEmployee?.id;

  /// [widget.initialEmployeeId], until the roster it resolves against has
  /// loaded once.
  late String? _pendingEmployeeId = widget.initialEmployeeId;

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
          final pending = _pendingEmployeeId;
          if (pending != null) {
            // Once, during this build — before anything reads the filter.
            _pendingEmployeeId = null;
            _selectedEmployee = employees
                .where((e) => e.id == pending)
                .firstOrNull;
          }
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
      pageSize: _pageSize,
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
            (days: 0, worked: Duration.zero, lateBreaks: 0);
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
          defaultFrom: _defaultFrom,
          defaultTo: _defaultTo,
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
          LayoutBuilder(
            builder: (context, constraints) {
              void onOpen(Attendance a) => _openDrawer(
                a,
                employeesById[a.employeeId],
                settings,
              );
              return constraints.maxWidth >= _tableMinWidth
                  ? _HistoryTable(
                      rows: result.rows,
                      employeesById: employeesById,
                      settings: settings,
                      onOpen: onOpen,
                    )
                  : _HistoryCards(
                      rows: result.rows,
                      employeesById: employeesById,
                      settings: settings,
                      onOpen: onOpen,
                    );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Paginator(
            page: result.page,
            pageCount: result.pageCount,
            totalCount: result.totalCount,
            pageSize: _pageSize,
            onChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (size) => setState(() {
              _pageSize = size;
              _page = 0;
            }),
          ),
        ],
      ],
    );
  }

  /// Bare panel: the day itself is the heading — see [AttendanceDayDetail].
  Future<void> _openDrawer(
    Attendance a,
    Employee? employee,
    StoreSettings settings,
  ) {
    return DetailDrawer.show(
      context,
      children: [
        AttendanceDayDetail(
          entry: a,
          employee: employee,
          maxBreakMinutes: resolvedMaxBreakMinutes(
            a,
            fallback: settings.maxBreakMinutes,
          ),
        ),
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

  final ({int days, Duration worked, int lateBreaks}) stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StatTileRow(
      tiles: [
        StatTile(
          label: l10n.attendanceStatDays,
          value: '${stats.days}',
          icon: LucideIcons.clipboardList,
        ),
        StatTile(
          label: l10n.attendanceStatWorked,
          value: Formatters.duration(stats.worked),
          icon: LucideIcons.clock,
        ),
        StatTile(
          label: l10n.attendanceStatLateBreaks,
          value: '${stats.lateBreaks}',
          icon: LucideIcons.coffee,
          accent: stats.lateBreaks == 0 ? null : AppColors.lowStock,
        ),
      ],
    );
  }
}

/// Search on the left, début, fin and statut at the right edge — the same strip
/// as the Personnel page and the payroll history.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.selectedEmployee,
    required this.employees,
    required this.from,
    required this.to,
    required this.status,
    required this.defaultFrom,
    required this.defaultTo,
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
  final DateTime defaultFrom;
  final DateTime defaultTo;
  final ValueChanged<Employee?> onEmployee;
  final ValueChanged<DateTime> onFrom;
  final ValueChanged<DateTime> onTo;
  final ValueChanged<AttendanceStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FilterToolbar(
      search: EmployeeSelector(
        employees: employees,
        value: selectedEmployee,
        showPin: true,
        searchBar: true,
        hint: l10n.employeesSearchHint,
        onChanged: onEmployee,
      ),
      filters: [
        DateFilter(
          key: const ValueKey('date-filter-from'),
          label: l10n.historyFilterFrom,
          value: from,
          firstDate: DateTime(2000),
          lastDate: to,
          isDefault: from == defaultFrom,
          onChanged: onFrom,
        ),
        DateFilter(
          key: const ValueKey('date-filter-to'),
          label: l10n.historyFilterTo,
          value: to,
          firstDate: from,
          lastDate: _dayOnly(DateTime.now()),
          isDefault: to == defaultTo,
          onChanged: onTo,
        ),
        FilterMenu<AttendanceStatus?>(
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

/// One line per day: Date / Employé / Travaillé / Statut / Alertes. Clicking
/// the row opens the detail drawer — there is no separate Détail column.
/// The arrival → départ times and the pauses are deliberately not here — a day
/// can hold several sessions, which no single cell reads well; the drawer's
/// timeline shows them all.
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
      minWidth: _tableMinWidth,
      columns: [
        DataColumn(label: Text(l10n.attendanceColumnDate)),
        DataColumn(label: Text(l10n.attendanceColumnEmployee)),
        DataColumn(label: Text(l10n.attendanceColumnWorked)),
        DataColumn(label: Text(l10n.attendanceColumnStatus)),
        DataColumn(label: Text(l10n.attendanceColumnFlags)),
      ],
      rows: [for (final a in rows) _row(context, l10n, a)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Attendance a) {
    final data = _attendanceRowData(a, employeesById, settings);
    final employee = data.employee;

    return DataRow(
      onSelectChanged: (_) => onOpen(a),
      cells: [
        DataCell(WeekdayDate(a.date)),
        DataCell(EmployeeCell(employee: employee)),
        DataCell(
          Text(data.worked == null ? '—' : Formatters.duration(data.worked!)),
        ),
        DataCell(AttendanceStatusBadge(status: a.status)),
        DataCell(
          AttendanceAlerts(entry: a, maxBreakMinutes: data.maxBreakMinutes),
        ),
      ],
    );
  }
}

/// The fields a table row and a card both need, computed once so the two
/// renderings of the same day can never drift apart.
typedef _AttendanceRowData = ({
  Employee? employee,
  Duration? worked,
  Duration totalPause,
  String arrival,
  String departure,
  int maxBreakMinutes,
});

_AttendanceRowData _attendanceRowData(
  Attendance a,
  Map<String, Employee> employeesById,
  StoreSettings settings,
) {
  final employee = employeesById[a.employeeId];
  final maxBreak = resolvedMaxBreakMinutes(
    a,
    fallback: settings.maxBreakMinutes,
  );
  return (
    employee: employee,
    worked: workedDuration(a),
    totalPause: totalBreak(a),
    arrival: a.sessions.firstOrNull?.clockInAt == null
        ? '—'
        : Formatters.time(a.sessions.first.clockInAt),
    departure: a.sessions.lastOrNull?.clockOutAt == null
        ? '…'
        : Formatters.time(a.sessions.last.clockOutAt!),
    maxBreakMinutes: maxBreak,
  );
}

/// The history as a grid of day cards — the table's small-screen alternative.
/// Below [_tableMinWidth] a `DataTable` would have to scroll sideways to show
/// its six columns, which is not a touch-friendly way to read a day's
/// pointage.
///
/// Fits as many columns as the available width allows — up to 3 on a wide
/// tablet, dropping to 2 then 1 as the screen narrows — rather than always
/// stacking a single column, which wastes tablet-width real estate. Uses the
/// same [cardGridColumns] sizing as the payroll history cards, so the two
/// screens switch column counts at the same width.
class _HistoryCards extends StatelessWidget {
  const _HistoryCards({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = cardGridColumns(constraints.maxWidth);
        const spacing = AppSpacing.lg;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final a in rows)
              SizedBox(
                width: cardWidth,
                child: _AttendanceCard(
                  attendance: a,
                  data: _attendanceRowData(a, employeesById, settings),
                  onTap: () => onOpen(a),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One day, as a card: the date and the detail action on top, who it is,
/// the arrival → départ span as the main figure, pause and overtime grouped
/// underneath it, and the status with — only when there is one — an alert
/// chip at the bottom.
class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.attendance,
    required this.data,
    required this.onTap,
  });

  final Attendance attendance;
  final _AttendanceRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = data.employee;
    final anomalies = attendanceAnomalies(
      attendance,
      maxBreakMinutes: data.maxBreakMinutes,
    );

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.dateLong(attendance.date),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.attendanceViewDetail,
                icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
                onPressed: onTap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (employee != null)
                EmployeeAvatar(employee: employee, size: 40)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    size: AppSizing.iconSm,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employee == null ? '—' : employeeDisplayName(employee),
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (employee != null)
                      Text(
                        employee.pin,
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
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.attendanceColumnSchedule,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${data.arrival} → ${data.departure}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.attendanceCardBreakLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  Formatters.duration(data.totalPause),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AttendanceStatusBadge(status: attendance.status),
          // Alerts get their own line rather than sharing the status badge's —
          // squeezed next to it, an anomaly chip has to fight the badge for
          // width and ends up ellipsized. Full card width lets the alerts'
          // own `Wrap` arrange chips across as many lines as it needs instead.
          if (anomalies.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AttendanceAlerts(
              entry: attendance,
              maxBreakMinutes: data.maxBreakMinutes,
            ),
          ],
        ],
      ),
    );
  }
}

