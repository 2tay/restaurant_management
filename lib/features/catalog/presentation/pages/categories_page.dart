import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/create_sheets.dart';

/// Manage the store's categories.
///
/// Exists because categories are user-created rather than hardcoded.
///
/// Deleting one that is still in use is **refused**, not warned about. Items
/// reference their category by id, so removing one underneath them would leave
/// those articles rendering as "—" with no way for anyone to work out what they
/// used to say. The dialog names the count and the fix instead.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The per-category article counts move whenever an article is created,
    // recategorised or deleted, and this follows all three: they are the same
    // query's tables.
    final rows = ref.watch(categoryRowsProvider(storeId));

    final l10n = AppLocalizations.of(context);

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
        child: AsyncListContent<CategoryRowView>(
          value: rows,
          onRetry: () => ref.invalidate(categoryRowsProvider(storeId)),
          skeleton: const SkeletonList(rows: 5, rowHeight: 64),
          empty: AppCard(
            child: EmptyState(
              icon: LucideIcons.tags,
              title: l10n.categoriesEmpty,
              message: l10n.categoriesEmptyBody,
              actionLabel: l10n.categoriesAdd,
              actionIcon: LucideIcons.plus,
              onAction: () => _create(context),
            ),
          ),
          builder: (context, rows) => AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final row in rows)
                  _CatalogTile(
                    icon: LucideIcons.tag,
                    title: row.category.name,
                    subtitle: l10n.categoriesItemCount(row.itemCount),
                    onEdit: () => _edit(context, row.category),
                    onDelete: () => _delete(context, ref, row),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final created = await CreateSheets.category(context, storeId: storeId);
    if (created == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).categoryCreated);
  }

  Future<void> _edit(BuildContext context, Category category) async {
    final renamed = await CreateSheets.category(
      context,
      storeId: storeId,
      existing: category,
    );
    if (renamed == null || !context.mounted) return;
    AppSnackBar.success(context, AppLocalizations.of(context).categoryUpdated);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CategoryRowView row,
  ) async {
    final l10n = AppLocalizations.of(context);
    final category = row.category;

    // Checked before asking rather than after confirming: offering a delete
    // that then quietly fails is worse than not offering it. The count comes
    // from the row the user is looking at, so the sentence in the dialog and
    // the number on the screen cannot disagree.
    if (row.itemCount > 0) {
      await ConfirmDialog.blocked(
        context,
        title: l10n.categoryDeleteBlockedTitle(category.name),
        message: l10n.categoryDeleteBlockedBody(row.itemCount),
      );
      return;
    }

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: category.name,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(catalogRepositoryProvider).deleteCategory(category.id);

    if (!context.mounted) return;
    AppSnackBar.success(context, l10n.categoryDeleted);
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
