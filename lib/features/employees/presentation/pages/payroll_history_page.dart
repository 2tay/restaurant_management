import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/payroll_math.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// How far back the range picker opens on first load.
const int _defaultRangeDays = 90;

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// The payroll history, day by day: every active employee's finished days over
/// a chosen date range (or one employee's, once picked in the filter), paid or
/// still owed, plus a "Payer" action that settles the unpaid days **of the
/// shown range** for the selected employee.
///
/// Shares its visual language with the Historique de pointage — the same
/// compact filter bar, KPI row, [DataTableWrapper] and right-side
/// [DetailDrawer] — so moving between the two pages does not feel like changing
/// apps.
///
/// A range start can never go before an employee's hire date — the picker is
/// bounded there and `PayrollRepository.days` enforces it again per employee.
class PayrollHistoryPage extends ConsumerStatefulWidget {
  const PayrollHistoryPage({
    required this.storeId,
    this.initialEmployeeId,
    super.key,
  });

  final String storeId;

  /// Opens filtered to this employee — "Historique" from the staff roster.
  /// Ignored when the id is not on the list.
  final String? initialEmployeeId;

  @override
  ConsumerState<PayrollHistoryPage> createState() => _PayrollHistoryPageState();
}

class _PayrollHistoryPageState extends ConsumerState<PayrollHistoryPage> {
  Employee? _selectedEmployee;
  late final DateTime _defaultTo;
  late final DateTime _defaultFrom;
  late DateTime _from;
  late DateTime _to;
  PaymentStatus? _statusFilter;
  int _page = 0;
  int _pageSize = Paginator.defaultPageSizes.first;

  /// The roster, cached from the last build so the synchronous filter handlers
  /// can resolve a floor without a query.
  List<Employee> _employees = const [];

  String? get _employeeId => _selectedEmployee?.id;

  /// [widget.initialEmployeeId], until the roster it resolves against has
  /// loaded once.
  late String? _pendingEmployeeId = widget.initialEmployeeId;

  @override
  void initState() {
    super.initState();
    _defaultTo = _dayOnly(clock.now());
    _defaultFrom = _defaultTo.subtract(const Duration(days: _defaultRangeDays));
    _from = _defaultFrom;
    _to = _defaultTo;
  }

  bool get _dateRangeIsDefault => _from == _defaultFrom && _to == _defaultTo;

  bool get _hasActiveFilters =>
      !_dateRangeIsDefault || _statusFilter != null || _employeeId != null;

  void _onEmployeeChanged(Employee? employee) {
    setState(() {
      _selectedEmployee = employee;
      _statusFilter = null;
      _page = 0;
      if (employee == null) return;
      final hire = _dayOnly(employee.hireDate);
      if (_from.isBefore(hire)) _from = hire;
      if (_to.isBefore(_from)) _to = _dayOnly(clock.now());
    });
  }

