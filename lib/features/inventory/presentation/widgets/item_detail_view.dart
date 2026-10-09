import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../data/providers.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../orders/presentation/widgets/order_status_badge.dart';
import '../../../stock_movement/presentation/widgets/movement_labels.dart';
import 'delete_item.dart';
import 'supplier_price_row.dart';
import '../../../orders/presentation/widgets/order_detail_view.dart';

/// The body of the item detail screen.
///
/// Extracted from the page so the inventory list can embed it in a split view
/// on a wide tablet, and push it as a full page on a narrow one, without the
/// content being written twice.
///
/// Takes an **id**, not an article. It used to take the object, because the
/// list that embedded it already had one; now it watches four queries of its
/// own, and taking the id is what lets it keep showing the right thing when a
/// delivery lands underneath it while somebody is looking at the screen.
///
/// The four are combined into one decision rather than rendered separately.
/// Four `.when`s would give four skeletons resolving at four different moments,
/// which reads as a page assembling itself rather than a page loading.
///
/// **One stock card, then three tabs.** The card answers what a product is
/// opened for — how much, how full, what is coming — and stays above the tabs.
/// Everything else was six sections stacked down one scroll, the suppliers
/// last; split into Aperçu / Fournisseurs / Historique, no tab is longer than
/// a phone screen.
class ItemDetailView extends ConsumerStatefulWidget {
  const ItemDetailView({
    required this.itemId,
    required this.storeId,
    this.showTitle = true,
    this.onClose,
    this.panel,
    this.scrollsItself = true,
    super.key,
  });

  final String itemId;
  final String storeId;

  /// False when the surrounding page already shows the item name in its header.
  ///
  /// It also decides who owns the actions. The page puts "Modifier" and
  /// "Supprimer" in its own header, so the body must not repeat them; the
  /// split pane has no header of its own, and without these it was a detail
  /// view with no way to act on what it was showing — the product could only
  /// be edited by leaving the screen it was open on.
  final bool showTitle;

  /// Closes the pane. Null when the view is the whole page, which closes by
  /// going back.
  final VoidCallback? onClose;

  /// The panel this is inside, when it is inside one. Only used to know
  /// whether the panel has somewhere to go back to — a product reached from a
  /// commande's lines — which is what decides between a back arrow and none.
  final PanelController? panel;

  /// True in the drawer, which is its own scrolling box. False on the
  /// product page, which scrolls as a whole — its title and buttons going up
  /// with the content rather than staying pinned above it.
  final bool scrollsItself;

  @override
  ConsumerState<ItemDetailView> createState() => _ItemDetailViewState();
}

const _tabOverview = 'overview';
const _tabSuppliers = 'suppliers';
const _tabHistory = 'history';

class _ItemDetailViewState extends ConsumerState<ItemDetailView> {
  String _tab = _tabOverview;

  String get _itemId => widget.itemId;
  String get _storeId => widget.storeId;

  @override
  Widget build(BuildContext context) {
    final data = asyncAll4(
      ref.watch(itemRowProvider(_itemId)),
      ref.watch(itemPricingProvider(_itemId)),
      ref.watch(movementRowsForItemProvider(_itemId)),
      ref.watch(itemOnOrderProvider((storeId: _storeId, itemId: _itemId))),
      (row, pricing, movements, onOrder) =>
          (row: row, pricing: pricing, movements: movements, onOrder: onOrder),
    );

    return AsyncContent<
      ({
        ItemRowView? row,
        ItemPricing pricing,
        List<MovementRowView> movements,
        ItemOnOrder onOrder,
      })
    >(
      value: data,
      skeleton: const SkeletonList(rows: 4, rowHeight: 120),
      onRetry: () {
        ref.invalidate(itemRowProvider(_itemId));
        ref.invalidate(itemPricingProvider(_itemId));
        ref.invalidate(movementRowsForItemProvider(_itemId));
        ref.invalidate(
          itemOnOrderProvider((storeId: _storeId, itemId: _itemId)),
        );
      },
      builder: (context, data) {
        final row = data.row;
        // Deleted while somebody was looking at it. Rendering nothing is right
        // here: the page around this already shows the error and the way back.
        if (row == null) return const SizedBox.shrink();

        return _body(context, row, data.pricing, data.movements, data.onOrder);
      },
    );
  }

