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
import '../widgets/item_card.dart';
import '../widgets/item_list_row.dart';

/// How the visible products are ordered.
///
/// [status] is the order the query itself returns — worst stock status first,
/// then alphabetical — and it is the default because it is the order that
/// answers the question the screen is usually open for: what needs dealing
/// with. The rest are applied in Dart over the rows already fetched, so
/// changing the order costs no round trip and cannot change *which* products
/// are listed.
enum ItemSort {
  status,
  recent,
  nameAsc,
  nameDesc,
  stockAsc,
  stockDesc;

  String label(AppLocalizations l10n) => switch (this) {
    ItemSort.status => l10n.inventorySortStatus,
    ItemSort.recent => l10n.inventorySortRecent,
    ItemSort.nameAsc => l10n.inventorySortNameAsc,
    ItemSort.nameDesc => l10n.inventorySortNameDesc,
    ItemSort.stockAsc => l10n.inventorySortStockAsc,
    ItemSort.stockDesc => l10n.inventorySortStockDesc,
  };
}

/// Cards or rows.
///
/// Two ways of reading the same list: the grid for finding a product you would
/// recognise by sight, the list for comparing quantities down a column. The
/// choice is per session — it lives in a provider rather than in a widget's
/// state so it survives opening a product and coming back, and it is not
/// written to disk because the app has no preferences store to write it to.
enum InventoryViewMode { grid, list }

class InventoryViewModeNotifier extends Notifier<InventoryViewMode> {
  @override
  InventoryViewMode build() => InventoryViewMode.grid;

  void select(InventoryViewMode mode) => state = mode;
}

final inventoryViewModeProvider =
    NotifierProvider<InventoryViewModeNotifier, InventoryViewMode>(
      InventoryViewModeNotifier.new,
    );

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
    this.sort = ItemSort.status,
  });

  final String query;
  final String? categoryId;
  final String? supplierId;
  final bool lowStockOnly;
  final String? selectedItemId;

  /// Not part of [hasActiveFilters], and deliberately: an order is not a
  /// filter. "Effacer les filtres" brings the hidden products back; it does not
  /// also undo the ordering the user chose to read them in.
  final ItemSort sort;

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
    ItemSort? sort,
    bool clearCategory = false,
    bool clearSupplier = false,
    bool clearSelection = false,
  }) {
    return InventoryFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      supplierId: clearSupplier ? null : supplierId ?? this.supplierId,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      selectedItemId:
          clearSelection ? null : selectedItemId ?? this.selectedItemId,
      sort: sort ?? this.sort,
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

  void setSort(ItemSort value) => state = state.copyWith(sort: value);

  void toggleLowStockOnly() =>
      state = state.copyWith(lowStockOnly: !state.lowStockOnly);

  void select(String itemId) => state = state.copyWith(selectedItemId: itemId);

  /// Closes the detail pane. The filters are left exactly as they were — the
  /// user shut one product, they did not ask to see the whole catalogue again.
  void clearSelection() => state = state.copyWith(clearSelection: true);

  void clear() => state = InventoryFilter(
    selectedItemId: state.selectedItemId,
    sort: state.sort,
  );
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
          shortLabel: l10n.shortAddItem,
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
          final visible = _sorted([
            for (final row in allRows)
              if (itemMatchesSearch(row.item, query)) row,
          ], filter.sort);
          final selected = _resolveSelection(visible, filter, canSplit);

          if (!canSplit || selected == null) {
            return _ListPane(storeId: storeId, rows: visible);
          }

          // The detail pane exists only once a product has been chosen, and
          // the grid keeps the whole width until then. A permanently reserved
          // half-screen holding "Sélectionnez un produit" spends the most
          // valuable space on the page saying nothing, and shrinks the grid
          // that is the point of the screen.
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
                child: ItemDetailView(
                  itemId: selected.item.id,
                  storeId: storeId,
                  onClose: () => afterFrame(
                    ref.read(inventoryFilterProvider.notifier).clearSelection,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The product whose detail is open, or null for none.
  ///
  /// Nothing is selected until somebody selects something. This used to open
  /// on the first row so the pane was never blank, which meant the screen
  /// arrived having already made a choice on the user's behalf and put one
  /// arbitrary product's detail — and its delete button — in front of them.
  ///
  /// A selection filtered out of the list closes the pane rather than sliding
  /// to a neighbour: the product the user was reading is not on screen any
  /// more, and quietly swapping in a different one is how somebody edits the
  /// wrong thing.
  ItemRowView? _resolveSelection(
    List<ItemRowView> rows,
    InventoryFilter filter,
    bool canSplit,
  ) {
    if (!canSplit || filter.selectedItemId == null) return null;

    for (final row in rows) {
      if (row.item.id == filter.selectedItemId) return row;
    }
    return null;
  }
}

class _ListPane extends ConsumerWidget {
  const _ListPane({required this.storeId, required this.rows});

  final String storeId;
  final List<ItemRowView> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inventoryFilterProvider);
    final notifier = ref.read(inventoryFilterProvider.notifier);
    final canSplit = context.canSplitView;

    // The two filter menus. Empty while their queries are out, which draws
    // each menu with only its "toutes" entry — briefly, and better than a menu
    // that grows a frame after somebody has reached for it.
    final categories = ref.watch(categoriesProvider(storeId)).value ?? const [];
    final suppliers = ref.watch(suppliersProvider(storeId)).value ?? const [];
    final viewMode = ref.watch(inventoryViewModeProvider);
    final onTap = _open(context, ref);
    final selectedId = canSplit ? filter.selectedItemId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search, filters, the result count and the display controls are one
        // bar rather than three stacked rows. As three, they cost 373dp on a
        // 360dp phone and 260 on the 1280dp design baseline — before a single
        // product. The screen is the products.
        _ListControls(
          filter: filter,
          notifier: notifier,
          count: rows.length,
          categories: {for (final c in categories) c.id: c.name},
          suppliers: {for (final s in suppliers) s.id: s.name},
          viewMode: viewMode,
          onViewMode: ref.read(inventoryViewModeProvider.notifier).select,
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
              : viewMode == InventoryViewMode.grid
              ? _ProductGrid(rows: rows, onTap: onTap, selectedId: selectedId)
              : _ProductList(rows: rows, onTap: onTap, selectedId: selectedId),
        ),
      ],
    );
  }

  /// What tapping a product does.
  ///
  /// On a wide screen it fills the detail pane beside the list; below the split
  /// breakpoint there is no pane, so it pushes the product's own page. Both
  /// views, and the arrow on every card, go through this one callback, so they
  /// cannot drift apart.
  ValueChanged<String> _open(BuildContext context, WidgetRef ref) {
    final canSplit = context.canSplitView;
    final notifier = ref.read(inventoryFilterProvider.notifier);

    return (itemId) {
      if (canSplit) {
        notifier.select(itemId);
      } else {
        context.pushScreen(Routes.toItem(storeId, itemId));
      }
    };
  }
}

