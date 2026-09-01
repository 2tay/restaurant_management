import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/utils/order_status.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/widgets.dart';
import 'create_order_page.dart';

/// Edit a draft commande.
///
/// The same form as creating one, because that is what it is — an order with
/// something already in it. Writing a second screen would guarantee the two
/// drifted apart on the details that matter, like which items the picker offers.
///
/// Refuses anything that is not a draft rather than rendering a form that
/// cannot save. A sent order is locked: the supplier is holding a copy of it,
/// and an order that quietly disagrees with the document in their inbox is
/// worse than no order at all.
class EditOrderPage extends ConsumerWidget {
  const EditOrderPage({
    required this.storeId,
    required this.orderId,
    super.key,
  });

  final String storeId;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncOrder = ref.watch(orderProvider(orderId));
    final order = asyncOrder.value;

    if (order == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: asyncOrder.isLoading
            ? const SkeletonList(rows: 3, rowHeight: 100)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () => context.goSection(Routes.toOrders(storeId)),
              ),
      );
    }

    if (!orderIsEditable(order)) {
      return ShellPage(
        back: BackDestination(
          label: l10n.ordersTitle,
          path: Routes.toOrders(storeId),
        ),
        title: l10n.orderDetailTitle(order.reference),
        child: ErrorState(
          message: l10n.orderLockedNotice,
          onRetry: () => context.goSection(Routes.toOrder(storeId, order.id)),
        ),
      );
    }

    return OrderFormPage(storeId: storeId, orderId: orderId);
  }
}
