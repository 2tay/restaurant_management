import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/models.dart';
import '../../../../shared/widgets/widgets.dart';

/// Asks before deleting a product, and states what goes with it.
///
/// Shared by the detail page and the detail pane rather than written twice.
/// The two used to be one screen; the moment the pane grew its own actions,
/// a copy of this would have been a second confirmation dialog free to drift
/// out of step with the first — and the one thing a delete confirmation must
/// not do is understate its blast radius on one route and not the other.
///
/// Returns true when the product was deleted, so the caller can close whatever
/// was showing it.
Future<bool> confirmDeleteItem(
  BuildContext context,
  WidgetRef ref,
  String storeId,
  Item item,
) async {
  final l10n = AppLocalizations.of(context);
  final items = ref.read(itemRepositoryProvider);

  // A product on a commande a supplier is still holding cannot go: the
  // document would be left referring to nothing. Explained before asking,
  // rather than confirmed and then quietly refused. The repository refuses it
  // too — this is the sentence, not the safeguard.
  final openOrders = await ref
      .read(orderRepositoryProvider)
      .openOrdersForItem(storeId, item.id);
  if (!context.mounted) return false;

  if (openOrders.isNotEmpty) {
    await ConfirmDialog.blocked(
      context,
      title: l10n.itemDeleteBlockedTitle(item.name),
      message: l10n.itemDeleteBlockedBody(openOrders.length),
    );
    return false;
  }

  // Deleting cascades to movements and supplier links, so the dialog states
  // exactly what disappears. A confirmation that does not name its blast
  // radius is a formality, not a safeguard.
  final movements = await ref
      .read(movementRepositoryProvider)
      .movementsForItem(item.id);
  final suppliers = await ref
      .read(supplierRepositoryProvider)
      .pricesForItem(item.id);
  if (!context.mounted) return false;

  final confirmed = await ConfirmDialog.confirmDelete(
    context,
    name: item.name,
    extraWarning: movements.isEmpty && suppliers.isEmpty
        ? null
        : l10n.itemDeleteCascadeWarning(movements.length, suppliers.length),
  );
  if (!confirmed || !context.mounted) return false;

  await items.delete(item.id);
  if (!context.mounted) return true;

  AppSnackBar.success(context, l10n.itemDeleted);
  return true;
}