  void _clearFilters() => setState(() {
    _from = _defaultFrom;
    _to = _defaultTo;
    _statusFilter = null;
    _selectedEmployee = null;
    _page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = asyncAll2(
      ref.watch(payableEmployeesProvider(widget.storeId)),
      ref.watch(storeSettingsProvider(widget.storeId)),
      (employees, settings) => (employees: employees, settings: settings),
    );

    return ShellPage(
      title: l10n.payrollHistoryTitle,
      subtitle: l10n.payrollHistorySubtitle,
      scrollable: true,
      child: AsyncContent<
        ({List<Employee> employees, StoreSettings settings})
      >(
        value: data,
        onRetry: () {
          ref.invalidate(payableEmployeesProvider(widget.storeId));
          ref.invalidate(storeSettingsProvider(widget.storeId));
        },
        builder: (context, base) {
          _employees = [...base.employees]
            ..sort(
              (a, b) =>
                  employeeDisplayName(a).compareTo(employeeDisplayName(b)),
            );
          final pending = _pendingEmployeeId;
          if (pending != null) {
            // Once, during this build — the same narrowing a pick in the
            // selector does (range floored at the hire date), minus setState.
            _pendingEmployeeId = null;
            final employee = _employees
                .where((e) => e.id == pending)
                .firstOrNull;
            if (employee != null) {
              _selectedEmployee = employee;
              final hire = _dayOnly(employee.hireDate);
              if (_from.isBefore(hire)) _from = hire;
              if (_to.isBefore(_from)) _to = _dayOnly(clock.now());
            }
          }
          return _buildBody(l10n, _employees, base.settings);
        },
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    List<Employee> employees,
    StoreSettings settings,
  ) {
    final key = (
      storeId: widget.storeId,
      employeeId: _employeeId,
      from: _from,
      to: _to,
      status: _statusFilter,
      page: _page,
      pageSize: _pageSize,
    );
    final daysAsync = ref.watch(payrollDaysProvider(key));

    return AsyncContent<PayrollDays>(
      value: daysAsync,
      skeleton: const SkeletonList(rows: 4, rowHeight: 120),
      onRetry: () => ref.invalidate(payrollDaysProvider(key)),
      builder: (context, data) => _content(l10n, employees, settings, data),
    );
  }

  Widget _content(
    AppLocalizations l10n,
    List<Employee> employees,
    StoreSettings settings,
    PayrollDays data,
  ) {
    if (data.page != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _page != data.page) setState(() => _page = data.page);
      });
    }

    final hasAnyDay = data.paidDays + data.unpaidDays > 0;
    final selectedEmployee = _selectedEmployee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Filters(
          selectedEmployee: _selectedEmployee,
          employees: employees,
          from: _from,
          to: _to,
          status: _statusFilter,
          floor: _pickerFloor(employees),
          defaultFrom: _defaultFrom,
          defaultTo: _defaultTo,
          onEmployee: _onEmployeeChanged,
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
            _statusFilter = s;
            _page = 0;
          }),
          onClear: () => setState(() {
            _from = _defaultFrom;
            _to = _defaultTo;
            _statusFilter = null;
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
            status: _statusFilter,
            employeeName: selectedEmployee == null
                ? null
                : employeeDisplayName(selectedEmployee),
            onClear: _clearFilters,
            onRemoveDateRange: () => setState(() {
              _from = _defaultFrom;
              _to = _defaultTo;
            }),
            onRemoveStatus: () => setState(() => _statusFilter = null),
            onRemoveEmployee: () => _onEmployeeChanged(null),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _kpiRow(l10n, data),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.payrollHistoryCount(data.totalCount),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (data.rows.isEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: hasAnyDay
                ? EmptyState(
                    icon: LucideIcons.wallet,
                    title: l10n.emptyStateNoResultsTitle,
                    message: l10n.emptyStateNoResultsBody,
                    actionLabel: l10n.inventoryClearFilters,
                    onAction: _clearFilters,
                  )
                : EmptyState(
                    icon: LucideIcons.wallet,
                    title: l10n.payrollHistoryEmpty,
                    message: l10n.payrollHistoryEmptyBody,
                  ),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final showEmployee = _employeeId == null;
              void onOpen(Attendance a) => _openDrawer(
                a,
                _payrollRowData(
                  a,
                  data.employeesById,
                  data.periodsById,
                  settings,
                ),
                settings,
              );
              return constraints.maxWidth >= _daysTableMinWidth(showEmployee)
                  ? _DaysTable(
                      rows: data.rows,
                      employeesById: data.employeesById,
                      periodsById: data.periodsById,
                      settings: settings,
                      showEmployee: showEmployee,
                      onOpen: onOpen,
                    )
                  : _DaysCards(
                      rows: data.rows,
                      employeesById: data.employeesById,
                      periodsById: data.periodsById,
                      settings: settings,
                      showEmployee: showEmployee,
                      onOpen: onOpen,
                    );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Paginator(
            page: data.page,
            pageCount: data.pageCount,
            totalCount: data.totalCount,
            pageSize: _pageSize,
            onChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (size) => setState(() {
              _pageSize = size;
              _page = 0;
            }),
          ),
        ],
        if (selectedEmployee != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              label: l10n.payrollPayAction,
              icon: LucideIcons.banknote,
              onPressed: data.unpaidDays == 0
                  ? null
                  : () => _confirmPay(selectedEmployee, from: _from, to: _to),
            ),
          ),
        ],
      ],
    );
  }

  Widget _kpiRow(AppLocalizations l10n, PayrollDays data) {
    return StatTileRow(
      tiles: [
        StatTile(
          label: l10n.payrollStatPaidDays,
          value: '${data.paidDays}',
          icon: LucideIcons.circleCheck,
        ),
        StatTile(
          label: l10n.payrollStatUnpaidDays,
          value: '${data.unpaidDays}',
          icon: LucideIcons.hourglass,
        ),
        StatTile(
          label: l10n.payrollStatWorkedHours,
          value: Formatters.duration(data.worked),
          icon: LucideIcons.clock,
        ),
      ],
    );
  }

  /// The earliest day the "Du" picker may reach: the selected employee's hire
  /// date, or the earliest hire among active employees when showing everyone —
  /// never later than the current [_from].
  DateTime _pickerFloor(List<Employee> employees) {
    if (_selectedEmployee != null) {
      return _dayOnly(_selectedEmployee!.hireDate);
    }
    final hires = employees.map((e) => _dayOnly(e.hireDate));
    final earliest = hires.isEmpty
        ? _from
        : hires.reduce((a, b) => a.isBefore(b) ? a : b);
    return earliest.isBefore(_from) ? earliest : _from;
  }

  /// Bare panel, like the pointage history's: the employee is the heading —
  /// see [PayrollDayDetail]. Its button pays this one day, whatever range the
  /// page is filtered to.
  Future<void> _openDrawer(
    Attendance a,
    _PayrollRowData data,
    StoreSettings settings,
  ) {
    final employee = data.employee;
    return DetailDrawer.show(
      context,
      children: [
        PayrollDayDetail(
          entry: a,
          employee: employee,
          rate: data.rate,
          amount: data.amount,
          paidAt: data.paidAt,
          maxBreakMinutes: resolvedMaxBreakMinutes(
            a,
            fallback: settings.maxBreakMinutes,
          ),
          onPay: employee == null
              ? null
              : () => _confirmPay(employee, from: a.date, to: a.date),
        ),
      ],
    );
  }

  /// Settles [employee]'s unpaid finished days from [from] to [to] — the
  /// page's filtered range from the button under the table, a single day from
  /// the drawer. Resolves true once paid.
  Future<bool> _confirmPay(
    Employee employee, {
    required DateTime from,
    required DateTime to,
  }) async {
    final l10n = AppLocalizations.of(context);
    final payroll = ref.read(payrollRepositoryProvider);
    final preview = await payroll.preview(
      employee.id,
      widget.storeId,
      from: from,
      to: to,
    );
    if (!mounted || preview.isEmpty) return false;

    final rangeLabel = from == to
        ? Formatters.date(from)
        : '${Formatters.date(from)} – ${Formatters.date(to)}';

    final ok = await ConfirmDialog.show(
      context,
      title: l10n.payrollPayConfirmTitle(employeeDisplayName(employee)),
      message: l10n.payrollPayConfirmBody(
        rangeLabel,
        preview.days.length,
        Formatters.price(preview.amount),
      ),
      confirmLabel: l10n.payrollPayAction,
    );
    if (!ok || !mounted) return false;

    final actorId = ref.read(currentEmployeeProvider)?.id;
    if (actorId == null) return false;

    // The person settling the days confirms with their own PIN — the same
    // check as the pointage board: unlimited tries, no lockout.
    final identityOk = await IdentityPromptDialog.show(
      context,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptPayrollSubtitle(employeeDisplayName(employee)),
      verify: (pin) =>
          ref.read(credentialRepositoryProvider).verifyPin(pin, actorId),
    );
    if (!identityOk || !mounted) return false;

    // Pays exactly what was confirmed, or nothing (audit L9).
    final PayrollPeriod? period;
    try {
      period = await payroll.pay(
        employee.id,
        widget.storeId,
        from: from,
        to: to,
        paidByEmployeeId: actorId,
        expected: preview,
      );
    } on PayrollPreviewOutdated {
      if (!mounted) return false;
      ref.invalidate(payrollDaysProvider);
      AppSnackBar.error(context, l10n.payrollPreviewOutdated);
      return false;
    }
    if (!mounted) return false;
    if (period == null) {
      AppSnackBar.error(context, l10n.payrollPayFailed);
      return false;
    }

    // A `FutureProvider` — nudge it so the table reflects the settled days.
    ref.invalidate(payrollDaysProvider);
    AppSnackBar.success(context, l10n.payrollPaid);
    return true;
  }
}