  Widget _body(
    BuildContext context,
    ItemRowView row,
    ItemPricing pricing,
    List<MovementRowView> movements,
    ItemOnOrder onOrderData,
  ) {
    final l10n = AppLocalizations.of(context);
    final prices = pricing.prices;

    final tabBody = switch (_tab) {
      _tabSuppliers => _suppliersTab(context, row, pricing),
      _tabHistory => _historyTab(context, movements),
      _ => _overviewTab(row, onOrderData),
    };

    final tabs = _DetailTabs(
      current: _tab,
      onSelected: (tab) => setState(() => _tab = tab),
      tabs: [
        (id: _tabOverview, label: l10n.itemTabOverview, count: null),
        (
          id: _tabSuppliers,
          label: l10n.itemTabSuppliers,
          count: prices.isEmpty ? null : prices.length,
        ),
        (id: _tabHistory, label: l10n.itemTabHistory, count: null),
      ],
    );

    // In the panel the stock card belongs to the Détail tab — the tabs sit
    // right under the product's name, as in a phone's own app sheets. On the
    // page it stays above them, carrying the photo the page header lacks.
    final stockCard = _StockCard(
      row: row,
      onOrder: onOrderData.quantity,
      showPhoto: !widget.showTitle,
      // The page header already carries the badge.
      showStatus: widget.showTitle,
    );

    final content = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: !widget.scrollsItself,
      primary: widget.scrollsItself ? null : false,
      physics: widget.scrollsItself
          ? null
          : const NeverScrollableScrollPhysics(),
      children: [
        if (!widget.showTitle) ...[
          stockCard,
          const SizedBox(height: AppSpacing.lg),
          tabs,
        ] else if (_tab == _tabOverview) ...[
          stockCard,
          const SizedBox(height: AppSpacing.md),
        ],
        if (!widget.showTitle) const SizedBox(height: AppSpacing.lg),
        ...tabBody,
        const SizedBox(height: AppSpacing.xxl),
      ],
    );

    // The page scrolls as a whole — its title and buttons go up with the
    // content — so there is nothing to pin and the caller owns the scrolling.
    if (!widget.showTitle) return content;

    // Which product you are reading, the tabs, and what acts on it must not
    // scroll away from you halfway down a long tab.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IdentityBar(row: row, onClose: widget.onClose, panel: widget.panel),
        const SizedBox(height: AppSpacing.md),
        tabs,
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: content),
        _ActionFooter(row: row, storeId: _storeId, onClose: widget.onClose),
      ],
    );
  }

  /// What is on its way, then the reference facts.
  ///
  /// Open commandes come first and only when there are any: they answer
  /// "stock is low, has anybody done anything about it?" — the question asked
  /// right before ordering the same thing twice.
  List<Widget> _overviewTab(ItemRowView row, ItemOnOrder onOrderData) {
    final l10n = AppLocalizations.of(context);
    final item = row.item;
    final openOrders = onOrderData.orders;

    return [
      if (openOrders.isNotEmpty) ...[
        SectionHeader(
          title: l10n.itemOpenOrdersTitle,
          count: openOrders.length,
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final view in openOrders)
                _OpenOrderLine(
                  view: view,
                  storeId: _storeId,
                  unitAbbreviation: row.unitAbbreviation,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      _FactGrid(row: row),
      if (item.note != null) ...[
        const SizedBox(height: AppSpacing.md),
        _NoteBlock(note: item.note!),
      ],
    ];
  }

  /// The heart of the screen. Not a single "cost" field, because a cost field
  /// would be a lie about how this restaurant actually buys.
  List<Widget> _suppliersTab(
    BuildContext context,
    ItemRowView row,
    ItemPricing pricing,
  ) {
    final l10n = AppLocalizations.of(context);
    final item = row.item;
    final prices = pricing.prices;
    final cheapest = pricing.cheapest;

    void link() => context.pushScreen(Routes.toLinkSupplier(_storeId, item.id));

    if (prices.isEmpty) {
      return [
        AppCard(
          child: EmptyState(
            icon: LucideIcons.truck,
            title: l10n.itemNoSuppliersTitle,
            message: l10n.itemNoSuppliersBody,
            actionLabel: l10n.itemLinkSupplier,
            actionIcon: LucideIcons.plus,
            onAction: link,
          ),
        ),
      ];
    }

    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, entry) in prices.indexed)
              SupplierPriceRow(
                view: entry,
                unitAbbreviation: row.unitAbbreviation,
                isCheapest:
                    prices.length > 1 && entry.price.id == cheapest?.price.id,
                showDivider: index < prices.length - 1,
                onViewHistory: () => context.pushScreen(
                  Routes.toPriceHistory(
                    _storeId,
                    item.id,
                    entry.price.supplierId,
                  ),
                ),
                onRemove: () => _confirmRemoveSupplier(context, pricing, entry),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: link,
          icon: const Icon(LucideIcons.plus, size: AppSizing.iconSm),
          label: Text(l10n.itemLinkSupplier),
        ),
      ),
    ];
  }

  List<Widget> _historyTab(
    BuildContext context,
    List<MovementRowView> movements,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (movements.isEmpty) {
      return [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l10n.itemNoMovements,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, movement) in movements.indexed)
              _MovementLine(
                view: movement,
                showDivider: index < movements.length - 1,
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          onPressed: () =>
              context.goSection(Routes.toMovements(_storeId, itemId: _itemId)),
          child: Text(l10n.actionViewAll),
        ),
      ),
    ];
  }

  Future<void> _confirmRemoveSupplier(
    BuildContext context,
    ItemPricing pricing,
    SupplierPriceView entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final price = entry.price;

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: entry.supplierName,
      extraWarning: l10n.itemRemoveSupplierWarning,
    );

    if (!confirmed || !context.mounted) return;

    // Removing the default promotes the next cheapest supplier, so the item
    // does not silently lose its price auto-fill everywhere. Working out which
    // one before the removal, so it can be named — and from the list already on
    // screen, which is cheapest-first for exactly this reason.
    SupplierPriceView? promoted;
    if (price.isDefault) {
      for (final candidate in pricing.prices) {
        if (candidate.price.id != price.id) {
          promoted = candidate;
          break;
        }
      }
    }

    await ref.read(supplierRepositoryProvider).unlinkItem(price.id);

    if (!context.mounted) return;
    AppSnackBar.success(context, l10n.itemSupplierRemoved);

    // Said out loud rather than left to be discovered: the default changing is
    // a consequence the user did not ask for and would otherwise only notice
    // the next time a form filled itself in with a different number.
    if (promoted != null) {
      AppSnackBar.warning(
        context,
        l10n.supplierPromotedToDefault(promoted.supplierName),
      );
    }
  }
}