/// Everything between the page header and the products: the search box, the
/// filters, how many matched, and how the list is shown.
///
/// One bar, not three rows. Search had its own line, the count had another and
/// the filters a third, which on a phone stacked into 373dp of controls above a
/// 320dp card — the screen showed two thirds of one product. They are all the
/// same kind of thing (narrow the list down) and they belong on the same line
/// wherever the line has room.
///
/// Ordering and view mode stay on the right, so they keep reading as "how this
/// list is shown" rather than joining the filters — until the pane is too
/// narrow for two sides, where they drop under and stay right-aligned.
class _ListControls extends StatelessWidget {
  const _ListControls({
    required this.filter,
    required this.notifier,
    required this.count,
    required this.categories,
    required this.suppliers,
    required this.viewMode,
    required this.onViewMode,
  });

  final InventoryFilter filter;
  final InventoryFilterNotifier notifier;

  /// How many products matched — the answer to whatever was just typed or
  /// picked, so it sits with the controls that asked the question.
  final int count;

  final Map<String, String> categories;
  final Map<String, String> suppliers;
  final InventoryViewMode viewMode;
  final ValueChanged<InventoryViewMode> onViewMode;

  /// Under this the two groups stop fitting on one line together. It is the
  /// pane's width, not the screen's: this list is half the window with a
  /// product open and all of it without.
  static const double _twoSided = 860;

