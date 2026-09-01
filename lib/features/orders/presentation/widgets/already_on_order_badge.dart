import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';

/// "This is already on its way."
///
/// Shown wherever an item appears that has outstanding quantity on another open
/// order. It exists to stop the most expensive mistake this app can fail to
/// prevent: a manager orders 20 kg on Monday, looks at the stock level on
/// Wednesday, sees it is still low — because the van has not arrived — and
/// orders 20 kg again.
///
/// Renders nothing when there is nothing on order, so call sites can drop it in
/// without guarding first — and nothing while the answer is still out, which is
/// the same shape and therefore costs no layout when it arrives.
///
/// This one **does** query per instance, which the other leaf widgets
/// deliberately do not. It is the exception worth making: it appears on a
/// handful of rows rather than on every row of a long list, and every instance
/// asking about the same article shares one live subscription rather than
/// opening its own.
class AlreadyOnOrderBadge extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final onOrder = ref
        .watch(itemOnOrderProvider((storeId: storeId, itemId: itemId)))
        .value;
    if (onOrder == null || onOrder.quantity <= 0) {
      return const SizedBox.shrink();
    }

    final orders = onOrder.orders;
    final formatted = Formatters.quantityWithUnit(
      onOrder.quantity,
      unitAbbreviation,
    );

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
