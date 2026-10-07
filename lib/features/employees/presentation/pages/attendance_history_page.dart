import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/correct_exit_dialog.dart';

/// Below this width the table would have to scroll horizontally to show its
/// six columns — a card per day reads better on a touch screen than a
/// sideways-scrolling table, so the history switches to cards instead.
const double _tableMinWidth = 740;

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
    // Today's sessions by default, on every screen; the range is the
    // manager's to widen from there.
    _defaultTo = dayOf(clock.now());
    _defaultFrom = _defaultTo;
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
    // While it loads (or with none open), every open past day reads as an
    // oubli — the same as before the journée de service existed.
    final openBusinessDay = ref
        .watch(openBusinessDayProvider(widget.storeId))
        .value
        ?.date;

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
          openBusinessDay,
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
    DateTime? openBusinessDay,
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
            _from = dayOf(d);
            if (_to.isBefore(_from)) _to = _from;
            _page = 0;
          }),
          onTo: (d) => setState(() {
            _to = dayOf(d);
            if (_from.isAfter(_to)) _from = _to;
            _page = 0;
          }),
          onStatus: (s) => setState(() {
            _status = s;
            _page = 0;
          }),
          onClear: () => setState(() {
            _from = _defaultFrom;
            _to = _defaultTo;
            _status = null;
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
                employeesById,
                settings,
                openBusinessDay,
              );
              return constraints.maxWidth >= _tableMinWidth
                  ? _HistoryTable(
                      rows: result.rows,
                      employeesById: employeesById,
                      settings: settings,
                      openBusinessDay: openBusinessDay,
                      onOpen: onOpen,
                    )
                  : _HistoryCards(
                      rows: result.rows,
                      employeesById: employeesById,
                      settings: settings,
                      openBusinessDay: openBusinessDay,
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
  ///
  /// A day left open (oubli de pointage) that the board can no longer end —
  /// it is not the journée still open — gets « Corriger la sortie ». A day
  /// with a double pointage, not paid yet, offers to remove one of its
  /// arrivals (« Supprimer ce pointage en double », rule P1).
  Future<void> _openDrawer(
    Attendance a,
    Map<String, Employee> employeesById,
    StoreSettings settings,
    DateTime? openBusinessDay,
  ) async {
    final l10n = AppLocalizations.of(context);
    final employee = employeesById[a.employeeId];
    final maxBreakMinutes = resolvedMaxBreakMinutes(
      a,
      fallback: settings.maxBreakMinutes,
    );
    final now = ref.read(attendanceClockProvider)();
    // The rule already leaves out the journée still open: an oubli is a day
    // the board can no longer end.
    final anomalies = attendanceAnomalies(
      a,
      maxBreakMinutes: maxBreakMinutes,
      now: now,
      openBusinessDay: openBusinessDay,
    );
    final correctable = anomalies.contains(AttendanceAnomaly.oubliDePointage);
    final duplicates =
        anomalies.contains(AttendanceAnomaly.doublePointage) &&
        a.paymentStatus != PaymentStatus.paid &&
        a.sessions.length > 1;

    return DetailDrawer.show(
      context,
      children: [
        AttendanceDayDetail(
          entry: a,
          employee: employee,
          maxBreakMinutes: maxBreakMinutes,
          exitAuthors: {
            for (final e in employeesById.values) e.id: employeeDisplayName(e),
          },
          openBusinessDay: openBusinessDay,
        ),
        if (correctable) ...[
          const SizedBox(height: AppSpacing.xxl),
          Builder(
            builder: (drawerContext) => FilledButton.icon(
              key: const ValueKey('attendance-correct-exit'),
              onPressed: () => _correctExit(drawerContext, a, employee),
              icon: const Icon(LucideIcons.clockAlert, size: AppSizing.iconSm),
              label: Text(l10n.attendanceCorrectExit),
            ),
          ),
        ],
        if (duplicates) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l10n.attendanceDuplicateHeading,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.attendanceDuplicateHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final (index, session) in a.sessions.indexed) ...[
            const SizedBox(height: AppSpacing.sm),
            Builder(
              builder: (drawerContext) => OutlinedButton.icon(
                key: ValueKey('attendance-delete-duplicate-$index'),
                onPressed: session.id == null
                    ? null
                    : () => _deleteDuplicate(drawerContext, a, session),
                icon: const Icon(LucideIcons.trash2, size: AppSizing.iconSm),
                label: Text(
                  l10n.attendanceDeleteDuplicate(
                    _sessionLabel(session),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  static String _sessionLabel(AttendanceSession session) {
    final out = session.clockOutAt;
    return out == null
        ? Formatters.time(session.clockInAt)
        : '${Formatters.time(session.clockInAt)} – ${Formatters.time(out)}';
  }

  /// Confirm, the signed-in user's PIN, then the removal. Closes the drawer
  /// on success.
  Future<void> _deleteDuplicate(
    BuildContext drawerContext,
    Attendance a,
    AttendanceSession session,
  ) async {
    final l10n = AppLocalizations.of(drawerContext);
    final actor = ref.read(currentEmployeeProvider);
    if (actor == null) return;
    final label = _sessionLabel(session);

    final confirmed = await ConfirmDialog.show(
      drawerContext,
      title: l10n.attendanceDeleteDuplicateTitle,
      message: l10n.attendanceDeleteDuplicateMessage(label),
      confirmLabel: l10n.attendanceDeleteDuplicateConfirm,
    );
    if (!confirmed || !drawerContext.mounted) return;

    final ok = await IdentityPromptDialog.show(
      drawerContext,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptDeleteDuplicateSubtitle,
      verify: (pin) =>
          ref.read(credentialRepositoryProvider).verifyPin(pin, actor.id),
    );
    if (!ok || !drawerContext.mounted) return;

    final done = await ref
        .read(attendanceRepositoryProvider)
        .deleteDuplicateSession(a.id, session.id!);
    if (!drawerContext.mounted) return;
    if (done == null) {
      AppSnackBar.error(drawerContext, l10n.attendanceDeleteDuplicateFailed);
      return;
    }
    Navigator.of(drawerContext).pop();
    if (!mounted) return;
    AppSnackBar.success(context, l10n.attendanceDeleteDuplicateDone(label));
  }

  /// The exit time, then the signed-in user's PIN, then the correction —
  /// signed with their id. Closes the drawer on success: the row it showed
  /// is now finished.
  Future<void> _correctExit(
    BuildContext drawerContext,
    Attendance a,
    Employee? employee,
  ) async {
    final l10n = AppLocalizations.of(drawerContext);
    final actor = ref.read(currentEmployeeProvider);
    if (actor == null) return;
    final date = Formatters.dateLongWeekday(a.date);
    final dateLower = date.isEmpty
        ? date
        : date[0].toLowerCase() + date.substring(1);

    final exit = await CorrectExitDialog.show(
      drawerContext,
      entry: a,
      employee: employee,
      now: ref.read(attendanceClockProvider)(),
    );
    if (exit == null || !drawerContext.mounted) return;

    final ok = await IdentityPromptDialog.show(
      drawerContext,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptCorrectExitSubtitle(dateLower),
      verify: (pin) =>
          ref.read(credentialRepositoryProvider).verifyPin(pin, actor.id),
    );
    if (!ok || !drawerContext.mounted) return;

    final fixed = await ref
        .read(attendanceRepositoryProvider)
        .correctExit(a.id, exit, correctedByEmployeeId: actor.id);
    if (!drawerContext.mounted) return;
    if (fixed == null) {
      AppSnackBar.error(drawerContext, l10n.attendanceCorrectExitFailed);
      return;
    }
    Navigator.of(drawerContext).pop();
    if (!mounted) return;
    AppSnackBar.success(context, l10n.attendanceCorrectExitDone(dateLower));
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
    required this.onClear,
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

  /// Resets the period and the status — not the employee, which is the
  /// search, not one of the filters.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rangeChanged = from != defaultFrom || to != defaultTo;

    return FilterToolbar(
      activeCount: (rangeChanged ? 1 : 0) + (status == null ? 0 : 1),
      onClear: onClear,
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
          lastDate: dayOf(clock.now()),
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
    required this.openBusinessDay,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final StoreSettings settings;
  final DateTime? openBusinessDay;
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
    final data = _attendanceRowData(
      a,
      employeesById,
      settings,
      openBusinessDay,
    );
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
          AttendanceAlerts(
            entry: a,
            maxBreakMinutes: data.maxBreakMinutes,
            openBusinessDay: data.openBusinessDay,
          ),
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
  int pauseCount,
  int maxBreakMinutes,
  DateTime? openBusinessDay,
});

_AttendanceRowData _attendanceRowData(
  Attendance a,
  Map<String, Employee> employeesById,
  StoreSettings settings,
  DateTime? openBusinessDay,
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
    pauseCount: totalPauseCount(a),
    maxBreakMinutes: maxBreak,
    openBusinessDay: openBusinessDay,
  );
}

/// The history as a grid of day cards — the table's small-screen alternative.
/// Below [_tableMinWidth] a `DataTable` would have to scroll sideways to show
/// its six columns, which is not a touch-friendly way to read a day's
/// pointage.
///
/// One card per line on a phone, two or more on a tablet — the same
/// [ResponsiveCardGrid] as the payroll history cards, so the two screens switch
/// column counts at the same width.
class _HistoryCards extends StatelessWidget {
  const _HistoryCards({
    required this.rows,
    required this.employeesById,
    required this.settings,
    required this.openBusinessDay,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final StoreSettings settings;
  final DateTime? openBusinessDay;
  final ValueChanged<Attendance> onOpen;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCardGrid(
      children: [
        for (final a in rows)
          _AttendanceCard(
            attendance: a,
            data: _attendanceRowData(
              a,
              employeesById,
              settings,
              openBusinessDay,
            ),
            onTap: () => onOpen(a),
          ),
      ],
    );
  }
}

/// One day, as a card: the date and the status on top ([CardDateHeader]), who
/// it is, the time worked and the pauses side by side, and — only when there
/// is one — an alert chip at the bottom. The whole card opens the detail.
///
/// No arrival → départ span: a day can hold several sessions, which one span
/// misreads; the drawer's timeline shows them all.
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
    final employee = data.employee;
    final anomalies = attendanceAnomalies(
      attendance,
      maxBreakMinutes: data.maxBreakMinutes,
      openBusinessDay: data.openBusinessDay,
    );

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardDateHeader(
            date: attendance.date,
            status: AttendanceStatusBadge(status: attendance.status),
          ),
          const SizedBox(height: AppSpacing.md),
          EmployeeCardIdentity(employee: employee),
          const SizedBox(height: AppSpacing.md),
          // IntrinsicHeight so the two tiles match when one label wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CardFigure(
                    label: l10n.attendanceStatWorked,
                    value: data.worked == null
                        ? '—'
                        : Formatters.duration(data.worked!),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CardFigure(
                    key: const ValueKey('attendance-card-pauses'),
                    label: l10n.attendanceCardBreakLabel,
                    count: data.pauseCount,
                    value: Formatters.duration(data.totalPause),
                  ),
                ),
              ],
            ),
          ),
          // Alerts get their own line, the full card width, so the alerts'
          // own `Wrap` arranges chips across as many lines as it needs.
          if (anomalies.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AttendanceAlerts(
              entry: attendance,
              maxBreakMinutes: data.maxBreakMinutes,
              openBusinessDay: data.openBusinessDay,
            ),
          ],
        ],
      ),
    );
  }
}

/// One figure on an [_AttendanceCard] — a small grey label over the value, on
/// a grey tile. [count], when given, sits in a badge beside the label: how
/// many pauses the value adds up.
class _CardFigure extends StatelessWidget {
  const _CardFigure({
    required this.label,
    required this.value,
    this.count,
    super.key,
  });

  final String label;
  final String value;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  key: const ValueKey('card-figure-count'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs + 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    '$count',
                    style: labelStyle?.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

