import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import 'movement_labels.dart';

/// One entry in the movement history.
class MovementRow extends StatelessWidget {
  const MovementRow({required this.movement, this.onTap, super.key});

  final StockMovement movement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final item = MockQueries.itemById(movement.itemId);
    final unit = item == null
        ? ''
        : MockQueries.unitAbbreviationOf(item.unitId);
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
                  item?.name ?? '—',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  movementDescription(
                    l10n,
                    movement,
                    MockQueries.supplierNameOf(movement.supplierId),
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

          // Deliveries carry what they cost; nothing else has a price.
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                movement.unitPrice == null
                    ? ''
                    : Formatters.price(
                        movement.unitPrice! * movement.quantity.abs(),
                      ),
                style: AppTypography.numericSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
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
}
