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
class ItemDetailView extends ConsumerWidget {
  const ItemDetailView({
    required this.itemId,
    required this.storeId,
    this.showTitle = true,
    this.onClose,
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

  /// True in the drawer, which is its own scrolling box. False on the
  /// product page, which scrolls as a whole — its title and buttons going up
  /// with the content rather than staying pinned above it.
  final bool scrollsItself;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = asyncAll4(
      ref.watch(itemRowProvider(itemId)),
      ref.watch(itemPricingProvider(itemId)),
      ref.watch(movementRowsForItemProvider(itemId)),
      ref.watch(itemOnOrderProvider((storeId: storeId, itemId: itemId))),
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
        ref.invalidate(itemRowProvider(itemId));
        ref.invalidate(itemPricingProvider(itemId));
        ref.invalidate(movementRowsForItemProvider(itemId));
        ref.invalidate(itemOnOrderProvider((storeId: storeId, itemId: itemId)));
      },
      builder: (context, data) {
        final row = data.row;
        // Deleted while somebody was looking at it. Rendering nothing is right
        // here: the page around this already shows the error and the way back.
        if (row == null) return const SizedBox.shrink();

        return _body(
          context,
          ref,
          row,
          data.pricing,
          data.movements,
          data.onOrder,
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ItemRowView row,
    ItemPricing pricing,
    List<MovementRowView> movements,
    ItemOnOrder onOrderData,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = row.item;
    final unit = row.unitAbbreviation;
    final prices = pricing.prices;
    final cheapest = pricing.cheapest;
    final defaultPrice = pricing.defaultPrice;
    final overpay = pricing.overpayPerUnit;
    final onOrder = onOrderData.quantity;
    final openOrders = onOrderData.orders;

    final content = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: !scrollsItself,
      primary: scrollsItself ? null : false,
      physics: scrollsItself ? null : const NeverScrollableScrollPhysics(),
      children: [
        // --- The figures ------------------------------------------------------
        //
        // The three numbers somebody opens a product to check: how much is
        // there, what it is worth, and whether anything is coming. They were
        // spread down an eight-row fact table that gave the category and the
        // last-updated date exactly as much weight.
        //
        // The photo rides here on the *page*, whose own header carries the name
        // but no picture. In the panel it is up in the bar that stays put, so
        // it is not drawn twice.
        _StatsCard(row: row, onOrder: onOrder, showPhoto: !showTitle),
        const SizedBox(height: AppSpacing.lg),

        // --- Suppliers and prices --------------------------------------------
        //
        // The heart of the screen. Not a single "cost" field, because a cost
        // field would be a lie about how this restaurant actually buys.
        SectionHeader(
          title: l10n.itemSuppliersTitle,
          subtitle: l10n.itemSuppliersSubtitle,
          count: prices.isEmpty ? null : prices.length,
          trailing: SecondaryButton(
            label: l10n.itemLinkSupplier,
            icon: LucideIcons.plus,
            onPressed: () =>
                context.pushScreen(Routes.toLinkSupplier(storeId, item.id)),
          ),
        ),

        if (overpay > 0 && defaultPrice != null && cheapest != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _OverpayNotice(
              amount: Formatters.price(overpay),
              unit: unit,
              cheapestSupplier: cheapest.supplierName,
            ),
          ),

        if (prices.isEmpty)
          AppCard(
            child: EmptyState(
              icon: LucideIcons.truck,
              title: l10n.itemNoSuppliersTitle,
              message: l10n.itemNoSuppliersBody,
              actionLabel: l10n.itemLinkSupplier,
              actionIcon: LucideIcons.plus,
              onAction: () =>
                  context.pushScreen(Routes.toLinkSupplier(storeId, item.id)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final entry in prices)
                  SupplierPriceRow(
                    view: entry,
                    unitAbbreviation: unit,
                    isCheapest:
                        prices.length > 1 &&
                        entry.price.id == cheapest?.price.id,
                    onViewHistory: () => context.pushScreen(
                      Routes.toPriceHistory(
                        storeId,
                        item.id,
                        entry.price.supplierId,
                      ),
                    ),
                    onRemove: () =>
                        _confirmRemoveSupplier(context, ref, pricing, entry),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),

        // --- Open orders -----------------------------------------------------
        //
        // Present only when something is on its way. This is the answer to
        // "stock is low, has anybody done anything about it?", and it is the
        // question a manager asks right before ordering the same thing twice.
        //
        // It sits under the suppliers rather than above them: both are about
        // buying, and the prices are what a decision is made from while this is
        // what has already been decided.
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
                    storeId: storeId,
                    unitAbbreviation: unit,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // --- Recent movements ------------------------------------------------
        SectionHeader(
          title: l10n.itemMovementsTitle,
          trailing: TextButton(
            onPressed: () =>
                context.goSection(Routes.toMovements(storeId, itemId: itemId)),
            child: Text(l10n.actionViewAll),
          ),
        ),
        if (movements.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.itemNoMovements,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final movement in movements) _MovementLine(view: movement),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),

        // --- Details ---------------------------------------------------------
        //
        // Reference, and last. Every one of these was a row in the fact table
        // at the top, weighted the same as the quantity on hand — which is the
        // one number the screen exists to show. They are worth having and not
        // worth reading first.
        SectionHeader(
          title: l10n.itemDetailsTitle,
          subtitle: l10n.itemDetailsSubtitle,
        ),
        AppCard(
          child: Column(
            children: [
              _FactRow(
                label: l10n.itemStockRangeLabel,
                value:
                    '${Formatters.quantity(item.lowStockThreshold)} / '
                    '${Formatters.quantityWithUnit(item.maxStock, unit)}',
              ),
              const Divider(height: AppSpacing.xl),
              _FactRow(
                label: l10n.itemAverageCost,
                value: item.averageCost == null
                    ? l10n.itemAverageCostUnknown
                    : '${Formatters.price(item.averageCost!)} / $unit',
              ),
              const Divider(height: AppSpacing.xl),
              _FactRow(label: l10n.itemCategoryLabel, value: row.categoryName),
              const Divider(height: AppSpacing.xl),
              _FactRow(label: l10n.itemUnitLabel, value: unit),
              const Divider(height: AppSpacing.xl),
              _FactRow(
                label: l10n.itemUpdatedLabel,
                value: Formatters.relative(item.updatedAt),
              ),
              // Shown only when the item has one. A dash-filled "Code-barres :
              // —" row on the thirty items that will never have a barcode
              // would make the absence look like missing data rather than a
              // fact about produce.
              if (item.barcode != null) ...[
                const Divider(height: AppSpacing.xl),
                _BarcodeRow(barcode: item.barcode!),
              ],
              if (item.note != null) ...[
                const Divider(height: AppSpacing.xl),
                _FactRow(label: l10n.itemNoteLabel, value: item.note!),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );

    // The page scrolls as a whole — its title and buttons go up with the
    // content — so there is nothing to pin and the caller owns the scrolling.
    if (!showTitle) return content;

    // The panel is its own scrolling box, and a 560dp column holding the
    // figures, the suppliers, the open commandes, the movements and the details
    // is a long one. Which product you are reading, and the way out, must not
    // scroll away from you halfway down it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IdentityBar(row: row, storeId: storeId, onClose: onClose),
        const Divider(height: AppSpacing.lg, color: AppColors.hairline),
        Expanded(child: content),
      ],
    );
  }

  Future<void> _confirmRemoveSupplier(
    BuildContext context,
    WidgetRef ref,
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

/// The overpaying callout.
///
/// The single most valuable thing this app can tell a restaurant owner, so it
/// is stated in euros per unit and names the cheaper supplier rather than
/// leaving them to work it out from the table below.
class _OverpayNotice extends StatelessWidget {
  const _OverpayNotice({
    required this.amount,
    required this.unit,
    required this.cheapestSupplier,
  });

  final String amount;
  final String unit;
  final String cheapestSupplier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lowStock.container,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.trendingUp,
            color: AppColors.lowStock.foreground,
            size: AppSizing.iconLg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.itemOverpayWarning(amount, unit, cheapestSupplier),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.lowStock.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The barcode, in a monospaced style and copyable.
///
/// Tabular figures rather than the body font: a barcode is read one digit at a
/// time, usually while comparing it against something printed, and proportional
/// digits make that harder than it needs to be. Tapping copies it, which is the
/// only thing anybody ever wants to do with one on screen.
class _BarcodeRow extends StatelessWidget {
  const _BarcodeRow({required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: barcode));
        if (context.mounted) {
          AppSnackBar.success(context, l10n.itemBarcodeCopied);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              l10n.itemBarcodeShortLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    barcode,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.numeric.copyWith(letterSpacing: 1),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: l10n.itemBarcodeCopyTooltip,
                  child: const Icon(
                    LucideIcons.copy,
                    size: AppSizing.iconSm,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final order = view.order;
    final outstanding = view.outstandingForItem;

    return InkWell(
      onTap: () => context.pushScreen(Routes.toOrder(storeId, order.id)),
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
                    '${order.reference} · ${l10n.orderSentOn(Formatters.date(order.sentAt ?? order.createdAt))}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              Formatters.quantityWithUnit(outstanding, unitAbbreviation),
              style: AppTypography.numeric,
            ),
            const SizedBox(width: AppSpacing.md),
            OrderStatusBadge(status: order.status, compact: true),
          ],
        ),
      ),
    );
  }
}

/// Who this is and the way out, pinned above the panel's scrolling body.
///
/// Photo, name, status, and the three things that act on the product: edit,
/// delete, close. Edit and delete were a full-width button row inside the
/// scroll, which cost a line of a narrow panel and scrolled out of reach
/// exactly when a long product page made them hardest to get back to. As icons
/// on the bar they are always there and take no room of their own.
class _IdentityBar extends ConsumerWidget {
  const _IdentityBar({
    required this.row,
    required this.storeId,
    this.onClose,
  });

  final ItemRowView row;
  final String storeId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = row.item;

    return Row(
      children: [
        ProductImage(imagePath: item.imagePath, size: 48, radius: 10),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                row.categoryName,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: () =>
              context.pushScreen(Routes.toEditItem(storeId, item.id)),
          tooltip: l10n.actionEdit,
          icon: const Icon(LucideIcons.pencil, size: AppSizing.iconMd),
        ),
        IconButton(
          onPressed: () async {
            final deleted = await confirmDeleteItem(context, ref, storeId, item);
            // The panel was showing a product that is gone. Closing it is the
            // only honest thing left to do.
            if (deleted) onClose?.call();
          },
          tooltip: l10n.actionDelete,
          color: AppColors.error,
          icon: const Icon(LucideIcons.trash2, size: AppSizing.iconMd),
        ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            tooltip: l10n.actionClose,
            icon: const Icon(LucideIcons.x, size: AppSizing.iconMd),
          ),
      ],
    );
  }
}

/// The three figures, and the gauge across the full width under them.
///
/// The gauge used to sit inside the first figure's column, so it was as wide as
/// the words "50 kg" — a bar too short to read a proportion off. It spans the
/// card now, which is the only width at which a proportion is worth drawing.
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.row,
    required this.onOrder,
    required this.showPhoto,
  });

  final ItemRowView row;
  final double onOrder;

  /// True on the page, whose own header names the product but shows no picture.
  /// False in the panel, where the bar above already has one.
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = row.item;
    final unit = row.unitAbbreviation;

    final figures = <Widget>[
      _Figure(
        // "Quantité", not "En stock": the status badge a few pixels away says
        // "En stock" and means something else entirely.
        label: l10n.itemQuantityLabel,
        value: Formatters.quantityWithUnit(item.quantity, unit),
        emphasis: true,
      ),
      _Figure(
        label: l10n.itemStockValueLabel,
        // No average cost means no value can be worked out. A zero here would
        // be a claim about the stock rather than an absence of information.
        value: item.averageCost == null
            ? l10n.itemStockValueUnknown
            : Formatters.price(item.quantity * item.averageCost!),
        emphasis: item.averageCost != null,
      ),
      // Only when something is actually coming. A permanent "En commande : 0"
      // would be a column of noise on every product in the catalogue.
      if (onOrder > 0)
        _Figure(
          label: l10n.itemOnOrderLabel,
          value: Formatters.quantityWithUnit(onOrder, unit),
          emphasis: true,
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPhoto) ...[
                ProductImage(imagePath: item.imagePath, size: 72),
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Three figures need about 110dp each before the numbers
                    // start wrapping under their own labels. Below that they
                    // stack two-up instead of being squeezed.
                    final perFigure = constraints.maxWidth / figures.length;
                    if (perFigure >= 110) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final figure in figures)
                            Expanded(child: figure),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.md,
                      children: figures,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          StockGauge(
            quantity: item.quantity,
            minimum: item.lowStockThreshold,
            maximum: item.maxStock,
            height: 8,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  // Named bounds, not "8 / 20": that shape directly under a
                  // filled bar reads as "8 out of 20", which is the current
                  // level — and the figure above already said it.
                  l10n.itemRangeInline(
                    Formatters.quantityWithUnit(item.lowStockThreshold, unit),
                    Formatters.quantityWithUnit(item.maxStock, unit),
                  ),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // What a commande would put on the line, stated rather than
              // offered: ordering happens on the Achats screens, and this is
              // the figure that says whether it is worth going there.
              if (item.quantity < item.maxStock) ...[
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    l10n.itemTopUpSuggestion(
                      Formatters.quantityWithUnit(topUpQuantity(item), unit),
                    ),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One figure in the header: a quiet label with the number under it.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Numeric type for a figure, ordinary body type for a phrase like
  /// "Coût inconnu", which in numeric type reads as a broken number.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      // Wide enough for a five-figure price, narrow enough that three fit
      // across a split pane before the Wrap breaks them onto two lines.
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: emphasis
                ? AppTypography.numericMedium
                : theme.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _MovementLine extends StatelessWidget {
  const _MovementLine({required this.view});

  final MovementRowView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movement = view.movement;
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
          Icon(
            movementTypeIcon(movement.type),
            size: AppSizing.iconMd,
            color: movementColors(movement.type).solid,
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
                  style: theme.textTheme.bodyLarge,
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
            ),
          ),
        ],
      ),
    );
  }
}
