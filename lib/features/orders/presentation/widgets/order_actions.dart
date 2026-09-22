import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// The actions an order offers from wherever it is shown — its own page, a
/// row of the orders list — written once, so the confirmation and the
/// message are the same from both.

/// Asks, then sends [order] to its supplier. The dialog names the supplier:
/// sending locks the order, and "Envoyer" on the wrong row is a real mistake.
Future<void> confirmSendOrder(
  BuildContext context,
  WidgetRef ref,
  PurchaseOrder order,
  String supplierName,
) async {
  final l10n = AppLocalizations.of(context);

  final confirmed = await ConfirmDialog.show(
    context,
    title: l10n.orderSendConfirmTitle(supplierName),
    message: l10n.orderSendConfirmBody,
    confirmLabel: l10n.orderSendConfirmAction,
    isDestructive: false,
  );
  if (!confirmed || !context.mounted) return;

  await ref.read(orderRepositoryProvider).send(order.id);

  if (!context.mounted) return;
  AppSnackBar.success(context, l10n.orderSent(supplierName));
}

/// Starts a new draft with the same supplier, products, quantities and
/// prices as [order], and opens it — reordering the usual weekly delivery is
/// one tap, then any change, then Envoyer.
Future<void> duplicateOrder(
  BuildContext context,
  WidgetRef ref,
  String storeId,
  PurchaseOrder order,
) async {
  final l10n = AppLocalizations.of(context);

  final copy = await ref
      .read(orderRepositoryProvider)
      .createDraft(
        storeId: storeId,
        supplierId: order.supplierId,
        lines: [
          // Only what was ordered; nothing received, nothing closed. The
          // repository gives each line its id as it writes it.
          for (final line in order.lines)
            PurchaseOrderLine(
              id: '',
              itemId: line.itemId,
              quantityOrdered: line.quantityOrdered,
              unitPrice: line.unitPrice,
            ),
        ],
        note: order.note,
      );

  if (!context.mounted) return;
  AppSnackBar.success(context, l10n.orderDuplicated(copy.reference));
  context.pushScreen(Routes.toOrder(storeId, copy.id));
}
