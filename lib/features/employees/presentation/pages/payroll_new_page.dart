import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Pick an employee, see everything owed to them (their unpaid finished days),
/// and pay it in one tap. "Payer" locks those days for good.
class PayrollNewPage extends ConsumerStatefulWidget {
  const PayrollNewPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<PayrollNewPage> createState() => _PayrollNewPageState();
}

class _PayrollNewPageState extends ConsumerState<PayrollNewPage> {
  String? _employeeId;

  @override
  Widget build(BuildContext context) {
    ref.watch(mockDataRevisionProvider);
    final l10n = AppLocalizations.of(context);
    final employees = MockQueries.activeEmployeesForStore(widget.storeId)
      ..sort((a, b) => employeeDisplayName(a).compareTo(employeeDisplayName(b)));

    final preview = _employeeId == null
        ? null
        : PayrollMutations.preview(_employeeId!, widget.storeId);

    return ShellPage(
      back: BackDestination(
        label: l10n.payrollHistoryTitle,
        path: Routes.toPayroll(widget.storeId),
      ),
      crumbs: [
        Crumb(l10n.payrollHistoryTitle, Routes.toPayroll(widget.storeId)),
        Crumb(l10n.payrollNewTitle),
      ],
      title: l10n.payrollNewTitle,
      subtitle: l10n.payrollNewSubtitle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.payrollNewEmployee),
            AppCard(
              child: AppDropdown<String>(
                label: l10n.payrollNewEmployee,
                value: _employeeId,
                hint: l10n.payrollNewEmployeeHint,
                options: [
                  for (final e in employees)
                    DropdownOption(
                      value: e.id,
                      label: employeeDisplayName(e),
                    ),
                ],
                onChanged: (value) => setState(() => _employeeId = value),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (preview != null) _PreviewSection(preview: preview),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.preview});

  final PayrollPreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (preview.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const Icon(
              LucideIcons.circleCheck,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.payrollNewNothingOwed,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.payrollNewDays,
          count: preview.days.length,
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final day in preview.days) _DayLine(day: day),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            children: [
              _TotalLine(
                label: l10n.payrollNewTotalWorked,
                value: Formatters.duration(
                  Duration(minutes: (preview.workedHours * 60).round()),
                ),
              ),
              const Divider(height: AppSpacing.xl),
              _TotalLine(
                label: l10n.payrollNewTotalOvertime,
                value: preview.overtimeHours == 0
                    ? '—'
                    : Formatters.duration(
                        Duration(
                          minutes: (preview.overtimeHours * 60).round(),
                        ),
                      ),
              ),
              const Divider(height: AppSpacing.xl),
              _TotalLine(
                label: l10n.payrollNewAmount,
                value: Formatters.price(preview.amount),
                emphasis: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: l10n.payrollNewPay,
          icon: LucideIcons.banknote,
          onPressed: () => _confirm(context),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final page = context.findAncestorStateOfType<_PayrollNewPageState>()!;
    final employeeId = page._employeeId!;
    final storeId = page.widget.storeId;
    final employee = MockQueries.employeeById(employeeId);

    final ok = await ConfirmDialog.show(
      context,
      title: l10n.payrollNewConfirmTitle(
        employee == null ? '' : employeeDisplayName(employee),
      ),
      message: l10n.payrollNewConfirmBody(
        preview.days.length,
        Formatters.price(preview.amount),
      ),
      confirmLabel: l10n.payrollNewPay,
    );
    if (!ok || !context.mounted) return;

    final period = PayrollMutations.pay(
      employeeId,
      storeId,
      paidByEmployeeId: mockCurrentEmployee.id,
    );
    if (period == null || !context.mounted) return;

    AppSnackBar.success(context, l10n.payrollNewPaid);
    context.goSection(Routes.toPayroll(storeId));
  }
}

class _DayLine extends StatelessWidget {
  const _DayLine({required this.day});

  final Attendance day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = [
      if (day.clockInAt != null) Formatters.time(day.clockInAt!),
      if (day.clockOutAt != null) Formatters.time(day.clockOutAt!),
    ].join(' – ');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              Formatters.date(day.date),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Expanded(
            child: Text(
              times,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasis
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyLarge;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(value, style: style),
      ],
    );
  }
}
