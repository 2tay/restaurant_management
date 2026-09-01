import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/view_models/view_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'movement_labels.dart';

/// One entry in the movement history.
class MovementRow extends StatelessWidget {
  const MovementRow({required this.view, this.storeId, this.onTap, super.key});

  final MovementRowView view;

  /// Needed to link back to the receipt. Omitted where the row is decorative.
  final String? storeId;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final movement = view.movement;
    final unit = view.unitAbbreviation;
    final isIncrease = movement.quantity > 0;

    final accent = switch (movement.type) {
      StockMovementType.stockIn => AppColors.inStock,
      StockMovementType.stockOut => AppColors.lowStock,
      StockMovementType.adjustment => AppColors.outOfStock,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              movementTypeIcon(movement.type),
              size: AppSizing.iconMd,
              color: accent.foreground,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.itemName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  movementDescription(
                    l10n,
                    movement,
                    view.supplierName ?? '—',
                    orderReference: view.orderReference,
                  ),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.dateTime(movement.occurredAt),
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  movement.userName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // What the stock that moved was worth.
          //
          // A delivery falls back to the price paid, which is the same figure;
          // everything else uses the cost recorded on the movement, so a line
          // of waste finally reads in euros as well as in kilos. Movements
          // seeded before costs existed carry neither and stay blank rather
          // than showing a zero that would read as free.
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _valueLabel(movement),
                style: AppTypography.numericSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          // Closes the trail in the other direction: from a quantity on the
          // shelf back to the delivery, the order, and the supplier.
          if (movement.receiptId != null && storeId != null) ...[
            IconButton(
              onPressed: () => context.pushScreen(
                Routes.toReceipt(storeId!, movement.receiptId!),
              ),
              tooltip: l10n.movementViewReceipt,
              icon: const Icon(LucideIcons.receiptText),
              color: AppColors.textSecondary,
              constraints: const BoxConstraints(
                minWidth: AppSizing.minTapTarget,
                minHeight: AppSizing.minTapTarget,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],

          const SizedBox(width: AppSpacing.md),

          SizedBox(
            width: 110,
            child: Text(
              Formatters.quantityDelta(movement.quantity, unit),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numeric.copyWith(
                fontWeight: FontWeight.w700,
                color: isIncrease
                    ? AppColors.inStock.foreground
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What the stock this movement moved was worth, or blank if unknown.
  ///
  /// [StockMovement.unitCost] is preferred over [StockMovement.unitPrice]
  /// because it is the figure that entered the stock and it is present on every
  /// kind of movement, not only on deliveries.
  static String _valueLabel(StockMovement movement) {
    final unitValue = movement.unitCost ?? movement.unitPrice;
    if (unitValue == null) return '';
    return Formatters.price(unitValue * movement.quantity.abs());
  }
}
