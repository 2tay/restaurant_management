import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Search across items, suppliers and categories for the current store.
///
/// Filters the static mock data client-side, which is all Phase 1 needs and
/// what Phase 2 will keep doing for anything already cached locally.
///
/// Results are grouped by kind rather than merged into one ranked list. Someone
/// typing "poulet" wants either the article or a supplier of it, and a blended
/// list makes them read every row to find out which is which.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({required this.storeId, super.key});

  final String storeId;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();

    final items = query.isEmpty
        ? <Item>[]
        : MockQueries.itemsForStore(
            widget.storeId,
          ).where((item) => item.name.toLowerCase().contains(query)).toList();

    final suppliers = query.isEmpty
        ? <Supplier>[]
        : MockQueries.suppliersForStore(widget.storeId)
              .where(
                (supplier) =>
                    supplier.name.toLowerCase().contains(query) ||
                    supplier.contactName.toLowerCase().contains(query) ||
                    supplier.city.toLowerCase().contains(query),
              )
              .toList();

    final categories = query.isEmpty
        ? <Category>[]
        : MockQueries.categoriesForStore(widget.storeId)
              .where((category) => category.name.toLowerCase().contains(query))
              .toList();

    final total = items.length + suppliers.length + categories.length;

    return ShellPage(
      back: BackDestination(
        label: l10n.dashboardTitle,
        path: Routes.toDashboard(widget.storeId),
      ),
      title: l10n.searchTitle,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SearchField(
              hint: l10n.searchHint,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.searchResultCount(total),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          Expanded(
            child: query.isEmpty
                ? EmptyState(
                    icon: LucideIcons.search,
                    title: l10n.searchPrompt,
                    message: l10n.searchPromptBody,
                  )
                : total == 0
                ? EmptyState.noResults(l10n)
                : ListView(
                    children: [
                      if (items.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.searchSectionItems,
                          count: items.length,
                        ),
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _ItemResult(
                              item: item,
                              storeId: widget.storeId,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (suppliers.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.searchSectionSuppliers,
                          count: suppliers.length,
                        ),
                        for (final supplier in suppliers)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _SimpleResult(
                              icon: LucideIcons.truck,
                              title: supplier.name,
                              subtitle: _joinDot(
                                supplier.contactName,
                                supplier.city,
                              ),
                              onTap: () => context.pushScreen(
                                Routes.toSupplier(widget.storeId, supplier.id),
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (categories.isNotEmpty) ...[
                        SectionHeader(
                          title: l10n.searchSectionCategories,
                          count: categories.length,
                        ),
                        for (final category in categories)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _SimpleResult(
                              icon: LucideIcons.tag,
                              title: category.name,
                              subtitle: l10n.categoriesItemCount(
                                MockQueries.itemCountInCategory(category.id),
                              ),
                              onTap: () => context.goSection(
                                Routes.toCategories(widget.storeId),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Joins two facts with a middot separator.
String _joinDot(String a, String b) => '$a · $b';

/// An item result, carrying its stock status so search doubles as a way to
/// check "do we still have any?" without opening the article.
class _ItemResult extends StatelessWidget {
  const _ItemResult({required this.item, required this.storeId});

  final Item item;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = MockQueries.unitAbbreviationOf(item.unitId);

    return AppCard(
      onTap: () => context.pushScreen(Routes.toItem(storeId, item.id)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.boxes,
            size: AppSizing.iconMd,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _joinDot(
                    MockQueries.categoryNameOf(item.categoryId),
                    Formatters.quantityWithUnit(item.quantity, unit),
                  ),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StockStatusBadge(status: stockStatusOf(item)),
        ],
      ),
    );
  }
}

class _SimpleResult extends StatelessWidget {
  const _SimpleResult({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconMd, color: AppColors.textSecondary),
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
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconSm,
            color: AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}
