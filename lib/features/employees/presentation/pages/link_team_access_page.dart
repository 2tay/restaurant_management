import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../team/presentation/pages/team_list_page.dart'
    show roleLabel, roleDescription;

/// Grants an employee an application account, reusing their name and email
/// rather than asking for them a second time.
///
/// Deliberately a separate page from `AddEditMemberPage` rather than that
/// page reused with pre-filled controllers: this one's identity fields are
/// fixed, not editable, because the whole point is that they came from the
/// employee record. The two write calls this makes — `AccountMutations.
/// invite` then `EmployeeMutations.linkTeamMember` — mirror the pattern
/// `LinkSupplierToItemPage` already uses for attaching one aggregate to
/// another: one screen, two mutation files, each touching only the list it
/// owns.
class LinkTeamAccessPage extends StatefulWidget {
  const LinkTeamAccessPage({
    required this.storeId,
    required this.employeeId,
    super.key,
  });

  final String storeId;
  final String employeeId;

  @override
  State<LinkTeamAccessPage> createState() => _LinkTeamAccessPageState();
}

class _LinkTeamAccessPageState extends State<LinkTeamAccessPage> {
  TeamRole _role = TeamRole.staff;
  late final Set<String> _storeIds = {widget.storeId};

  /// Set when the employee's email is already on the team under a different,
  /// unlinked account. Can't be fixed on this screen — the email here is
  /// read-only — so the message points back at the employee's own edit form.
  bool _emailConflict = false;

  bool get _isDirty => _role != TeamRole.staff || _storeIds.length != 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final employee = MockQueries.employeeById(widget.employeeId);

    if (employee == null) {
      return ShellPage(
        title: l10n.linkTeamAccessTitle,
        child: ErrorState(
          onRetry: () => context.goSection(Routes.toEmployees(widget.storeId)),
        ),
      );
    }

    return FormScaffold(
      title: l10n.linkTeamAccessTitle,
      subtitle: l10n.linkTeamAccessSubtitle(employee.fullName),
      back: BackDestination(
        label: employee.fullName,
        path: Routes.toEmployee(widget.storeId, employee.id),
      ),
      crumbs: [
        Crumb(l10n.employeesTitle, Routes.toEmployees(widget.storeId)),
        Crumb(
          employee.fullName,
          Routes.toEmployee(widget.storeId, employee.id),
        ),
        Crumb(l10n.linkTeamAccessTitle),
      ],
      submitLabel: l10n.linkTeamAccessSubmit,
      submitIcon: LucideIcons.userPlus,
      onSubmit: _storeIds.isNotEmpty ? () => _submit(employee) : null,
      isDirty: _isDirty,
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                _IdentityRow(
                  icon: LucideIcons.user,
                  label: l10n.employeeFormFullName,
                  value: employee.fullName,
                ),
                const Divider(height: AppSpacing.xl),
                _IdentityRow(
                  icon: LucideIcons.mail,
                  label: l10n.employeeFormEmail,
                  value: employee.email,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              l10n.linkTeamAccessIdentityHelp,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),

          if (_emailConflict) ...[
            const SizedBox(height: AppSpacing.lg),
            _ConflictBanner(message: l10n.linkTeamAccessEmailTaken),
          ],

          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.memberFormRole),
          for (final role in TeamRole.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LinkRoleOption(
                role: role,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: l10n.memberFormStores),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final store in mockStores)
                  CheckboxListTile(
                    value: _storeIds.contains(store.id),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _storeIds.add(store.id);
                      } else {
                        _storeIds.remove(store.id);
                      }
                    }),
                    title: Text(store.name),
                    subtitle: Text(store.city),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit(Employee employee) {
    final l10n = AppLocalizations.of(context);

    final member = AccountMutations.invite(
      fullName: employee.fullName,
      email: employee.email,
      role: _role,
      storeIds: _storeIds.toList(),
    );

    // Null means this email is already on the team under an account this
    // employee isn't linked to yet. Nothing on this screen can fix that — the
    // email field is fixed — so the message sends the user to the one place
    // that can.
    if (member == null) {
      setState(() => _emailConflict = true);
      return;
    }

    EmployeeMutations.linkTeamMember(employee.id, member.id);
    AppSnackBar.success(context, l10n.linkTeamAccessGranted);
    context.pushScreen(Routes.toEmployee(widget.storeId, employee.id));
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
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

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.outOfStock;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.triangleAlert,
            color: colors.foreground,
            size: AppSizing.iconMd,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same role choice card `AddEditMemberPage` uses, kept local here rather
/// than shared — the two forms' surrounding state differs enough that a
/// shared widget would need to abstract over both, for one card that is
/// three fields wide.
class _LinkRoleOption extends StatelessWidget {
  const _LinkRoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final TeamRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      selected: selected,
      child: Row(
        children: [
          Icon(
            selected ? LucideIcons.circleCheck : LucideIcons.circle,
            size: AppSizing.iconLg,
            color: selected ? AppColors.primary600 : AppColors.borderStrong,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleLabel(l10n, role), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  roleDescription(l10n, role),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
