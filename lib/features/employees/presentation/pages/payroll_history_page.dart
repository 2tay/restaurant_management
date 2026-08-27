import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

enum _Period {
  last30(30),
  last90(90),
  last365(365),
  all(null);

  const _Period(this.days);
  final int? days;
}

const int _pageSize = 25;

/// The payroll history — every run the store has paid, filterable by employee
/// and period, with the "Nouveau paiement" flow.
class PayrollHistoryPage extends ConsumerStatefulWidget {
  const PayrollHistoryPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<PayrollHistoryPage> createState() =>
      _PayrollHistoryPageState();
}

class _PayrollHistoryPageState extends ConsumerState<PayrollHistoryPage> {
  _Period _period = _Period.last90;
  String _employeeQuery = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(mockDataRevisionProvider);
    final l10n = AppLocalizations.of(context);

    return ShellPage(
      title: l10n.payrollHistoryTitle,
      subtitle: l10n.payrollHistorySubtitle,
      scrollable: false,
      actions: [
        PrimaryButton(
          label: l10n.payrollNewAction,
          icon: LucideIcons.banknote,
          onPressed: () =>
              context.pushScreen(Routes.toPayrollNew(widget.storeId)),
        ),
      ],
      child: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final result = MockQueries.payrollPeriodsForStore(
      widget.storeId,
      withinDays: _period.days,
      employeeQuery: _employeeQuery.trim().isEmpty ? null : _employeeQuery,
      page: _page,
      pageSize: _pageSize,
    );
    if (result.page != _page) _page = result.page;

    final storeEmpty =
        MockQueries.payrollPeriodsForStore(widget.storeId).totalCount == 0;

    // KPIs over the filtered period (all rows in the window, not just the page).
    final windowRows = MockQueries.payrollPeriodsForStore(
      widget.storeId,
      withinDays: _period.days,
      pageSize: 100000,
    ).rows;
    final total = windowRows.fold<double>(0, (s, p) => s + p.computedAmount);
    final overtime = windowRows.fold<double>(
      0,
      (s, p) => s + p.totalOvertimeHours,
    );
    final employees = windowRows.map((p) => p.employeeId).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.payrollStatRuns,
                value: '${windowRows.length}',
                icon: LucideIcons.receipt,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: StatTile(
                label: l10n.payrollStatTotal,
                value: Formatters.price(total),
                icon: LucideIcons.banknote,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: StatTile(
                label: l10n.payrollStatEmployees,
                value: '$employees',
                icon: LucideIcons.users,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: StatTile(
                label: l10n.payrollStatOvertime,
                value: Formatters.duration(
                  Duration(minutes: (overtime * 60).round()),
                ),
                icon: LucideIcons.hourglass,
              ),
            ),
          ],
        ),
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
                onChanged: (q) => setState(() {
                  _employeeQuery = q;
                  _page = 0;
                }),
              ),
            ),
            FilterMenu<_Period>(
              label: l10n.movementsFilterPeriod,
              selectedLabel: _periodLabel(l10n, _period),
              entries: {
                for (final p in _Period.values) p: _periodLabel(l10n, p),
              },
              onSelected: (p) => setState(() {
                _period = p;
                _page = 0;
              }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.payrollHistoryCount(result.totalCount),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: result.rows.isEmpty
              ? EmptyState(
                  icon: LucideIcons.receipt,
                  title: storeEmpty
                      ? l10n.payrollHistoryEmpty
                      : l10n.emptyStateNoResultsTitle,
                  message: storeEmpty
                      ? l10n.payrollHistoryEmptyBody
                      : l10n.emptyStateNoResultsBody,
                  actionLabel: storeEmpty ? l10n.payrollNewAction : null,
                  actionIcon: storeEmpty ? LucideIcons.banknote : null,
                  onAction: storeEmpty
                      ? () => context.pushScreen(
                          Routes.toPayrollNew(widget.storeId),
                        )
                      : null,
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _Table(rows: result.rows),
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
                ),
        ),
      ],
    );
  }
}

String _periodLabel(AppLocalizations l10n, _Period period) => switch (period) {
  _Period.last30 => l10n.periodLast30Days,
  _Period.last90 => l10n.periodLast90Days,
  _Period.last365 => l10n.payrollPeriodLastYear,
  _Period.all => l10n.periodAll,
};

class _Table extends StatelessWidget {
  const _Table({required this.rows});

  final List<PayrollPeriod> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DataTableWrapper(
      minWidth: 940,
      columns: [
        DataColumn(label: Text(l10n.payrollColumnEmployee)),
        DataColumn(label: Text(l10n.payrollColumnPeriod)),
        DataColumn(label: Text(l10n.payrollColumnDays)),
        DataColumn(label: Text(l10n.payrollColumnHours)),
        DataColumn(label: Text(l10n.payrollColumnOvertime)),
        DataColumn(label: Text(l10n.payrollColumnAmount)),
        DataColumn(label: Text(l10n.payrollColumnPaidAt)),
        DataColumn(label: Text(l10n.payrollColumnPaidBy)),
      ],
      rows: [
        for (final p in rows) _row(context, l10n, p),
      ],
    );
  }

  DataRow _row(BuildContext context, AppLocalizations l10n, PayrollPeriod p) {
    final employee = MockQueries.employeeById(p.employeeId);
    final paidBy = p.paidByEmployeeId == null
        ? null
        : MockQueries.employeeById(p.paidByEmployeeId!);

    return DataRow(
      cells: [
        DataCell(
          Text(employee == null ? '—' : employeeDisplayName(employee)),
        ),
        DataCell(
          Text(
            '${Formatters.date(p.startDate)} – ${Formatters.date(p.endDate)}',
          ),
        ),
        DataCell(Text('${p.workedDays}')),
        DataCell(
          Text(
            Formatters.duration(
              Duration(minutes: (p.totalWorkedHours * 60).round()),
            ),
          ),
        ),
        DataCell(
          Text(
            p.totalOvertimeHours == 0
                ? '—'
                : Formatters.duration(
                    Duration(minutes: (p.totalOvertimeHours * 60).round()),
                  ),
          ),
        ),
        DataCell(Text(Formatters.price(p.computedAmount))),
        DataCell(Text(p.paidAt == null ? '—' : Formatters.date(p.paidAt!))),
        DataCell(
          Text(paidBy == null ? '—' : employeeDisplayName(paidBy)),
        ),
      ],
    );
  }
}
