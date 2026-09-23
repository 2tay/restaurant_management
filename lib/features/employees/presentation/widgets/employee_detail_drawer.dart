import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/employee_status.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'employee_actions.dart';
import 'employee_wizard_dialog.dart';

/// How many of the most recent days the drawer lists — enough to see how the
/// week went; the full history is one tap away on the Historique screen.
const int _recentDays = 10;

/// Opens one employee's detail in a [DetailDrawer] over the roster — the
/// replacement for the old full-page profile, so the list stays in place
/// behind it.
///
/// The body watches the employee rather than being handed a snapshot, so an
/// archive or restore from inside the drawer shows at once.
Future<void> showEmployeeDetailDrawer(
  BuildContext context, {
  required String storeId,
  required Employee employee,
}) {
  return DetailDrawer.show(
    context,
    title: employeeDisplayName(employee),
    children: [
      EmployeeDetailBody(
        storeId: storeId,
        employeeId: employee.id,
        // The roster's context, not the drawer's: the drawer closes first,
        // and the edit dialog opens over the roster.
        onEdit: (current) => showEmployeeWizard(
          context,
          storeId: storeId,
          employee: current,
        ),
      ),
    ],
  );
}

/// The drawer's content: identity, actions, contact, pay, recent pointage.
class EmployeeDetailBody extends ConsumerWidget {
  const EmployeeDetailBody({
    required this.storeId,
    required this.employeeId,
    required this.onEdit,
    super.key,
  });

  final String storeId;
  final String employeeId;

  /// Opens the edit wizard for the employee as currently shown.
  final ValueChanged<Employee> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = asyncAll3(
      ref.watch(employeeProvider(employeeId)),
      ref.watch(attendanceForEmployeeProvider(employeeId)),
      ref.watch(storeSettingsProvider(storeId)),
      (employee, attendances, settings) =>
          (employee: employee, attendances: attendances, settings: settings),
    );

    return AsyncContent<
      ({
        Employee? employee,
        List<Attendance> attendances,
        StoreSettings settings,
      })
    >(
      value: data,
      onRetry: () {
        ref.invalidate(employeeProvider(employeeId));
        ref.invalidate(attendanceForEmployeeProvider(employeeId));
        ref.invalidate(storeSettingsProvider(storeId));
      },
      builder: (context, data) {
        final employee = data.employee;
        if (employee == null) return const ErrorState();
        return _body(context, ref, employee, data.attendances, data.settings);
      },
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    Employee employee,
    List<Attendance> attendances,
    StoreSettings settings,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final archived = !isEmployeeActive(employee);
    final recent = attendances.take(_recentDays).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            EmployeeAvatar(employee: employee, size: 56, dimmed: archived),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmployeeRoleBadge(role: employee.role),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.employeeHiredOn(Formatters.date(employee.hireDate)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        if (archived) ...[
          NoticeBanner(
            icon: LucideIcons.userMinus,
            title: l10n.employeeDetailArchivedOn(
              Formatters.date(employee.archivedAt!),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SecondaryButton(
              label: l10n.actionEdit,
              icon: LucideIcons.pencil,
              onPressed: () {
                Navigator.of(context).pop();
                onEdit(employee);
              },
            ),
            if (archived)
              SecondaryButton(
                label: l10n.employeeRestore,
                icon: LucideIcons.userCheck,
                onPressed: () => restoreEmployee(context, ref, employee),
              )
            else
              DestructiveButton(
                label: l10n.employeeArchiveConfirm,
                icon: LucideIcons.userMinus,
                filled: false,
                onPressed: () =>
                    confirmArchiveEmployee(context, ref, employee),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        SectionHeader(title: l10n.employeeDetailContact),
        DrawerRow(label: l10n.employeeFormEmail, value: employee.email),
        DrawerRow(label: l10n.employeeFormPhone, value: employee.phone),
        DrawerRow(label: l10n.employeeFormPin, value: employee.pin),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(title: l10n.employeeFormEmployment),
        DrawerRow(
          label: l10n.employeeFormPayHourly,
          value: '${Formatters.price(employee.pay)} / h',
        ),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(
          title: l10n.employeeHistoryTitle,
          count: attendances.isEmpty ? null : attendances.length,
        ),
        if (recent.isEmpty)
          Text(
            l10n.employeeHistoryEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final entry in recent)
                  AttendanceRow(
                    attendance: entry,
                    maxBreakMinutes: settings.maxBreakMinutes,
                  ),
              ],
            ),
          ),
          if (attendances.length > recent.length) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.goSection(Routes.toAttendanceHistory(storeId));
                },
                icon: const Icon(LucideIcons.history, size: AppSizing.iconSm),
                label: Text(l10n.employeeHistorySeeAll),
              ),
            ),
          ],
        ],
      ],
    );
  }

}
