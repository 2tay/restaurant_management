import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/routes.dart';
import '../../../../app/navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/stock_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../stock_movement/presentation/widgets/movement_labels.dart';
import 'supplier_price_row.dart';

/// The body of the item detail screen.
///
/// Extracted from the page so the inventory list can embed it in a split view
/// on a wide tablet, and push it as a full page on a narrow one, without the
/// content being written twice.
class ItemDetailView extends StatelessWidget {
  const ItemDetailView({
    required this.item,
    required this.storeId,
    this.showTitle = true,
    super.key,
  });

  final Item item;
  final String storeId;

  /// False when the surrounding page already shows the item name in its header.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final status = stockStatusOf(item);
    final unit = MockQueries.unitAbbreviationOf(item.unitId);
    final prices = MockQueries.pricesForItem(item.id);
    final cheapest = MockQueries.cheapestPriceForItem(item.id);
    final defaultPrice = MockQueries.defaultPriceForItem(item.id);
    final overpay = MockQueries.overpayPerUnit(item.id);
    final movements = MockQueries.movementsForItem(item.id).take(6).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (showTitle) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.name, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(width: AppSpacing.md),
              StockStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // --- Facts -----------------------------------------------------------
        AppCard(
          child: Column(
            children: [
              _FactRow(
                label: l10n.itemQuantityLabel,
                value: Formatters.quantityWithUnit(item.quantity, unit),
                emphasis: true,
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
                value: MockQueries.categoryNameOf(item.categoryId),
              ),
              const Divider(height: AppSpacing.xl),
              _FactRow(
                label: l10n.itemUpdatedLabel,
                value: Formatters.relative(item.updatedAt),
              ),
              if (item.note != null) ...[
                const Divider(height: AppSpacing.xl),
                _FactRow(label: l10n.itemNoteLabel, value: item.note!),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

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
              cheapestSupplier: MockQueries.supplierNameOf(cheapest.supplierId),
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
                for (final price in prices)
                  SupplierPriceRow(
                    price: price,
                    unitAbbreviation: unit,
                    isCheapest: prices.length > 1 && price.id == cheapest?.id,
                    onViewHistory: () => context.pushScreen(
                      Routes.toPriceHistory(storeId, item.id, price.supplierId),
                    ),
                    onRemove: () => _confirmRemoveSupplier(context, price),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),

        // --- Recent movements ------------------------------------------------
        SectionHeader(
          title: l10n.itemMovementsTitle,
          trailing: TextButton(
            onPressed: () => context.goSection(Routes.toMovements(storeId)),
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
                  _MovementLine(movement: movement, unitAbbreviation: unit),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Future<void> _confirmRemoveSupplier(
    BuildContext context,
    SupplierPrice price,
  ) async {
    final l10n = AppLocalizations.of(context);
    final supplierName = MockQueries.supplierNameOf(price.supplierId);

    final confirmed = await ConfirmDialog.confirmDelete(
      context,
      name: supplierName,
      extraWarning: l10n.itemRemoveSupplierWarning,
    );

    if (confirmed && context.mounted) {
      // Phase 1 changes no data — the confirmation is what is being designed
      // here, not the mutation.
      AppSnackBar.success(context, l10n.itemSupplierRemoved);
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
                ? AppTypography.numeric.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _MovementLine extends StatelessWidget {
  const _MovementLine({required this.movement, required this.unitAbbreviation});

  final StockMovement movement;
  final String unitAbbreviation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    MockQueries.supplierNameOf(movement.supplierId),
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
            Formatters.quantityDelta(movement.quantity, unitAbbreviation),
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
