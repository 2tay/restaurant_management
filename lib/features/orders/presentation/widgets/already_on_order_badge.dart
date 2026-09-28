import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';

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
      child: LabelChip(
        label: l10n.orderAlreadyOnOrder(formatted),
        icon: LucideIcons.truck,
        background: AppColors.offlineContainer,
        foreground: AppColors.steel800,
        dense: true,
      ),
    );
  }
}