typedef _TabSpec = ({String id, String label, int? count});

/// Détail / Fournisseurs / Historique as an underlined tab bar.
///
/// Each tab takes a third of the width and keeps its word — three icons
/// alone are a guessing game. The selected one is in the brand green with a
/// bar under it, sitting on a hairline that runs the full width.
class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.tabs,
    required this.current,
    required this.onSelected,
  });

  final List<_TabSpec> tabs;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: _DetailTab(
                tab: tab,
                selected: tab.id == current,
                onTap: () => onSelected(tab.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailTab extends StatelessWidget {
  const _DetailTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColors.primary700 : AppColors.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: selected ? null : onTap,
        child: SizedBox(
          height: AppSizing.minTapTarget,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected
                              ? AppColors.primary700
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (tab.count != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryContainer
                              : AppColors.surfaceVariant,
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: Text(
                          '${tab.count}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: 0,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary600 : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who this is and the way out, pinned above the panel's scrolling body.
///
/// Photo, name and category, read at a glance. Editing and deleting moved to
/// the footer; what stays here is the way out — a back arrow once the panel
/// has walked forward, and a close button on a tablet. A phone's bottom sheet
/// has its handle for that, and a cross beside it would be a second way to do
/// the same thing.
class _IdentityBar extends StatelessWidget {
  const _IdentityBar({required this.row, this.onClose, this.panel});

  final ItemRowView row;
  final VoidCallback? onClose;
  final PanelController? panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = row.item;

    final canGoBack = panel?.canGoBack ?? false;
    final isSheet = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return Row(
      children: [
        // Only once the panel has walked forward — a product opened from a
        // commande's lines. It sits before the photo, where a back control is
        // looked for.
        if (canGoBack) ...[
          IconButton(
            onPressed: panel!.back,
            tooltip: l10n.actionBack,
            icon: const Icon(LucideIcons.arrowLeft, size: AppSizing.iconMd),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        ProductImage(imagePath: item.imagePath, size: 56, radius: 12),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  const Icon(
                    LucideIcons.leaf,
                    size: 14,
                    color: AppColors.primary600,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      row.categoryName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onClose != null && !isSheet)
          IconButton(
            onPressed: onClose,
            tooltip: l10n.actionClose,
            icon: const Icon(LucideIcons.x, size: AppSizing.iconMd),
          ),
      ],
    );
  }
}

/// Modifier and Supprimer, side by side and pinned under the scrolling body.
///
/// Two halves of the width, the edit filled in green and the delete only
/// outlined in red — far enough apart, and different enough, that one is not
/// pressed for the other. Supprimer still asks before it deletes.
class _ActionFooter extends ConsumerWidget {
  const _ActionFooter({required this.row, required this.storeId, this.onClose});

  final ItemRowView row;
  final String storeId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final item = row.item;
    const buttonSize = Size.fromHeight(48);
    const shape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    context.pushScreen(Routes.toEditItem(storeId, item.id)),
                style: FilledButton.styleFrom(
                  minimumSize: buttonSize,
                  shape: shape,
                ),
                icon: const Icon(LucideIcons.pencil, size: AppSizing.iconSm),
                label: Text(
                  l10n.actionEdit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final deleted = await confirmDeleteItem(
                    context,
                    ref,
                    storeId,
                    item,
                  );
                  // The panel was showing a product that is gone. Closing it
                  // is the only honest thing left to do.
                  if (deleted) onClose?.call();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: buttonSize,
                  shape: shape,
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                icon: const Icon(LucideIcons.trash2, size: AppSizing.iconSm),
                label: Text(
                  l10n.actionDelete,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The figure a product is opened for, how full the shelf is, and what is
/// worth knowing next to it.
///
/// The quantity is the one large number. The range is two short labels under
/// the ends of the gauge, not a sentence; value, what is on its way and what a
/// refill would take are chips, each present only when it has something to
/// say — a permanent "0 en route" would be noise on every product.
class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.row,
    required this.onOrder,
    required this.showPhoto,
    required this.showStatus,
  });

  final ItemRowView row;
  final double onOrder;
  final bool showPhoto;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = row.item;
    final unit = row.unitAbbreviation;
    final caption = theme.textTheme.labelMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    final chips = <Widget>[
      // No average cost means no value can be worked out; no chip rather than
      // a zero, which would be a claim about the stock.
      if (item.averageCost != null)
        _MetricChip(
          icon: LucideIcons.wallet,
          value: Formatters.price(item.quantity * item.averageCost!),
          caption: l10n.itemChipValue,
          tooltip: l10n.itemStockValueLabel,
        ),
      if (onOrder > 0)
        _MetricChip(
          icon: LucideIcons.truck,
          value: Formatters.quantityWithUnit(onOrder, unit),
          caption: l10n.itemChipOnOrder,
          tooltip: l10n.itemOnOrderLabel,
          highlighted: true,
        ),
      if (item.quantity < item.maxStock)
        _MetricChip(
          icon: LucideIcons.arrowUpToLine,
          value: Formatters.quantityWithUnit(topUpQuantity(item), unit),
          caption: l10n.itemChipTopUp,
          tooltip: l10n.itemTopUpTooltip,
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showPhoto) ...[
                ProductImage(imagePath: item.imagePath, size: 56),
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: Semantics(
                  label:
                      '${l10n.itemQuantityLabel} '
                      '${Formatters.quantityWithUnit(item.quantity, unit)}',
                  excludeSemantics: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: Formatters.quantity(item.quantity),
                          style: AppTypography.numericLarge,
                        ),
                        TextSpan(
                          text: ' $unit',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (showStatus) ...[
                const SizedBox(width: AppSpacing.sm),
                StockStatusBadge(status: stockStatusOf(item)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StockGauge(
            quantity: item.quantity,
            minimum: item.lowStockThreshold,
            maximum: item.maxStock,
            height: 10,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                l10n.itemGaugeMin(
                  Formatters.quantityWithUnit(item.lowStockThreshold, unit),
                ),
                style: caption,
              ),
              const Spacer(),
              Text(
                l10n.itemGaugeMax(
                  Formatters.quantityWithUnit(item.maxStock, unit),
                ),
                style: caption,
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }
}

/// A figure with a one-word caption — "186,00 € valeur" — in a soft pill. The
/// full label is the tooltip and what a screen reader hears.
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.value,
    required this.caption,
    required this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final String value;
  final String caption;
  final String tooltip;

  /// Tinted, for the figure that changes what to do next — stock on its way.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = highlighted
        ? AppColors.onPrimaryContainer
        : AppColors.textPrimary;
    final muted = highlighted
        ? AppColors.onPrimaryContainer
        : AppColors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: '$tooltip $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primaryContainer
                : AppColors.surfaceVariant,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSizing.iconSm - 2, color: muted),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: ' $caption',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference facts as small tiles — two across in a phone-width panel,
/// four across where there is room — instead of a label/value table whose
/// rows all weighed the same as the quantity.
///
/// Category and range are not here: the header and the stock card already
/// show them.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.row});

  final ItemRowView row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = row.item;
    final unit = row.unitAbbreviation;

    final tiles = <Widget>[
      _FactTile(icon: LucideIcons.box, label: l10n.itemUnitLabel, value: unit),
      _FactTile(
        icon: LucideIcons.coins,
        label: l10n.itemAverageCost,
        value: item.averageCost == null
            ? l10n.itemAverageCostUnknown
            : '${Formatters.price(item.averageCost!)} / $unit',
      ),
      _FactTile(
        icon: LucideIcons.clock,
        label: l10n.itemUpdatedLabel,
        value: Formatters.relative(item.updatedAt),
      ),
      // Only when the item has one. A dash on the thirty items that will
      // never have a barcode would make the absence look like missing data
      // rather than a fact about produce.
      if (item.barcode != null) _BarcodeTile(barcode: item.barcode!),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        // A tile left alone on the last row of two takes the whole row
        // rather than leaving a hole beside it.
        final lastAlone = columns == 2 && tiles.length.isOdd;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (index, tile) in tiles.indexed)
              SizedBox(
                width: lastAlone && index == tiles.length - 1
                    ? constraints.maxWidth
                    : width,
                child: tile,
              ),
          ],
        );
      },
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: AppSizing.iconMd,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value,
                      style:
                          valueStyle ??
                          theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The barcode, in tabular figures and copyable.
///
/// A barcode is read one digit at a time, usually while comparing it against
/// something printed, and proportional digits make that harder than it needs
/// to be. Tapping copies it, which is the only thing anybody ever wants to do
/// with one on screen.
class _BarcodeTile extends StatelessWidget {
  const _BarcodeTile({required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Tooltip(
      message: l10n.itemBarcodeCopyTooltip,
      child: _FactTile(
        icon: LucideIcons.scanBarcode,
        label: l10n.itemBarcodeShortLabel,
        value: barcode,
        valueStyle: AppTypography.numeric.copyWith(
          fontSize: 15,
          letterSpacing: 0.5,
        ),
        trailing: const Icon(
          LucideIcons.copy,
          size: 14,
          color: AppColors.textDisabled,
        ),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: barcode));
          if (context.mounted) {
            AppSnackBar.success(context, l10n.itemBarcodeCopied);
          }
        },
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      label: l10n.itemNoteLabel,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              LucideIcons.stickyNote,
              size: AppSizing.iconSm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(note, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// One open commande carrying this item, with what is still outstanding on it.
class _OpenOrderLine extends StatelessWidget {
  const _OpenOrderLine({
    required this.view,
    required this.storeId,
    required this.unitAbbreviation,
  });

  final OrderRowView view;
  final String storeId;
  final String unitAbbreviation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = view.order;

    return InkWell(
      // Walks the panel forward when this product is itself in one, and opens
      // a panel over the page when it is not.
      onTap: () => openOrderPanel(context, storeId: storeId, orderId: order.id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.supplierName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    order.reference,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '+${Formatters.quantityWithUnit(view.outstandingForItem, unitAbbreviation)}',
              style: AppTypography.numeric,
            ),
            const SizedBox(width: AppSpacing.sm),
            OrderStatusBadge(status: order.status, compact: true),
          ],
        ),
      ),
    );
  }
}

class _MovementLine extends StatelessWidget {
  const _MovementLine({required this.view, required this.showDivider});

  final MovementRowView view;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movement = view.movement;
    final colors = movementColors(movement.type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.hairline))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              movementTypeIcon(movement.type),
              size: AppSizing.iconSm - 2,
              color: colors.solid,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movementDescription(
                    AppLocalizations.of(context),
                    movement,
                    view.supplierName ?? '—',
                    orderReference: view.orderReference,
                    unit: view.unitAbbreviation,
                  ),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${Formatters.relative(movement.occurredAt)} · ${movement.userName}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            Formatters.quantityDelta(movement.quantity, view.unitAbbreviation),
            style: AppTypography.numeric.copyWith(
              color: quantityDeltaColor(movement.quantity),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
