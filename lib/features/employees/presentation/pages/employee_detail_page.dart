import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/attendance_status.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// One employee's profile.
///
/// Pushed from the roster, so it carries a labelled back control. The
/// attendance and payroll sections are placeholders in Phase 2 — Phases 3 and
/// 5 fill them in with the shared attendance row and a payroll list.
class EmployeeDetailPage extends ConsumerWidget {
  const EmployeeDetailPage({
    required this.storeId,
    required this.employeeId,
    super.key,
  });

  final String storeId;
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockDataRevisionProvider);

    final l10n = AppLocalizations.of(context);
    final employee = MockQueries.employeeById(employeeId);

    if (employee == null) {
      return ShellPage(
        title: l10n.employeesTitle,
        child: ErrorState(
          onRetry: () => context.goSection(Routes.toEmployees(storeId)),
        ),
      );
    }

    final archived = !isEmployeeActive(employee);
    final attendances = MockQueries.attendancesForEmployee(employeeId);
    final settings = MockQueries.storeSettings(storeId);
    final schedule = resolvedSchedule(
      employee,
      storeOpenMinutes: settings.openMinutes,
      storeCloseMinutes: settings.closeMinutes,
    );

    return ShellPage(
      back: BackDestination(
        label: l10n.employeesTitle,
        path: Routes.toEmployees(storeId),
      ),
      crumbs: [
        Crumb(l10n.employeesTitle, Routes.toEmployees(storeId)),
        Crumb(employeeDisplayName(employee)),
      ],
      title: employeeDisplayName(employee),
      subtitle: employeeRoleLabel(l10n, employee.role),
      actions: [
        SecondaryButton(
          label: l10n.actionEdit,
          icon: LucideIcons.pencil,
          onPressed: () =>
              context.pushScreen(Routes.toEditEmployee(storeId, employeeId)),
        ),
        if (archived)
          SecondaryButton(
            label: l10n.employeeRestore,
            icon: LucideIcons.userCheck,
            onPressed: () => _restore(context, employee),
          )
        else
          DestructiveButton(
            label: l10n.employeeArchiveConfirm,
            icon: LucideIcons.userMinus,
            filled: false,
            onPressed: () => _confirmArchive(context, employee),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EmployeeAvatar(employee: employee, size: 64, dimmed: archived),
              const SizedBox(width: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmployeeRoleBadge(role: employee.role),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.employeeHiredOn(Formatters.date(employee.hireDate)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (archived) ...[
            _ArchivedBanner(archivedAt: employee.archivedAt!),
            const SizedBox(height: AppSpacing.xl),
          ],

          SectionHeader(title: l10n.employeeDetailContact),
          AppCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: LucideIcons.mail,
                  label: l10n.employeeFormEmail,
                  value: employee.email,
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  icon: LucideIcons.phone,
                  label: l10n.employeeFormPhone,
                  value: employee.phone,
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  icon: LucideIcons.idCard,
                  label: l10n.employeeFormCin,
                  value: employee.cin,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.employeeFormEmployment),
          AppCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: LucideIcons.briefcase,
                  label: l10n.employeeFormContractType,
                  value: contractTypeLabel(l10n, employee.contractType),
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  icon: LucideIcons.wallet,
                  label: employee.contractType == ContractType.fixed
                      ? l10n.employeeFormPayMonthly
                      : l10n.employeeFormPayHourly,
                  value: employee.contractType == ContractType.fixed
                      ? Formatters.price(employee.pay)
                      : '${Formatters.price(employee.pay)} / h',
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  icon: LucideIcons.clock,
                  label: l10n.employeeFormSchedule,
                  value: _scheduleText(l10n, employee),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: l10n.employeeHistoryTitle,
            count: attendances.isEmpty ? null : attendances.length,
          ),
          _AttendanceHistoryCard(
            attendances: attendances,
            scheduledStartMinutes: schedule.startMinutes,
            maxBreakMinutes: settings.maxBreakMinutes,
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.employeePayrollTitle),
          const _PlaceholderCard(),
        ],
      ),
    );
  }

  String _scheduleText(AppLocalizations l10n, Employee employee) {
    final start = employee.scheduledStartMinutes;
    final end = employee.scheduledEndMinutes;
    if (start == null && end == null) return l10n.employeeScheduleStoreHours;
    final from = start == null ? '—' : Formatters.minutesToClock(start);
    final to = end == null ? '—' : Formatters.minutesToClock(end);
    return '$from – $to';
  }

  Future<void> _confirmArchive(BuildContext context, Employee employee) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.employeeArchiveTitle(
        '« ${employeeDisplayName(employee)} »',
      ),
      message: l10n.employeeArchiveBody,
      confirmLabel: l10n.employeeArchiveConfirm,
    );
    if (!confirmed || !context.mounted) return;

    EmployeeMutations.archive(employee.id);
    AppSnackBar.success(context, l10n.employeeArchived);
    context.goSection(Routes.toEmployees(storeId));
  }

  void _restore(BuildContext context, Employee employee) {
    final l10n = AppLocalizations.of(context);
    EmployeeMutations.restore(employee.id);
    AppSnackBar.success(context, l10n.employeeRestored);
  }
}

/// This employee's attendance, most recent first, using the shared
/// [AttendanceRow] the Historique tab (Phase 4) also builds on.
class _AttendanceHistoryCard extends StatelessWidget {
  const _AttendanceHistoryCard({
    required this.attendances,
    required this.scheduledStartMinutes,
    required this.maxBreakMinutes,
  });

  final List<Attendance> attendances;
  final int scheduledStartMinutes;
  final int maxBreakMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (attendances.isEmpty) {
      return AppCard(
        child: Text(
          l10n.employeeHistoryEmpty,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in attendances)
            AttendanceRow(
              attendance: entry,
              scheduledStartMinutes: scheduledStartMinutes,
              maxBreakMinutes: maxBreakMinutes,
            ),
        ],
      ),
    );
  }
}

/// A stand-in for a section whose real content lands in a later phase. Says
/// so plainly rather than pretending — same honesty as the app's fake login.
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppCard(
      child: Row(
        children: [
          const Icon(
            LucideIcons.hardHat,
            size: AppSizing.iconMd,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.employeeSectionComingSoonTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.archivedAt});

  final DateTime archivedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.userMinus,
            size: AppSizing.iconMd,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.employeeDetailArchivedOn(Formatters.date(archivedAt)),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizing.iconMd, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
      ],
    );
  }
}
