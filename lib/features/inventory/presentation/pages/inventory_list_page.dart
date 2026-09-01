import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/item_search.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/item_detail_view.dart';
import '../widgets/item_row.dart';

/// Local filter state for the inventory list.
///
/// Which chip is selected, what is typed in the search box, which row is
/// showing on the right. No repository and no business logic: the parts of this
/// that the database can answer become an [ItemFilter] and go into the query,
/// while the search text and the selection stay here, because neither is a
/// question about the data.
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

  /// The part of this the database can answer.
  ///
  /// The search text is deliberately not in it: `itemMatchesSearch` explains
  /// why it stays a Dart predicate. Everything else is a `WHERE` clause.
  ItemFilter get itemFilter => ItemFilter(
    categoryId: categoryId,
    supplierId: supplierId,
    lowStockOnly: lowStockOnly,
  );

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

    // Receiving a delivery changes quantities under this screen. The query
    // re-runs itself when the table changes, so this redraws without being
    // told to. The ordering — worst status first, then alphabetical — is that
    // query's ORDER BY rather than a sort here.
    final filter = ref.watch(inventoryFilterProvider);
    final rows = ref.watch(
      itemRowsProvider((storeId: storeId, filter: filter.itemFilter)),
    );
    final canSplit = context.canSplitView;

    return ShellPage(
      title: l10n.inventoryTitle,
      scrollable: false,
      actions: [
        PrimaryButton(
          label: l10n.actionAddItem,
          icon: LucideIcons.plus,
          onPressed: () => context.pushScreen(Routes.toAddItem(storeId)),
        ),
      ],
      child: AsyncContent<List<ItemRowView>>(
        value: rows,
        onRetry: () => ref.invalidate(
          itemRowsProvider((storeId: storeId, filter: filter.itemFilter)),
        ),
        builder: (context, allRows) {
          // The search box is applied here rather than in SQL, for the reasons
          // written down in `item_search.dart`.
          final query = filter.query.trim().toLowerCase();
          final visible = [
            for (final row in allRows)
              if (itemMatchesSearch(row.item, query)) row,
          ];
          final selected = _resolveSelection(visible, filter, canSplit);

          if (!canSplit) return _ListPane(storeId: storeId, rows: visible);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _ListPane(storeId: storeId, rows: visible),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                flex: 4,
                child: selected == null
                    ? _NoSelection(l10n: l10n)
                    : ItemDetailView(
                        itemId: selected.item.id,
                        storeId: storeId,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Keeps the detail pane populated rather than blank on first load — a split
  /// view whose right half is empty looks broken.
  ItemRowView? _resolveSelection(
    List<ItemRowView> rows,
    InventoryFilter filter,
    bool canSplit,
  ) {
    if (!canSplit || rows.isEmpty) return null;
    if (filter.selectedItemId == null) return rows.first;

    for (final row in rows) {
      if (row.item.id == filter.selectedItemId) return row;
    }
    // The selected item was filtered out; fall back rather than showing nothing.
    return rows.first;
  }
}

class _ListPane extends ConsumerWidget {
  const _ListPane({required this.storeId, required this.rows});

  final String storeId;
  final List<ItemRowView> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(inventoryFilterProvider);
    final notifier = ref.read(inventoryFilterProvider.notifier);
    final canSplit = context.canSplitView;

    // The two filter menus. Empty while their queries are out, which draws
    // each menu with only its "toutes" entry — briefly, and better than a menu
    // that grows a frame after somebody has reached for it.
    final categories = ref.watch(categoriesProvider(storeId)).value ?? const [];
    final suppliers = ref.watch(suppliersProvider(storeId)).value ?? const [];

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
          l10n.inventoryCount(rows.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),

        Expanded(
          child: rows.isEmpty
              ? _EmptyList(
                  storeId: storeId,
                  // With no filter active, an empty result means the
                  // establishment is empty. With one active it means the
                  // filter matched nothing. Two different sentences and two
                  // different buttons, and this is the whole difference
                  // between them.
                  storeHasItems: filter.hasActiveFilters,
                  onClearFilters: notifier.clear,
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final item = row.item;
                    return ItemRow(
                      view: row,
                      selected: canSplit && filter.selectedItemId == item.id,
                      onTap: () {
                        if (canSplit) {
                          notifier.select(item.id);
                        } else {
                          context.pushScreen(Routes.toItem(storeId, item.id));
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
      onAction: () => context.pushScreen(Routes.toAddItem(storeId)),
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
      child: FilterPill(label: label, selectedLabel: selectedLabel),
    );
  }
}