  /// The search box inside the bar. Narrower than the 420dp it gets on its own
  /// line — it is sharing now, and a product name is a short query.
  static const double _searchWidth = 300;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Filters wrap rather than scroll: a hidden filter is a filter nobody
    // uses, and French category names are long.
    final filters = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // A stated width, not a cap. `SearchField` fills whatever box it is
        // given, and a `Wrap` gives its children the whole line to ask for —
        // so an uncapped one took a run to itself and pushed all four filters
        // onto lines of their own.
        SizedBox(
          width: _searchWidth,
          child: SearchField(
            hint: l10n.inventorySearchHint,
            initialValue: filter.query,
            onChanged: notifier.setQuery,
          ),
        ),
        _FilterMenu(
          label: l10n.inventoryFilterCategory,
          allLabel: l10n.inventoryFilterAll,
          selectedId: filter.categoryId,
          options: categories,
          onSelected: notifier.setCategory,
        ),
        _FilterMenu(
          label: l10n.inventoryFilterSupplier,
          allLabel: l10n.inventoryFilterAllSuppliers,
          selectedId: filter.supplierId,
          options: suppliers,
          onSelected: notifier.setSupplier,
        ),
        // A pill rather than a Material `FilterChip`: the chip drew itself
        // 385dp wide for a three-word label, next to two 180dp pills saying
        // the same kind of thing. Same control, same shape as its neighbours,
        // half the width — and the roster's "afficher les retirés" toggle is
        // built exactly this way, so the two now match.
        Material(
          color: Colors.transparent,
          borderRadius: AppRadius.pillAll,
          child: InkWell(
            onTap: notifier.toggleLowStockOnly,
            borderRadius: AppRadius.pillAll,
            child: FilterPill(
              label: l10n.inventoryFilterLowOnly,
              selectedLabel: filter.lowStockOnly
                  ? l10n.inventoryFilterLowOnly
                  : null,
              icon: LucideIcons.triangleAlert,
            ),
          ),
        ),
        if (filter.hasActiveFilters)
          TextButton.icon(
            onPressed: notifier.clear,
            icon: const Icon(LucideIcons.x, size: 16),
            label: Text(l10n.inventoryClearFilters),
          ),
        Text(
          l10n.inventoryCount(count),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    // Wrapped rather than a Row: on a phone the sort pill and the toggle do
    // not fit side by side, and a Row would overflow instead of stacking.
    final display = Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SortMenu(sort: filter.sort, onSelected: notifier.setSort),
        _ViewModeToggle(mode: viewMode, onSelected: onViewMode),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _twoSided) {
          return Row(
            children: [
              Expanded(child: filters),
              const SizedBox(width: AppSpacing.lg),
              display,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            filters,
            const SizedBox(height: AppSpacing.sm),
            display,
          ],
        );
      },
    );
  }
}

/// The products as cards.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.rows,
    required this.onTap,
    required this.selectedId,
  });

  final List<ItemRowView> rows;
  final ValueChanged<String> onTap;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    // A grid rather than a list, because the photo is what makes a catalogue
    // scannable without reading it. The column count comes from the available
    // width rather than from a breakpoint: this pane is half the screen with a
    // product open and all of it without, and a fixed count would leave cards
    // stretched across one and crushed in the other.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = inventoryGridColumns(constraints.maxWidth);

        // The tile's height is stated, not derived from a ratio.
        //
        // `childAspectRatio` sets the height from the width, which means the
        // space left for the card's text varies with the column count — and on
        // a narrow pane it went negative, collapsing the picture to nothing.
        // Here the picture's height is computed from the column width and then
        // bounded, the text block is a known height, and the tile is exactly
        // the two added up, so neither can squeeze the other however the grid
        // is sized.
        //
        // The tile is the card's *outer* height, so it carries the border too.
        // `AppCard` draws one inside its own box and lays the card out in what
        // is left, which is two pixels less than the tile — the amount every
        // card in this grid was overflowing by before the allowance was added.
        final spacing = AppSpacing.md * (columns - 1);
        final cellWidth = (constraints.maxWidth - spacing) / columns;
        final imageHeight = inventoryImageHeight(cellWidth);

        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent:
                imageHeight +
                itemCardTextHeightFor(context) +
                AppCard.verticalBorderAllowance,
          ),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return ItemCard(
              view: row,
              imageHeight: imageHeight,
              selected: selectedId == row.item.id,
              onTap: () => onTap(row.item.id),
            );
          },
        );
      },
    );
  }
}

/// The products as compact rows.
///
/// Everything the card carries, on one line: thumbnail, name, category,
/// status, quantity, and the same arrow. For the user who knows what they are
/// looking for and wants twenty products on screen rather than six.
class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.rows,
    required this.onTap,
    required this.selectedId,
  });

  final List<ItemRowView> rows;
  final ValueChanged<String> onTap;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final row = rows[index];
        return ItemListRow(
          view: row,
          selected: selectedId == row.item.id,
          onTap: () => onTap(row.item.id),
        );
      },
    );
  }
}

/// The chip-shaped trigger for the ordering menu.
///
/// The pill only tints once the order is *not* the default one, which is the
/// rule the filter pills follow too: a highlighted control means "this is why
/// the list does not look the way you expect".
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSelected});

  final ItemSort sort;
  final ValueChanged<ItemSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = sort.label(l10n);

    final menu = PopupMenuButton<ItemSort>(
      tooltip: l10n.inventorySortLabel,
      initialValue: sort,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in ItemSort.values)
          PopupMenuItem<ItemSort>(
            value: option,
            child: Text(option.label(l10n)),
          ),
      ],
      child: FilterPill(
        label: label,
        selectedLabel: sort == ItemSort.status ? null : label,
        icon: LucideIcons.arrowUpDown,
      ),
    );

    // No "Trier par" caption beside it. The pill carries the sort icon and the
    // current ordering, which says the same thing in a third of the width —
    // and the caption was 90dp of a control bar that had none to spare. It
    // survives as the menu's tooltip.
    return LayoutBuilder(
      builder: (context, constraints) {
        // [FilterPill] only shrinks against a bounded width, which is also
        // what [Flexible] needs.
        return constraints.maxWidth.isFinite
            ? Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: menu)])
            : menu;
      },
    );
  }
}

