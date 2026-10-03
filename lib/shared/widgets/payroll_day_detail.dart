import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/attendance_status.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import 'attendance_day_detail.dart';
import 'attendance_timeline.dart';
import 'day_summary_table.dart';
import 'payment_status_badge.dart';
import 'primary_button.dart';

/// One day of the Historique de paiement, as its drawer shows it — the same
/// reading order as the pointage drawers' [AttendanceDayDetail]:
///
/// 1. who (avatar, name, PIN) with the day's payment status;
/// 2. the day, and one short line saying what the rest shows;
/// 3. the sessions, each titled `Session N° x`;
/// 4. the summary table — time worked, breaks, the hourly rate and the amount
///    (rate × time worked over every session), then when it was paid;
/// 5. « Payer ce jour » while the day is unpaid and [onPay] is given.
///
/// [rate] and [amount] are figured by the caller, so the drawer shows exactly
/// what the table row beside it does: the rate frozen on the payroll run for a
/// paid day, the employee's current one for an unpaid day.
class PayrollDayDetail extends StatelessWidget {
  const PayrollDayDetail({
    required this.entry,
    required this.rate,
    required this.amount,
    required this.maxBreakMinutes,
    this.employee,
    this.paidAt,
    this.onPay,
    super.key,
  });

  final Attendance entry;

  /// €/h the day is figured at.
  final double rate;
  final double amount;
  final int maxBreakMinutes;

  /// Null when the row's employee is gone — the badge stands alone.
  final Employee? employee;

  /// When the day's payroll run was settled; null while unpaid.
  final DateTime? paidAt;

  /// Pays this one day. Resolves true once paid, which closes the drawer —
  /// its figures would otherwise go stale under the refreshed table.
  final Future<bool> Function()? onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final worked = workedDuration(entry);
    final rateLabel = l10n.payrollRatePerHour(Formatters.price(rate));
    final pay = onPay;
    final payable =
        pay != null &&
        employee != null &&
        entry.paymentStatus == PaymentStatus.unpaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceIdentityRow(
          employee: employee,
          badge: PaymentStatusBadge(status: entry.paymentStatus),
        ),
        const SizedBox(height: AppSpacing.xl),
        AttendanceDayDate(date: entry.date),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.payrollDayIntro,
          key: const ValueKey('payroll-day-intro'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AttendanceSessions(entry: entry, maxBreakMinutes: maxBreakMinutes),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          l10n.attendanceDaySummary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DaySummaryTable(
          key: const ValueKey('payroll-day-summary'),
          rows: [
            DaySummaryRow(
              valueKey: const ValueKey('payroll-day-worked'),
              label: l10n.attendanceTotalWorked,
              value: worked == null ? '—' : Formatters.duration(worked),
            ),
            DaySummaryRow(
              valueKey: const ValueKey('payroll-day-pauses'),
              label: l10n.attendancePausesCount(totalPauseCount(entry)),
              value: Formatters.duration(totalBreak(entry)),
            ),
            DaySummaryRow(
              valueKey: const ValueKey('payroll-day-rate'),
              label: l10n.payrollDetailRate,
              value: rateLabel,
            ),
            DaySummaryRow(
              valueKey: const ValueKey('payroll-day-amount'),
              label: l10n.payrollDetailAmount(
                Formatters.price(rate),
                Formatters.duration(worked ?? Duration.zero),
              ),
              value: Formatters.price(amount),
              emphasis: true,
            ),
            if (paidAt != null)
              DaySummaryRow(
                valueKey: const ValueKey('payroll-day-paid-at'),
                label: l10n.payrollColumnPaidAt,
                value: Formatters.date(paidAt!),
              ),
          ],
        ),
        if (payable) ...[
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            label: l10n.payrollDetailPayNow,
            icon: LucideIcons.banknote,
            fullWidth: true,
            onPressed: () async {
              final paid = await pay();
              if (paid && context.mounted) {
                DrawerScope.maybeOf(context)?.close();
              }
            },
          ),
        ],
      ],
    );
  }
}
