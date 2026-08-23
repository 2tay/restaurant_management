import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/create_sheets.dart';

/// Manage the store's categories.
///
/// Exists because categories are user-created rather than hardcoded. Deleting
/// one warns how many items still reference it — a silent delete would leave
/// articles orphaned with no way to tell.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = MockQueries.categoriesForStore(storeId);

    return ShellPage(
      tabs: SectionTabs(
        currentPath: Routes.toCategories(storeId),
        tabs: [
          SectionTab(
            label: l10n.catalogTabCategories,
            path: Routes.toCategories(storeId),
          ),
          SectionTab(
            label: l10n.catalogTabUnits,
            path: Routes.toUnits(storeId),
          ),
        ],
      ),
      title: l10n.categoriesTitle,
      subtitle: l10n.categoriesSubtitle,
      actions: [
        PrimaryButton(
          label: l10n.categoriesAdd,
          icon: LucideIcons.plus,
          onPressed: () => _create(context),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: categories.isEmpty
            ? AppCard(
                child: EmptyState(
                  icon: LucideIcons.tags,
                  title: l10n.categoriesEmpty,
                  message: l10n.categoriesEmptyBody,
                  actionLabel: l10n.categoriesAdd,
                  actionIcon: LucideIcons.plus,
                  onAction: () => _create(context),
                ),
              )
            : AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final category in categories)
                      _CatalogTile(
                        icon: LucideIcons.tag,
                        title: category.name,
                        subtitle: l10n.categoriesItemCount(
                          MockQueries.itemCountInCategory(category.id),
                        ),
                        onEdit: () => _rename(context, category.name),
                        onDelete: () => _delete(
                          context,
                          name: category.name,
                          usageCount: MockQueries.itemCountInCategory(
                            category.id,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await CreateSheets.category(context);
    if (name == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).categoryCreated);
  }

  Future<void> _rename(BuildContext context, String current) async {
    final name = await CreateSheets.category(context);
    if (name == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).categoryUpdated);
  }

  Future<void> _delete(
    BuildContext context, {
    required String name,
    required int usageCount,
  }) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: name,
      // Naming the blast radius rather than a generic warning: "3 articles
      // devront être reclassés" is actionable, "êtes-vous sûr ?" is not.
      extraWarning: usageCount > 0
          ? l10n.categoriesInUseWarning(usageCount)
          : null,
    );

    if (confirmed && context.mounted) {
      AppSnackBar.success(context, l10n.categoryDeleted);
    }
  }
}

/// A row on the categories or units screen.
class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (trailingLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.pillAll,
              ),
              child: Text(trailingLabel!, style: theme.textTheme.labelMedium),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          IconButton(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil),
            tooltip: l10n.actionEdit,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2),
            tooltip: l10n.actionDelete,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

/// Reused by the units screen so both catalog screens stay identical in shape.
class CatalogTile extends StatelessWidget {
  const CatalogTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    this.trailingLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _CatalogTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailingLabel: trailingLabel,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
