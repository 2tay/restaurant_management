import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'primary_button.dart';

/// What a list shows when it has nothing in it.
///
/// Never a blank table. A new store opening the inventory should be told what
/// to do next, not left wondering whether the app is broken — so [action] is
/// strongly encouraged wherever the user can actually fix the emptiness.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;

  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  /// The "nothing matched your filters" case, which is different from "there is
  /// nothing here" — the fix is to change the filters, not to add data.
  factory EmptyState.noResults(
    AppLocalizations l10n, {
    VoidCallback? onClearFilters,
    String? clearLabel,
  }) {
    return EmptyState(
      icon: LucideIcons.searchX,
      title: l10n.emptyStateNoResultsTitle,
      message: l10n.emptyStateNoResultsBody,
      actionLabel: clearLabel,
      onAction: onClearFilters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
