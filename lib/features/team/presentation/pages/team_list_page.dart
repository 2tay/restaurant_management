import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Who can get into this store, and with what rights.
class TeamListPage extends StatelessWidget {
  const TeamListPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = MockQueries.teamForStore(storeId);

    return ShellPage(
      title: l10n.teamTitle,
      subtitle: l10n.teamSubtitle,
      scrollable: false,
      actions: [
        SecondaryButton(
          label: l10n.rolesTitle,
          icon: LucideIcons.shieldCheck,
          onPressed: () => context.pushScreen(Routes.toRoles(storeId)),
        ),
        PrimaryButton(
          label: l10n.teamInvite,
          icon: LucideIcons.userPlus,
          onPressed: () => context.pushScreen(Routes.toAddTeamMember(storeId)),
        ),
      ],
      child: members.isEmpty
          ? EmptyState(
              icon: LucideIcons.users,
              title: l10n.teamEmpty,
              message: l10n.teamEmptyBody,
              actionLabel: l10n.teamInvite,
              actionIcon: LucideIcons.userPlus,
              onAction: () =>
                  context.pushScreen(Routes.toAddTeamMember(storeId)),
            )
          : ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _MemberRow(member: members[index], storeId: storeId),
            ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.storeId});

  final TeamMember member;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final initials = member.fullName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();

    return AppCard(
      onTap: () =>
          context.pushScreen(Routes.toEditTeamMember(storeId, member.id)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: member.isActive
                  ? AppColors.primaryContainer
                  : AppColors.neutral100,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: theme.textTheme.labelLarge?.copyWith(
                color: member.isActive
                    ? AppColors.onPrimaryContainer
                    : AppColors.textDisabled,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!member.isActive) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Pill(
                        label: l10n.teamPending,
                        colors: AppColors.lowStock,
                      ),
                    ],
                  ],
                ),
                Text(
                  member.email,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(flex: 2, child: _RoleChip(role: member.role)),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            flex: 2,
            child: Text(
              member.lastActiveAt == null
                  ? l10n.teamStoreAccess(member.storeIds.length)
                  : l10n.teamLastActive(
                      Formatters.relative(member.lastActiveAt!),
                    ),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          IconButton(
            onPressed: () =>
                context.pushScreen(Routes.toEditTeamMember(storeId, member.id)),
            icon: const Icon(LucideIcons.pencil),
            tooltip: l10n.actionEdit,
          ),
        ],
      ),
    );
  }
}

/// Role badge. Owner is tinted; the other two are neutral, because "gérant" and
/// "employé" are the normal cases and should not compete for attention.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final TeamRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final label = roleLabel(l10n, role);
    final isOwner = role == TeamRole.owner;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isOwner
              ? AppColors.primaryContainer
              : AppColors.surfaceVariant,
          borderRadius: AppRadius.pillAll,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isOwner
                ? AppColors.onPrimaryContainer
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.colors});

  final String label;
  final StockStatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.foreground),
      ),
    );
  }
}

/// Shared role naming, so the list, the form and the matrix agree.
String roleLabel(AppLocalizations l10n, TeamRole role) => switch (role) {
  TeamRole.owner => l10n.roleOwner,
  TeamRole.manager => l10n.roleManager,
  TeamRole.staff => l10n.roleStaff,
};

String roleDescription(AppLocalizations l10n, TeamRole role) => switch (role) {
  TeamRole.owner => l10n.roleOwnerBody,
  TeamRole.manager => l10n.roleManagerBody,
  TeamRole.staff => l10n.roleStaffBody,
};