// -----------------------------------------------------------------------------

/// Search on the left, début, fin and statut at the right edge — the same strip
/// as the Personnel page and the attendance history.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.selectedEmployee,
    required this.employees,
    required this.from,
    required this.to,
    required this.status,
    required this.floor,
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
  final PaymentStatus? status;
  final DateTime floor;
  final DateTime defaultFrom;
  final DateTime defaultTo;
  final ValueChanged<Employee?> onEmployee;
  final ValueChanged<DateTime> onFrom;
  final ValueChanged<DateTime> onTo;
  final ValueChanged<PaymentStatus?> onStatus;

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
          firstDate: floor,
          lastDate: to,
          isDefault: from == defaultFrom,
          onChanged: onFrom,
        ),
        DateFilter(
          key: const ValueKey('date-filter-to'),
          label: l10n.historyFilterTo,
          value: to,
          firstDate: from,
          lastDate: _dayOnly(clock.now()),
          isDefault: to == defaultTo,
          onChanged: onTo,
        ),
        FilterMenu<PaymentStatus?>(
          label: l10n.payrollFilterStatus,
          selectedLabel: status == null
              ? null
              : paymentStatusLabel(l10n, status!),
          entries: {
            null: l10n.payrollStatusAll,
            PaymentStatus.paid: l10n.payrollStatusPaid,
            PaymentStatus.unpaid: l10n.payrollStatusUnpaid,
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
  final PaymentStatus? status;
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
            label: paymentStatusLabel(l10n, status!),
            onRemove: onRemoveStatus,
          ),
        TextButton(onPressed: onClear, child: Text(l10n.inventoryClearFilters)),
      ],
    );
  }
}

