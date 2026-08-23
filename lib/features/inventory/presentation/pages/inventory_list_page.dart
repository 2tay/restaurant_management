import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/item_detail_view.dart';
import '../widgets/item_row.dart';

/// Local filter state for the inventory list.
///
/// Exactly the kind of trivial UI state Riverpod is permitted to hold in Phase
/// 1 — which chip is selected, what is typed in the search box. No repository,
/// no business logic.
class InventoryFilter {
  const InventoryFilter({
    this.query = '',
    this.categoryId,
    this.supplierId,
    this.lowStockOnly = false,
    this.selectedItemId,
  });

  final String query;
  final String? categoryId;
  final String? supplierId;
  final bool lowStockOnly;
  final String? selectedItemId;

  bool get hasActiveFilters =>
      query.isNotEmpty ||
      categoryId != null ||
      supplierId != null ||
      lowStockOnly;

  InventoryFilter copyWith({
    String? query,
    String? categoryId,
    String? supplierId,
    bool? lowStockOnly,
    String? selectedItemId,
    bool clearCategory = false,
    bool clearSupplier = false,
  }) {
    return InventoryFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      selectedItemId: selectedItemId ?? this.selectedItemId,
    );
  }
}

class InventoryFilterNotifier extends Notifier<InventoryFilter> {
  @override
  InventoryFilter build() => const InventoryFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void setCategory(String? id) => id == null
      ? state = state.copyWith(clearCategory: true)
      : state = state.copyWith(categoryId: id);

  void setSupplier(String? id) => id == null
      ? state = state.copyWith(clearSupplier: true)
      : state = state.copyWith(supplierId: id);

  void toggleLowStockOnly() =>
      state = state.copyWith(lowStockOnly: !state.lowStockOnly);

  void select(String itemId) => state = state.copyWith(selectedItemId: itemId);

  void clear() => state = InventoryFilter(selectedItemId: state.selectedItemId);
}

final inventoryFilterProvider =
    NotifierProvider<InventoryFilterNotifier, InventoryFilter>(
      InventoryFilterNotifier.new,
    );

/// The inventory list.
///
/// On a wide tablet this is a master–detail split: list on the left, the
/// selected item's detail on the right. Below the split breakpoint, tapping a
/// row pushes the detail as its own page instead. The brief asks for exactly
/// this — full-screen navigation for every tap wastes a tablet's width.
class InventoryListPage extends ConsumerWidget {
  const InventoryListPage({required this.storeId, super.key});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(inventoryFilterProvider);
    final items = _visibleItems(filter);
    final canSplit = context.canSplitView;

    final selected = _resolveSelection(items, filter, canSplit);

    return ShellPage(
      title: l10n.inventoryTitle,
      scrollable: false,
      actions: [
        PrimaryButton(
          label: l10n.actionAddItem,
          icon: LucideIcons.plus,
          onPressed: () => context.go(Routes.toAddItem(storeId)),
        ),
      ],
      child: canSplit
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _ListPane(storeId: storeId, items: items),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 4,
                  child: selected == null
                      ? _NoSelection(l10n: l10n)
                      : ItemDetailView(item: selected, storeId: storeId),
                ),
              ],
            )
          : _ListPane(storeId: storeId, items: items),
    );
  }

  /// Keeps the detail pane populated rather than blank on first load — a split
  /// view whose right half is empty looks broken.
  Item? _resolveSelection(
    List<Item> items,
    InventoryFilter filter,
    bool canSplit,
  ) {
    if (!canSplit || items.isEmpty) return null;
    if (filter.selectedItemId == null) return items.first;

    for (final item in items) {
      if (item.id == filter.selectedItemId) return item;
    }
    // The selected item was filtered out; fall back rather than showing nothing.
    return items.first;
  }

  List<Item> _visibleItems(InventoryFilter filter) {
    final query = filter.query.trim().toLowerCase();

    final items = MockQueries.itemsForStore(storeId).where((item) {
      if (query.isNotEmpty && !item.name.toLowerCase().contains(query)) {
        return false;
      }
      if (filter.categoryId != null && item.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.supplierId != null) {
        final suppliesIt = MockQueries.pricesForItem(
          item.id,
        ).any((price) => price.supplierId == filter.supplierId);
        if (!suppliesIt) return false;
      }
      if (filter.lowStockOnly && !needsAttention(item)) return false;
      return true;
    }).toList();

    // Worst status first, then alphabetical — what needs attention floats up.
    items.sort((a, b) {
      final byStatus = _rank(a).compareTo(_rank(b));
      return byStatus != 0 ? byStatus : a.name.compareTo(b.name);
    });
    return items;
  }

  int _rank(Item item) => switch (stockStatusOf(item)) {
    StockStatus.outOfStock => 0,
    StockStatus.lowStock => 1,
    StockStatus.inStock => 2,
  };
}

