import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/payroll_math.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Sentinel [AppDropdown] value for "every employee".
const String _kAllEmployees = '__all__';

const int _pageSize = 25;

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// The payroll history, day by day: every active employee's finished days over
/// a chosen date range (or one employee's, once picked in the filter), paid or
/// still owed, plus a "Payer" action that settles the unpaid days **of the
/// shown range** for the selected employee.
///
/// A range start can never go before an employee's hire date — the picker is
/// bounded there and `MockQueries.payrollDays` enforces it again per employee.
class PayrollHistoryPage extends ConsumerStatefulWidget {
  const PayrollHistoryPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<PayrollHistoryPage> createState() => _PayrollHistoryPageState();
}

class _PayrollHistoryPageState extends ConsumerState<PayrollHistoryPage> {
  String _employeeSel = _kAllEmployees;
  late DateTime _from;
  late DateTime _to;
  PaymentStatus? _statusFilter;
  int _page = 0;

  String? get _employeeId =>
      _employeeSel == _kAllEmployees ? null : _employeeSel;

  @override
  void initState() {
    super.initState();
    _to = _dayOnly(DateTime.now());
    _from = _to.subtract(const Duration(days: 90));
  }

  void _onEmployeeChanged(String? value) {
    setState(() {
      _employeeSel = value ?? _kAllEmployees;
      _statusFilter = null;
      _page = 0;
      final id = _employeeId;
      if (id == null) return;
      final employee = MockQueries.employeeById(id);
      if (employee == null) return;
      final hire = _dayOnly(employee.hireDate);
      if (_from.isBefore(hire)) _from = hire;
      if (_to.isBefore(_from)) _to = _dayOnly(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockDataRevisionProvider);
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.payrollHistoryTitle,
      subtitle: l10n.payrollHistorySubtitle,
      scrollable: true,
      child: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final employees = MockQueries.activeEmployeesForStore(
      widget.storeId,
    )..sort((a, b) => employeeDisplayName(a).compareTo(employeeDisplayName(b)));

    final settings = MockQueries.storeSettings(widget.storeId);
    final data = MockQueries.payrollDays(
      widget.storeId,
      employeeId: _employeeId,
      from: _from,
      to: _to,
      status: _statusFilter,
      page: _page,
      pageSize: _pageSize,
    );
    if (data.page != _page) _page = data.page;

    final hasAnyDay = data.paidDays + data.unpaidDays > 0;
    final selectedEmployee = _employeeId == null
        ? null
        : MockQueries.employeeById(_employeeId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filters(l10n, employees),
        const SizedBox(height: AppSpacing.xl),
        _kpiRow(l10n, data),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.payrollHistoryCount(data.totalCount),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (data.rows.isEmpty)
          AppCard(
            padding: EdgeInsets.zero,
            child: hasAnyDay
                ? EmptyState.noResults(
                    l10n,
                    onClearFilters: () => setState(() => _statusFilter = null),
                    clearLabel: l10n.inventoryClearFilters,
                  )
                : EmptyState(
                    icon: LucideIcons.wallet,
                    title: l10n.payrollHistoryEmpty,
                    message: l10n.payrollHistoryEmptyBody,
                  ),
          )
        else ...[
          _DaysTable(
            rows: data.rows,
            settings: settings,
            openMinutes: settings.openMinutes,
            closeMinutes: settings.closeMinutes,
            showEmployee: _employeeId == null,
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

  Widget _filters(AppLocalizations l10n, List<Employee> employees) {
    final today = _dayOnly(DateTime.now());
    final floor = _pickerFloor(employees);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 240,
          child: SearchableDropdown<String>(
            label: l10n.payrollFilterEmployee,
            value: _employeeSel,
            options: [
              DropdownOption(
                value: _kAllEmployees,
                label: l10n.payrollFilterAllEmployees,
              ),
              for (final e in employees)
                DropdownOption(value: e.id, label: employeeDisplayName(e)),
            ],
            onChanged: _onEmployeeChanged,
          ),
        ),
        _labelled(
          l10n.payrollFilterFrom,
          SizedBox(
            width: 165,
            child: DateField(
              value: _from,
              compact: true,
              firstDate: floor,
              lastDate: _to,
              onChanged: (d) => setState(() {
                _from = _dayOnly(d);
                _page = 0;
              }),
            ),
          ),
        ),
        _labelled(
          l10n.payrollFilterTo,
          SizedBox(
            width: 165,
            child: DateField(
              value: _to,
              compact: true,
              firstDate: _from,
              lastDate: today,
              onChanged: (d) => setState(() {
                _to = _dayOnly(d);
                _page = 0;
              }),
            ),
          ),
        ),
        _labelled(
          l10n.payrollFilterStatus,
          FilterMenu<PaymentStatus?>(
            label: l10n.payrollFilterStatus,
            selectedLabel: _statusFilter == null
                ? l10n.payrollStatusAll
                : paymentStatusLabel(l10n, _statusFilter!),
            entries: {
              null: l10n.payrollStatusAll,
              PaymentStatus.paid: l10n.payrollStatusPaid,
              PaymentStatus.unpaid: l10n.payrollStatusUnpaid,
            },
            onSelected: (s) => setState(() {
              _statusFilter = s;
              _page = 0;
            }),
          ),
        ),
      ],
    );
  }

  /// The earliest day the "Du" picker may reach: the selected employee's hire
  /// date, or the earliest hire among active employees when showing everyone —
  /// never later than the current [_from].
  DateTime _pickerFloor(List<Employee> employees) {
    if (_employeeId != null) {
      final e = MockQueries.employeeById(_employeeId!);
      return e == null ? _from : _dayOnly(e.hireDate);
    }
    final hires = employees.map((e) => _dayOnly(e.hireDate));
    final earliest = hires.isEmpty
        ? _from
        : hires.reduce((a, b) => a.isBefore(b) ? a : b);
    return earliest.isBefore(_from) ? earliest : _from;
  }

  Widget _kpiRow(
    AppLocalizations l10n,
    ({
      List<Attendance> rows,
      int paidDays,
      int unpaidDays,
      Duration worked,
      Duration overtime,
      int totalCount,
      int page,
      int pageCount,
    })
    data,
  ) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.payrollStatPaidDays,
            value: '${data.paidDays}',
            icon: LucideIcons.circleCheck,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.payrollStatUnpaidDays,
            value: '${data.unpaidDays}',
            icon: LucideIcons.hourglass,
            accent: data.unpaidDays == 0 ? null : AppColors.lowStock,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.payrollStatWorkedHours,
            value: Formatters.duration(data.worked),
            icon: LucideIcons.clock,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: StatTile(
            label: l10n.payrollStatOvertimeHours,
            value: data.overtime == Duration.zero
                ? '—'
                : Formatters.duration(data.overtime),
            icon: LucideIcons.timer,
          ),
        ),
      ],
    );
  }

  Widget _labelled(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );

  Future<void> _confirmPay(Employee employee) async {
    final l10n = AppLocalizations.of(context);
    final preview = PayrollMutations.preview(
      employee.id,
      widget.storeId,
      from: _from,
      to: _to,
    );
    if (preview.isEmpty) return;

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

    final period = PayrollMutations.pay(
      employee.id,
      widget.storeId,
      from: _from,
      to: _to,
      paidByEmployeeId: mockCurrentEmployee.id,
    );
    if (period == null || !mounted) return;

    AppSnackBar.success(context, l10n.payrollPaid);
  }
}

