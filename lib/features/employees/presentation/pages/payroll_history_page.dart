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
import '../../../../core/utils/responsive.dart';
import '../../../../data/current_employee.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

const int _pageSize = 25;

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
  const PayrollHistoryPage({required this.storeId, super.key});

  final String storeId;

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

  /// The roster, cached from the last build so the synchronous filter handlers
  /// can resolve a floor without a query.
  List<Employee> _employees = const [];

  String? get _employeeId => _selectedEmployee?.id;

  @override
  void initState() {
    super.initState();
    _defaultTo = _dayOnly(DateTime.now());
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
      if (_to.isBefore(_from)) _to = _dayOnly(DateTime.now());
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
      ref.watch(activeEmployeesProvider(widget.storeId)),
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
          ref.invalidate(activeEmployeesProvider(widget.storeId));
          ref.invalidate(storeSettingsProvider(widget.storeId));
        },
        builder: (context, base) {
          _employees = [...base.employees]
            ..sort(
              (a, b) =>
                  employeeDisplayName(a).compareTo(employeeDisplayName(b)),
            );
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
          canReset: _hasActiveFilters,
          onReset: _clearFilters,
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
                l10n,
                a,
                data.employeesById[a.employeeId],
                data.paidAtByPeriod,
                settings,
              );
              return constraints.maxWidth >= (showEmployee ? 1080 : 940)
                  ? _DaysTable(
                      rows: data.rows,
                      employeesById: data.employeesById,
                      paidAtByPeriod: data.paidAtByPeriod,
                      settings: settings,
                      showEmployee: showEmployee,
                      onOpen: onOpen,
                    )
                  : _DaysCards(
                      rows: data.rows,
                      employeesById: data.employeesById,
                      paidAtByPeriod: data.paidAtByPeriod,
                      settings: settings,
                      showEmployee: showEmployee,
                      onOpen: onOpen,
                    );
            },
          ),
          if (data.pageCount > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Paginator(
              page: data.page,
              pageCount: data.pageCount,
              totalCount: data.totalCount,
              pageSize: _pageSize,
              onChanged: (p) => setState(() => _page = p),
            ),
          ],
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
                  : () => _confirmPay(selectedEmployee),
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
        StatTile(
          label: l10n.payrollStatOvertimeHours,
          value: data.overtime == Duration.zero
              ? '—'
              : Formatters.duration(data.overtime),
          icon: LucideIcons.timer,
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

  Future<void> _openDrawer(
    AppLocalizations l10n,
    Attendance a,
    Employee? employee,
    Map<String, DateTime> paidAtByPeriod,
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
    final money = employee == null
        ? const (rate: 0.0, base: 0.0, premium: 0.0, total: 0.0)
        : dayAmountBreakdown(
            a,
            employee,
            settings,
            scheduledEndMinutes: ctx.endMinutes,
          );
    final paidAt = a.payrollPeriodId == null
        ? null
        : paidAtByPeriod[a.payrollPeriodId!];

    return DetailDrawer.show(
      context,
      title: l10n.payrollDetailTitle,
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // Indented past the avatar so this lines up with the name/CIN
              // above rather than with the avatar's left edge.
              const SizedBox(width: 48 + AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.calendar,
                              size: AppSizing.iconSm,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              Formatters.date(a.date),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        PaymentStatusBadge(status: a.paymentStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              const Icon(
                LucideIcons.calendar,
                size: AppSizing.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                Formatters.date(a.date),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              PaymentStatusBadge(status: a.paymentStatus),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        _drawerSectionTitle(LucideIcons.clock, l10n.payrollColumnHours),
        const SizedBox(height: AppSpacing.md),
        DrawerRow(
          label: l10n.payrollColumnClockIn,
          value: a.clockInAt == null ? '—' : Formatters.time(a.clockInAt!),
        ),
        DrawerRow(
          label: l10n.payrollColumnClockOut,
          value: a.clockOutAt == null ? '—' : Formatters.time(a.clockOutAt!),
        ),
        if (a.pauses.isNotEmpty)
          DrawerRow(
            label: l10n.payrollDetailBreakTotal,
            value: Formatters.duration(totalBreak(a)),
          ),
        const SizedBox(height: AppSpacing.xxxl),
        _drawerSectionTitle(LucideIcons.timer, l10n.payrollDetailWorkSection),
        const SizedBox(height: AppSpacing.md),
        DrawerRow(
          label: l10n.payrollDetailWorked,
          value: worked == null ? '—' : Formatters.duration(worked),
        ),
        DrawerRow(
          label: l10n.payrollColumnOvertime,
          value: overtime == Duration.zero
              ? '—'
              : l10n.payrollDetailOvertimeInfo(Formatters.duration(overtime)),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _drawerSectionTitle(LucideIcons.wallet, l10n.payrollColumnAmount),
        const SizedBox(height: AppSpacing.md),
        DrawerRow(
          label: l10n.payrollDetailRate,
          value: '${Formatters.price(money.rate)} / h',
        ),
        DrawerRow(
          label: l10n.payrollDetailBase,
          value: Formatters.price(money.base),
        ),
        if (money.premium > 0)
          DrawerRow(
            label: l10n.payrollDetailPremium,
            value: Formatters.price(money.premium),
          ),
        DrawerRow(
          label: l10n.payrollDetailTotal,
          valueWidget: Text(
            Formatters.price(money.total),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (paidAt != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '${l10n.payrollColumnPaidAt} ${Formatters.date(paidAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inStock.foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (employee != null && a.paymentStatus == PaymentStatus.unpaid) ...[
          const SizedBox(height: AppSpacing.xxxl),
          PrimaryButton(
            label: l10n.payrollDetailPayNow,
            icon: LucideIcons.banknote,
            fullWidth: true,
            onPressed: () => _confirmPay(employee),
          ),
        ],
      ],
    );
  }

  /// A drawer section title matching the drawer header's own text style —
  /// bigger than the shared [SectionHeader], with a leading icon.
  Widget _drawerSectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: AppSizing.iconSm, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.xs),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ],
  );

  Future<void> _confirmPay(Employee employee) async {
    final l10n = AppLocalizations.of(context);
    final payroll = ref.read(payrollRepositoryProvider);
    final preview = await payroll.preview(
      employee.id,
      widget.storeId,
      from: _from,
      to: _to,
    );
    if (!mounted || preview.isEmpty) return;

    final rangeLabel = '${Formatters.date(_from)} – ${Formatters.date(_to)}';

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
    if (!ok || !mounted) return;

    final actorId = ref.read(currentEmployeeProvider)?.id;
    if (actorId == null) return;

    // The person settling the days confirms with their own CIN — same
    // wrong-attempt / 5-minute lockout as the pointage board.
    final identityOk = await IdentityPromptDialog.show(
      context,
      title: l10n.identityPromptTitle,
      subtitle: l10n.identityPromptPayrollSubtitle(employeeDisplayName(employee)),
      verify: (cin) =>
          ref.read(credentialRepositoryProvider).verifyCin(cin, actorId),
    );
    if (!identityOk || !mounted) return;

    final period = await payroll.pay(
      employee.id,
      widget.storeId,
      from: _from,
      to: _to,
      paidByEmployeeId: actorId,
    );
    if (!mounted || period == null) return;

    // A `FutureProvider` — nudge it so the table reflects the settled days.
    ref.invalidate(payrollDaysProvider);
    AppSnackBar.success(context, l10n.payrollPaid);
  }
}

// -----------------------------------------------------------------------------

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selectedEmployee,
    required this.employees,
    required this.from,
    required this.to,
    required this.status,
    required this.floor,
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
  final PaymentStatus? status;
  final DateTime floor;
  final bool canReset;
  final VoidCallback onReset;
  final ValueChanged<Employee?> onEmployee;
  final ValueChanged<DateTime> onFrom;
  final ValueChanged<DateTime> onTo;
  final ValueChanged<PaymentStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = _dayOnly(DateTime.now());

    return FilterBar(
      reset: canReset
          ? FilterResetButton(
              label: l10n.payrollFilterReset,
              onPressed: onReset,
            )
          : null,
      fields: [
        FilterField(
          label: l10n.payrollFilterEmployee,
          child: EmployeeSelector(
            employees: employees,
            value: selectedEmployee,
            showCin: true,
            hint: l10n.payrollFilterAllEmployees,
            onChanged: onEmployee,
          ),
        ),
        FilterField.date(
          label: l10n.payrollFilterFrom,
          child: DateField(
            value: from,
            compact: true,
            firstDate: floor,
            lastDate: to,
            onChanged: onFrom,
          ),
        ),
        FilterField.date(
          label: l10n.payrollFilterTo,
          child: DateField(
            value: to,
            compact: true,
            firstDate: from,
            lastDate: today,
            onChanged: onTo,
          ),
        ),
        FilterField.auto(
          label: l10n.payrollFilterStatus,
          child: FilterMenu<PaymentStatus?>(
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

class _DaysTable extends StatelessWidget {
  const _DaysTable({
    required this.rows,
    required this.employeesById,
    required this.paidAtByPeriod,
    required this.settings,
    required this.showEmployee,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final Map<String, DateTime> paidAtByPeriod;
  final StoreSettings settings;
  final bool showEmployee;
  final ValueChanged<Attendance> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: showEmployee ? 1080 : 940,
      columns: [
        if (showEmployee) DataColumn(label: Text(l10n.payrollColumnEmployee)),
        DataColumn(label: Text(l10n.payrollColumnDate)),
        DataColumn(label: Text(l10n.payrollColumnHours)),
        DataColumn(label: Text(l10n.payrollColumnWorked)),
        DataColumn(label: Text(l10n.payrollColumnOvertime)),
        DataColumn(label: Text(l10n.payrollColumnAmount), numeric: true),
        DataColumn(label: Text(l10n.payrollColumnStatus)),
        DataColumn(label: Text(l10n.payrollColumnPaidAt)),
        DataColumn(label: Text(l10n.payrollColumnDetail)),
      ],
      rows: [for (final a in rows) _row(context, l10n, a)],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, Attendance a) {
    final theme = Theme.of(context);
    final data = _payrollRowData(a, employeesById, paidAtByPeriod, settings);
    final employee = data.employee;

    final arrival = a.clockInAt == null ? '—' : Formatters.time(a.clockInAt!);
    final departure = a.clockOutAt == null
        ? '…'
        : Formatters.time(a.clockOutAt!);

    return DataRow(
      onSelectChanged: (_) => onOpen(a),
      cells: [
        if (showEmployee)
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
        DataCell(Text(Formatters.date(a.date))),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$arrival → $departure'),
              if (a.pauses.isNotEmpty)
                Text(
                  l10n.payrollBreakSummary(
                    a.pauses.length,
                    Formatters.duration(totalBreak(a)),
                  ),
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
        DataCell(
          Text(
            data.overtime == Duration.zero
                ? '—'
                : Formatters.duration(data.overtime),
          ),
        ),
        DataCell(NumericCell(Formatters.price(data.amount), emphasis: true)),
        DataCell(PaymentStatusBadge(status: a.paymentStatus)),
        DataCell(
          Text(data.paidAt == null ? '—' : Formatters.date(data.paidAt!)),
        ),
        DataCell(
          IconButton(
            tooltip: l10n.payrollViewDetail,
            icon: const Icon(LucideIcons.eye, size: AppSizing.iconSm),
            onPressed: () => onOpen(a),
          ),
        ),
      ],
    );
  }
}

/// The fields a table row and a card both need, computed once so the two
/// renderings of the same day can never drift apart — mirrors
/// `_attendanceRowData` in the pointage history page.
typedef _PayrollRowData = ({
  Employee? employee,
  Duration? worked,
  Duration overtime,
  double amount,
  DateTime? paidAt,
});

_PayrollRowData _payrollRowData(
  Attendance a,
  Map<String, Employee> employeesById,
  Map<String, DateTime> paidAtByPeriod,
  StoreSettings settings,
) {
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

  return (
    employee: employee,
    worked: workedDuration(a),
    overtime: overtimeBy(a, ctx.endMinutes) ?? Duration.zero,
    amount: employee == null
        ? 0.0
        : dayAmount(a, employee, settings, scheduledEndMinutes: ctx.endMinutes),
    paidAt: a.payrollPeriodId == null
        ? null
        : paidAtByPeriod[a.payrollPeriodId!],
  );
}

/// The payroll history as a grid of day cards — the table's small-screen
/// alternative, the same concept as `_HistoryCards` on the pointage history
/// page: fits as many columns as the available width allows via
/// [cardGridColumns] rather than always stacking a single column.
class _DaysCards extends StatelessWidget {
  const _DaysCards({
    required this.rows,
    required this.employeesById,
    required this.paidAtByPeriod,
    required this.settings,
    required this.showEmployee,
    required this.onOpen,
  });

  final List<Attendance> rows;
  final Map<String, Employee> employeesById;
  final Map<String, DateTime> paidAtByPeriod;
  final StoreSettings settings;
  final bool showEmployee;
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
                child: _PayrollDayCard(
                  attendance: a,
                  data: _payrollRowData(a, employeesById, paidAtByPeriod, settings),
                  showEmployee: showEmployee,
                  onTap: () => onOpen(a),
                ),
              ),
          ],
        );
      },
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
                    Text(
                      showEmployee && employee != null
                          ? employeeDisplayName(employee)
                          : Formatters.dateLong(attendance.date),
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      showEmployee
                          ? Formatters.date(attendance.date)
                          : (employee == null
                                ? '—'
                                : l10n.employeeCinLabel(employee.cin)),
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
              Expanded(
                child: _Figure(
                  label: l10n.payrollColumnOvertime,
                  value: data.overtime == Duration.zero
                      ? '—'
                      : Formatters.duration(data.overtime),
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
