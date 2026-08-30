import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/item_search.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Search across items, suppliers and categories for the current store.
///
/// Filters the static mock data client-side, which is all Phase 1 needs and
/// what Phase 2 will keep doing for anything already cached locally.
///
/// Results are grouped by kind rather than merged into one ranked list. Someone
/// typing "poulet" wants either the article or a supplier of it, and a blended
/// list makes them read every row to find out which is which.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();

    // Results cover articles, suppliers and categories — all three are
    // creatable and deletable, and all three queries watch their own tables.
    //
    // The matching stays in Dart. It is the same predicate the inventory list
    // uses, for the reason written down in `item_search.dart`: SQLite folds
    // case for ASCII only, so a `LIKE` here would stop finding "Épicerie".
    final allItems =
        ref.watch(itemRowsProvider((
              storeId: widget.storeId,
              filter: ItemFilter.none,
            ))).value ??
        const <ItemRowView>[];
    final allSuppliers =
        ref.watch(supplierRowsProvider(widget.storeId)).value ??
        const <SupplierRowView>[];
    final allCategories =
        ref.watch(categoryRowsProvider(widget.storeId)).value ??
        const <CategoryRowView>[];

    // Matches on name or on an exact barcode — pasting a scanned code into the
    // box finds the article.
    final items = query.isEmpty
        ? const <ItemRowView>[]
        : [
            for (final row in allItems)
              if (itemMatchesSearch(row.item, query)) row,
          ];

    final suppliers = query.isEmpty
        ? const <SupplierRowView>[]
        : [
            for (final row in allSuppliers)
              if (row.supplier.name.toLowerCase().contains(query) ||
                  row.supplier.contactName.toLowerCase().contains(query) ||
                  row.supplier.city.toLowerCase().contains(query))
                row,
          ];

    final categories = query.isEmpty
        ? const <CategoryRowView>[]
        : [
            for (final row in allCategories)
              if (row.category.name.toLowerCase().contains(query)) row,
          ];

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
                              view: item,
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
                              title: supplier.supplier.name,
                              subtitle: _joinDot(
                                supplier.supplier.contactName,
                                supplier.supplier.city,
                              ),
                              onTap: () => context.pushScreen(
                                Routes.toSupplier(
                                  widget.storeId,
                                  supplier.supplier.id,
                                ),
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
                              title: category.category.name,
                              subtitle: l10n.categoriesItemCount(
                                category.itemCount,
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
  const _ItemResult({required this.view, required this.storeId});

  final ItemRowView view;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = view.item;
    final unit = view.unitAbbreviation;

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
                    view.categoryName,
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