/// Cards or rows, as a two-button segmented control.
class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onSelected});

  final InventoryViewMode mode;
  final ValueChanged<InventoryViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      height: AppSizing.minTapTarget,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            icon: LucideIcons.layoutGrid,
            label: l10n.inventoryViewGrid,
            selected: mode == InventoryViewMode.grid,
            onTap: () => onSelected(InventoryViewMode.grid),
          ),
          _ViewModeButton(
            icon: LucideIcons.list,
            label: l10n.inventoryViewList,
            selected: mode == InventoryViewMode.list,
            onTap: () => onSelected(InventoryViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillAll,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.standard,
            // Square at the tap-target floor, even though the icon inside is
            // small: this is a control for a wet finger on a tablet.
            width: AppSizing.minTapTarget,
            height: AppSizing.minTapTarget,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryContainer : Colors.transparent,
              borderRadius: AppRadius.pillAll,
            ),
            child: Icon(
              icon,
              size: AppSizing.iconMd,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rows in the order the user asked for.
///
/// [ItemSort.status] returns the list untouched: that *is* the query's own
/// `ORDER BY`, and re-sorting it here would only risk disagreeing with it. The
/// others copy before sorting, because the list handed in belongs to the
/// provider and sorting it in place would mutate cached state.
List<ItemRowView> _sorted(List<ItemRowView> rows, ItemSort sort) {
  if (sort == ItemSort.status) return rows;

  final sorted = [...rows];
  switch (sort) {
    case ItemSort.status:
      break;
    case ItemSort.recent:
      sorted.sort((a, b) => b.item.updatedAt.compareTo(a.item.updatedAt));
    case ItemSort.nameAsc:
      sorted.sort(_byName);
    case ItemSort.nameDesc:
      sorted.sort((a, b) => _byName(b, a));
    case ItemSort.stockAsc:
      sorted.sort((a, b) => a.item.quantity.compareTo(b.item.quantity));
    case ItemSort.stockDesc:
      sorted.sort((a, b) => b.item.quantity.compareTo(a.item.quantity));
  }
  return sorted;
}

/// Case-insensitive, so "Tomates" and "tomates" land next to each other rather
/// than in two alphabets.
int _byName(ItemRowView a, ItemRowView b) =>
    a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());

/// Closes the detail pane one frame after the tap that asked for it.
///
/// The close button removes *itself* from the tree: shutting the pane disposes
/// the `MouseRegion` the pointer is inside while the mouse tracker is still
/// dispatching that very click. Deferring by a frame keeps the removal out of
/// the tracker's own update, and costs the user nothing they can perceive.
void afterFrame(VoidCallback change) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => change());

/// How many cards fit, given the width the grid actually has.
///
/// Around 260 logical pixels per card: narrower and the French product names
/// ellipsize into uselessness, wider and a full-width grid on a large tablet
/// draws four enormous photographs. Capped at four for the same reason.
///
/// The one column below [_singleColumn] is the phone case. Two cards across a
/// 380-pixel screen leaves 180 pixels for a name, a category and a quantity,
/// which is not enough for any of them; one full-width card per row is.
int inventoryGridColumns(double width) {
  if (width < _singleColumn) return 1;
  final columns = (width / _columnTarget).floor();
  return columns.clamp(2, 5);
}

/// Roughly how wide a card wants to be.
///
/// 230dp rather than the 260 it started at, and the ceiling is five columns
/// rather than four. Both spend the same currency: a 1280dp window drew three
/// cards across at 309dp each, which is a large photograph of a bag of flour
/// and six products on screen. At 230 it draws four, and a 1600dp desktop five.
const double _columnTarget = 230;

/// Below this width the grid drops to a single column.
const double _singleColumn = 440;

/// How tall the picture on a card is, for a column this wide.
///
/// Three fifths of the column's width, which keeps the picture a little over
/// half the card once [itemCardTextHeight] is added under it. Bounded at both
/// ends: a single-column phone layout would otherwise draw a poster, and a
/// five-column pane on a small tablet a postage stamp.
///
/// The ratio was three quarters and the ceiling 240, which is where most of a
/// 376dp card came from. A product photograph is there to be recognised at a
/// glance, not studied — 190dp is plenty for that, and the difference is a
/// phone showing three cards instead of one.
double inventoryImageHeight(double cellWidth) =>
    (cellWidth * 0.6).clamp(110, 190);

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