class _ListPane extends ConsumerWidget {
  const _ListPane({required this.storeId, required this.items});

  final String storeId;
  final List<Item> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(inventoryFilterProvider);
    final notifier = ref.read(inventoryFilterProvider.notifier);
    final canSplit = context.canSplitView;

    final categories = MockQueries.categoriesForStore(storeId);
    final suppliers = MockQueries.suppliersForStore(storeId);
    final storeHasItems = MockQueries.itemsForStore(storeId).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchField(
          hint: l10n.inventorySearchHint,
          initialValue: filter.query,
          onChanged: notifier.setQuery,
        ),
        const SizedBox(height: AppSpacing.md),

        // Filters wrap rather than scroll: a hidden filter is a filter nobody
        // uses, and French category names are long.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FilterMenu(
              label: l10n.inventoryFilterCategory,
              allLabel: l10n.inventoryFilterAll,
              selectedId: filter.categoryId,
              options: {for (final c in categories) c.id: c.name},
              onSelected: notifier.setCategory,
            ),
            _FilterMenu(
              label: l10n.inventoryFilterSupplier,
              allLabel: l10n.inventoryFilterAllSuppliers,
              selectedId: filter.supplierId,
              options: {for (final s in suppliers) s.id: s.name},
              onSelected: notifier.setSupplier,
            ),
            FilterChip(
              label: Text(l10n.inventoryFilterLowOnly),
              avatar: Icon(
                LucideIcons.triangleAlert,
                size: 16,
                color: filter.lowStockOnly
                    ? AppColors.lowStock.foreground
                    : AppColors.textSecondary,
              ),
              selected: filter.lowStockOnly,
              onSelected: (_) => notifier.toggleLowStockOnly(),
              selectedColor: AppColors.lowStock.container,
              checkmarkColor: AppColors.lowStock.foreground,
            ),
            if (filter.hasActiveFilters)
              TextButton.icon(
                onPressed: notifier.clear,
                icon: const Icon(LucideIcons.x, size: 16),
                label: Text(l10n.inventoryClearFilters),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.inventoryCount(items.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),

        Expanded(
          child: items.isEmpty
              ? _EmptyList(
                  storeId: storeId,
                  storeHasItems: storeHasItems,
                  onClearFilters: notifier.clear,
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ItemRow(
                      item: item,
                      selected: canSplit && filter.selectedItemId == item.id,
                      onTap: () {
                        if (canSplit) {
                          notifier.select(item.id);
                        } else {
                          context.go(Routes.toItem(storeId, item.id));
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Distinguishes "this store has nothing yet" from "your filters matched
/// nothing". They need different words and a different button.
class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.storeId,
    required this.storeHasItems,
    required this.onClearFilters,
  });

  final String storeId;
  final bool storeHasItems;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (storeHasItems) {
      return EmptyState.noResults(
        l10n,
        onClearFilters: onClearFilters,
        clearLabel: l10n.inventoryClearFilters,
      );
    }

    return EmptyState(
      icon: LucideIcons.packageOpen,
      title: l10n.emptyStateNoItemsTitle,
      message: l10n.emptyStateNoItemsBody,
      actionLabel: l10n.actionAddItem,
      actionIcon: LucideIcons.plus,
      onAction: () => context.go(Routes.toAddItem(storeId)),
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: EmptyState(
        icon: LucideIcons.mousePointerClick,
        title: l10n.inventorySelectPrompt,
        message: l10n.inventorySelectPromptBody,
      ),
    );
  }
}

/// A dropdown filter rendered as a chip.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.allLabel,
    required this.selectedId,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String allLabel;
  final String? selectedId;
  final Map<String, String> options;
  final ValueChanged<String?> onSelected;

  static const String _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    final selectedLabel = selectedId == null ? null : options[selectedId];

    return PopupMenuButton<String>(
      tooltip: label,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (value) => onSelected(value == _allValue ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(value: _allValue, child: Text(allLabel)),
        const PopupMenuDivider(),
        for (final entry in options.entries)
          PopupMenuItem<String>(value: entry.key, child: Text(entry.value)),
      ],
      child: Container(
        height: AppSizing.minTapTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selectedLabel == null
              ? AppColors.surface
              : AppColors.primaryContainer,
          borderRadius: AppRadius.pillAll,
          border: Border.all(
            color: selectedLabel == null
                ? AppColors.border
                : AppColors.primary600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                selectedLabel ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selectedLabel == null
                      ? AppColors.textSecondary
                      : AppColors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              LucideIcons.chevronDown,
              size: AppSizing.iconSm,
              color: selectedLabel == null
                  ? AppColors.textSecondary
                  : AppColors.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
