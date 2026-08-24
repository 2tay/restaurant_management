import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../mock_data/mock_data.dart';

/// "This is already on its way."
///
/// Shown wherever an item appears that has outstanding quantity on another open
/// order. It exists to stop the most expensive mistake this app can fail to
/// prevent: a manager orders 20 kg on Monday, looks at the stock level on
/// Wednesday, sees it is still low — because the van has not arrived — and
/// orders 20 kg again.
///
/// Renders nothing when there is nothing on order, so call sites can drop it in
/// without guarding first.
class AlreadyOnOrderBadge extends StatelessWidget {
  const AlreadyOnOrderBadge({
    required this.storeId,
    required this.itemId,
    required this.unitAbbreviation,
    super.key,
  });

  final String storeId;
  final String itemId;
  final String unitAbbreviation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quantity = MockQueries.onOrderQuantity(storeId, itemId);
    if (quantity <= 0) return const SizedBox.shrink();

    final orders = MockQueries.openOrdersForItem(storeId, itemId);
    final formatted = Formatters.quantityWithUnit(quantity, unitAbbreviation);

    return Tooltip(
      message: l10n.orderAlreadyOnOrderDetail(formatted, orders.length),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          color: AppColors.offlineContainer,
          borderRadius: AppRadius.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.truck,
              size: AppSizing.iconSm,
              color: AppColors.steel800,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                l10n.orderAlreadyOnOrder(formatted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.steel800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