class _DaysTable extends StatelessWidget {
  const _DaysTable({
    required this.rows,
    required this.settings,
    required this.openMinutes,
    required this.closeMinutes,
    required this.showEmployee,
  });

  final List<Attendance> rows;
  final StoreSettings settings;
  final int openMinutes;
  final int closeMinutes;
  final bool showEmployee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: showEmployee ? 1040 : 900,
      columns: [
        if (showEmployee) DataColumn(label: Text(l10n.payrollColumnEmployee)),
        DataColumn(label: Text(l10n.payrollColumnDate)),
        DataColumn(label: Text(l10n.payrollColumnClockIn)),
        DataColumn(label: Text(l10n.payrollColumnClockOut)),
        DataColumn(label: Text(l10n.payrollColumnWorked)),
        DataColumn(label: Text(l10n.payrollColumnOvertime)),
        DataColumn(label: Text(l10n.payrollColumnAmount)),
        DataColumn(label: Text(l10n.payrollColumnStatus)),
        DataColumn(label: Text(l10n.payrollColumnPaidAt)),
      ],
      rows: [for (final a in rows) _row(a)],
    );
  }

  DataRow _row(Attendance a) {
    final employee = MockQueries.employeeById(a.employeeId);
    final scheduleEnd = employee == null
        ? closeMinutes
        : resolvedSchedule(
            employee,
            storeOpenMinutes: openMinutes,
            storeCloseMinutes: closeMinutes,
          ).endMinutes;

    final worked = workedDuration(a);
    final overtime = overtimeBy(a, scheduleEnd);
    final amount = employee == null
        ? 0.0
        : dayAmount(a, employee, settings, scheduledEndMinutes: scheduleEnd);
    final paidAt = a.payrollPeriodId == null
        ? null
        : MockQueries.payrollPeriodById(a.payrollPeriodId!)?.paidAt;

    return DataRow(
      cells: [
        if (showEmployee)
          DataCell(
            Text(employee == null ? '—' : employeeDisplayName(employee)),
          ),
        DataCell(Text(Formatters.date(a.date))),
        DataCell(
          Text(a.clockInAt == null ? '—' : Formatters.time(a.clockInAt!)),
        ),
        DataCell(
          Text(a.clockOutAt == null ? '—' : Formatters.time(a.clockOutAt!)),
        ),
        DataCell(Text(worked == null ? '—' : Formatters.duration(worked))),
        DataCell(
          Text(
            overtime == null || overtime == Duration.zero
                ? '—'
                : Formatters.duration(overtime),
          ),
        ),
        DataCell(Text(Formatters.price(amount))),
        DataCell(PaymentStatusBadge(status: a.paymentStatus)),
        DataCell(Text(paidAt == null ? '—' : Formatters.date(paidAt))),
      ],
    );
  }
}
