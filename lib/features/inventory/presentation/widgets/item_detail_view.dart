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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = asyncAll4(
      ref.watch(itemRowProvider(itemId)),
      ref.watch(itemPricingProvider(itemId)),
      ref.watch(movementRowsForItemProvider(itemId)),
      ref.watch(itemOnOrderProvider((storeId: storeId, itemId: itemId))),
      (row, pricing, movements, onOrder) => (
        row: row,
        pricing: pricing,
        movements: movements,
        onOrder: onOrder,
      ),
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
    final status = stockStatusOf(item);
    final prices = pricing.prices;
    final cheapest = pricing.cheapest;
    final defaultPrice = pricing.defaultPrice;
    final overpay = pricing.overpayPerUnit;
    final onOrder = onOrderData.quantity;
    final openOrders = onOrderData.orders;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (showTitle) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The photo, at the top of the pane, so the product being read
              // about is the product the user tapped and not a name that could
              // be any of forty.
              ProductImage(imagePath: item.imagePath, size: 64),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    StockStatusBadge(status: status),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: onClose,
                tooltip: l10n.actionClose,
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // The two things you came here to do, on the screen you are already
          // on. Editing used to mean leaving the split view for the full page,
          // which is the long way round to a form the pane could have opened.
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: l10n.actionEdit,
                  icon: LucideIcons.pencil,
                  onPressed: () => context.pushScreen(
                    Routes.toEditItem(storeId, item.id),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DestructiveButton(
                label: l10n.actionDelete,
                icon: LucideIcons.trash2,
                filled: false,
                onPressed: () async {
                  final deleted =
                      await confirmDeleteItem(context, ref, storeId, item);
                  // The pane was showing a product that is gone. Closing it is
                  // the only honest thing left to do.
                  if (deleted) onClose?.call();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // --- Facts -----------------------------------------------------------
        AppCard(
          child: Column(
            children: [
              _FactRow(
                label: l10n.itemOnHandLabel,
                value: Formatters.quantityWithUnit(item.quantity, unit),
                emphasis: true,
              ),
              // Only when something is actually coming. A permanent "En
              // commande : 0" row would be four words of noise on every item in
              // the catalogue.
              if (onOrder > 0) ...[
                const Divider(height: AppSpacing.xl),
                _FactRow(
                  label: l10n.itemOnOrderLabel,
                  value: Formatters.quantityWithUnit(onOrder, unit),
                ),
              ],
              const Divider(height: AppSpacing.xl),
              // Sits with the quantity rather than with the supplier prices
              // below, because it is a fact about the stock on hand — what it
              // cost — and not an offer from anybody. Seeing the two apart is
              // what stops them being read as the same number disagreeing with
              // itself.
              _FactRow(
                label: l10n.itemAverageCost,
                value: item.averageCost == null
                    ? l10n.itemAverageCostUnknown
                    : '${Formatters.price(item.averageCost!)} / $unit',
              ),
              const Divider(height: AppSpacing.xl),
              _FactRow(
                label: l10n.itemThresholdLabel,
                value: Formatters.quantityWithUnit(
                  item.lowStockThreshold,
                  unit,
                ),
              ),
              const Divider(height: AppSpacing.xl),
              _FactRow(
                label: l10n.itemCategoryLabel,
                value: row.categoryName,
              ),
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
        const SizedBox(height: AppSpacing.xl),

        // --- Open orders -----------------------------------------------------
        //
        // Present only when something is on its way. This is the answer to
        // "stock is low, has anybody done anything about it?", and it is the
        // question a manager asks right before ordering the same thing twice.
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

        // --- Recent movements ------------------------------------------------
        SectionHeader(
          title: l10n.itemMovementsTitle,
          trailing: TextButton(
            onPressed: () => context.goSection(
              Routes.toMovements(storeId, itemId: itemId),
            ),
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
                for (final movement in movements)
                  _MovementLine(view: movement),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
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

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

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
            style: emphasis
                ? AppTypography.numericMedium
                : theme.textTheme.bodyLarge,
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
    final isIncrease = movement.quantity > 0;

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
            isIncrease
                ? LucideIcons.arrowDownToLine
                : LucideIcons.arrowUpFromLine,
            size: AppSizing.iconMd,
            color: isIncrease
                ? AppColors.inStock.solid
                : AppColors.textSecondary,
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
              color: isIncrease
                  ? AppColors.inStock.foreground
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
