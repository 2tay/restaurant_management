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
import '../../../team/presentation/pages/team_list_page.dart' show roleLabel;
import '../widgets/time_entry_history_list.dart';
import 'employees_list_page.dart';

/// One employee's profile and clock history.
///
/// Pushed from the roster, so it carries a labelled back control rather than
/// being reached from the sidebar directly. Attendance is read-only here —
/// same reasoning as an item's quantity being read-only on its edit form: a
/// correction to a clock time is a Stage 2/3 concern with its own trail, not
/// something to slip in from a routine profile screen.
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
    // The profile, the archived state and the clock history all move under
    // this screen.
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
    final entries = MockQueries.timeEntriesForEmployee(employeeId);

    return ShellPage(
      back: BackDestination(
        label: l10n.employeesTitle,
        path: Routes.toEmployees(storeId),
      ),
      crumbs: [
        Crumb(l10n.employeesTitle, Routes.toEmployees(storeId)),
        Crumb(employee.fullName),
      ],
      title: employee.fullName,
      subtitle: employeeTypeLabel(l10n, employee.type),
      actions: [
        SecondaryButton(
          label: l10n.actionEdit,
          icon: LucideIcons.pencil,
          onPressed: () =>
              context.pushScreen(Routes.toEditEmployee(storeId, employeeId)),
        ),
        if (!archived)
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
                  icon: LucideIcons.mapPin,
                  label: l10n.employeeFormAddress,
                  value: employee.address,
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

          SectionHeader(title: l10n.employeeDetailEmployment),
          AppCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: LucideIcons.briefcase,
                  label: l10n.employeeFormType,
                  value: employeeTypeLabel(l10n, employee.type),
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(
                  icon: LucideIcons.wallet,
                  label: payTypeLabel(l10n, employee.payType),
                  value: employee.payType == PayType.monthlySalary
                      ? Formatters.price(employee.payRate)
                      : '${Formatters.price(employee.payRate)} / h',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: l10n.employeeAccessTitle),
          _AccessCard(storeId: storeId, employee: employee),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(
            title: l10n.employeeHistoryTitle,
            count: entries.isEmpty ? null : entries.length,
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: TimeEntryHistoryList(entries: entries),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, Employee employee) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.employeeArchiveTitle('« ${employee.fullName} »'),
      message: l10n.employeeArchiveBody,
      confirmLabel: l10n.employeeArchiveConfirm,
    );
    if (!confirmed || !context.mounted) return;

    EmployeeMutations.archive(employee.id);
    AppSnackBar.success(context, l10n.employeeArchived);
    context.goSection(Routes.toEmployees(storeId));
  }
}

/// The "Accès à l'application" card: either an invitation to grant one, or a
/// link through to the account this employee already has.
///
/// A dangling `teamMemberId` (the linked account was removed some other way
/// than through `AccountMutations.removeMember`, which is the only path that
/// clears it) falls back to the "no access" state rather than crashing —
/// defensive, since nothing in this codebase should be able to produce that
/// state, but a missing record is cheap to treat as absent instead of
/// asserted against.
class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.storeId, required this.employee});

  final String storeId;
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final teamMemberId = employee.teamMemberId;
    final member = teamMemberId == null
        ? null
        : MockQueries.teamMemberById(teamMemberId);

    if (member == null) {
      return AppCard(
        child: Row(
          children: [
            const Icon(
              LucideIcons.shieldOff,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.employeeAccessNone,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SecondaryButton(
              label: l10n.employeeAccessGrant,
              icon: LucideIcons.userPlus,
              onPressed: () => context.pushScreen(
                Routes.toLinkTeamAccess(storeId, employee.id),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: () =>
          context.pushScreen(Routes.toEditTeamMember(storeId, member.id)),
      child: Row(
        children: [
          Icon(
            LucideIcons.shieldCheck,
            size: AppSizing.iconMd,
            color: AppColors.inStock.foreground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.employeeAccessLinked(roleLabel(l10n, member.role)),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconMd,
            color: AppColors.textSecondary,
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