/// Below this the day list switches from the table to cards. The table's own
/// minimum width, so the two can never disagree.
double _daysTableMinWidth(bool showEmployee) => showEmployee ? 1000 : 860;

class _DaysTable extends StatelessWidget {
  const _DaysTable({
    required this.rows,
    required this.employeesById,
    required this.periodsById,
    required this.settings,
    required this.showEmployee,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final Map<String, PayrollPeriod> periodsById;
  final StoreSettings settings;
  final bool showEmployee;
  final ValueChanged<Attendance> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: _daysTableMinWidth(showEmployee),
      columns: [
        if (showEmployee) DataColumn(label: Text(l10n.payrollColumnEmployee)),
        DataColumn(label: Text(l10n.payrollColumnDate)),
        DataColumn(label: Text(l10n.payrollColumnBreaks)),
        DataColumn(label: Text(l10n.payrollColumnWorked)),
        DataColumn(label: Text(l10n.payrollColumnAmount), numeric: true),
        DataColumn(label: Text(l10n.payrollColumnStatus)),
        DataColumn(label: Text(l10n.payrollColumnPaidAt)),
      ],
      rows: [for (final a in rows) _row(context, l10n, a)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Attendance a) {
    final theme = Theme.of(context);
    final data = _payrollRowData(a, employeesById, periodsById, settings);
    final employee = data.employee;
    final pauses = totalPauseCount(a);

    return DataRow(
      onSelectChanged: (_) => onOpen(a),
      cells: [
        if (showEmployee)
          DataCell(
            EmployeeCell(
              employee: employee,
              dimmed: employee?.archivedAt != null,
              trailing: employee?.archivedAt != null
                  ? const RetiredChip(key: ValueKey('payroll-row-retired'))
                  : null,
            ),
          ),
        DataCell(WeekdayDate(a.date)),
        DataCell(
          pauses == 0
              ? const Text('—')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$pauses'),
                    Text(
                      Formatters.duration(totalBreak(a)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
        DataCell(
          Text(data.worked == null ? '—' : Formatters.duration(data.worked!)),
        ),
        DataCell(NumericCell(Formatters.price(data.amount), emphasis: true)),
        DataCell(PaymentStatusBadge(status: a.paymentStatus)),
        DataCell(
          data.paidAt == null ? const Text('—') : WeekdayDate(data.paidAt!),
        ),
      ],
    );
  }
}

/// The fields a table row and a card both need, computed once so the two
/// renderings of the same day can never drift apart — mirrors
/// `_attendanceRowData` in the pointage history page.
///
/// A paid day is figured at the rate frozen on its payroll run, an unpaid one
/// at the employee's current rate — see [dayRate].
typedef _PayrollRowData = ({
  Employee? employee,
  Duration? worked,
  double rate,
  double amount,
  DateTime? paidAt,
});

_PayrollRowData _payrollRowData(
  Attendance a,
  Map<String, Employee> employeesById,
  Map<String, PayrollPeriod> periodsById,
  StoreSettings settings,
) {
  final employee = employeesById[a.employeeId];
  final period = a.payrollPeriodId == null
      ? null
      : periodsById[a.payrollPeriodId!];
  final rate = employee == null
      ? period?.appliedRate ?? 0.0
      : dayRate(employee, settings, period);

  return (
    employee: employee,
    worked: workedDuration(a),
    rate: rate,
    amount: dayAmountAt(a, rate),
    paidAt: period?.paidAt,
  );
}

/// The payroll history as a grid of day cards — the table's small-screen
/// alternative, the same concept as `_HistoryCards` on the pointage history
/// page: one card per line on a phone, two or more on a tablet, via the shared
/// [ResponsiveCardGrid].
class _DaysCards extends StatelessWidget {
  const _DaysCards({
    required this.rows,
    required this.employeesById,
    required this.periodsById,
    required this.settings,
    required this.showEmployee,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final Map<String, PayrollPeriod> periodsById;
  final StoreSettings settings;
  final bool showEmployee;
  final ValueChanged<Attendance> onOpen;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCardGrid(
      children: [
        for (final a in rows)
          _PayrollDayCard(
            attendance: a,
            data: _payrollRowData(a, employeesById, periodsById, settings),
            showEmployee: showEmployee,
            onTap: () => onOpen(a),
          ),
      ],
    );
  }
}

/// One paid or unpaid day, as a card — styled after [OrderRow]: a status
/// stripe down the left edge instead of a neutral surface, and the money
/// figure set in the same tabular numeric style as an order total.
class _PayrollDayCard extends StatelessWidget {
  const _PayrollDayCard({
    required this.attendance,
    required this.data,
    required this.showEmployee,
    required this.onTap,
  });

  final Attendance attendance;
  final _PayrollRowData data;
  final bool showEmployee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final employee = data.employee;
    final colors = PaymentStatusBadge.colorsFor(attendance.paymentStatus);

    return AppCard(
      onTap: onTap,
      accentColor: colors.solid,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A Wrap, not a Row: on a narrow card « Retiré » drops
                    // under the name instead of pushing past the edge.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          showEmployee && employee != null
                              ? employeeDisplayName(employee)
                              : Formatters.dateLong(attendance.date),
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showEmployee && employee?.archivedAt != null)
                          const RetiredChip(),
                      ],
                    ),
                    Text(
                      showEmployee
                          ? Formatters.date(attendance.date)
                          : (employee == null
                                ? '—'
                                : employee.pin),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PaymentStatusBadge(status: attendance.paymentStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Figure(
                  label: l10n.payrollColumnWorked,
                  value: data.worked == null
                      ? '—'
                      : Formatters.duration(data.worked!),
                ),
              ),
              _Figure(
                label: l10n.payrollColumnAmount,
                value: Formatters.price(data.amount),
                alignEnd: true,
                emphasis: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled figure inside a [_PayrollDayCard] — worked/overtime/amount all
/// share this shape, with the amount set apart by [emphasis].
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: emphasis
              ? AppTypography.numeric
              : theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}
