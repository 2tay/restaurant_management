import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/navigation.dart';
import '../../../../app/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../documents/receipt_document_button.dart';
import '../widgets/receipt_detail_view.dart';

/// One delivery, as recorded.
///
/// Read-only, and deliberately has no edit or delete action anywhere on it. A
/// confirmed receipt is what the stock movements point back to; changing it
/// after the fact would silently rewrite history that somebody may already have
/// acted on. Corrections go through a stock adjustment instead, which leaves
/// both the original and the correction visible.
///
/// Reachable from the order it belongs to and from any stock movement it
/// generated, which is what closes the trail: quantity → movement → receipt →
/// order → supplier.
class ReceiptDetailPage extends ConsumerWidget {
  const ReceiptDetailPage({
    required this.storeId,
    required this.receiptId,
    super.key,
  });

  final String storeId;
  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(receiptDetailProvider(receiptId));
    final view = detail.value;

    if (view == null) {
      return ShellPage(
        title: l10n.ordersTitle,
        child: detail.isLoading
            ? const SkeletonList(rows: 3, rowHeight: 110)
            : ErrorState(
                message: l10n.errorStateBody,
                onRetry: () => context.goSection(Routes.toOrders(storeId)),
              ),
      );
    }

    final receipt = view.receipt;
    final reference = view.orderReference;

    return ShellPage(
      back: BackDestination(
        label: reference,
        path: Routes.toOrder(storeId, receipt.orderId),
      ),
      crumbs: [
        Crumb(l10n.ordersTitle, Routes.toOrders(storeId)),
        Crumb(reference, Routes.toOrder(storeId, receipt.orderId)),
        Crumb(l10n.orderTabReceipts),
      ],
      title: l10n.receiptDetailTitle(Formatters.dateLong(receipt.receivedAt)),
      // The document reference is on screen because the phone call that follows
      // an emailed bon de réception starts with the supplier quoting it back.
      subtitle:
          '${view.reference} · '
          '${l10n.receiptReceivedBy(receipt.receivedByName)}',
      actions: [
        SecondaryButton(
          label: l10n.receiptOrderReference(reference),
          icon: LucideIcons.clipboardList,
          onPressed: () =>
              context.pushScreen(Routes.toOrder(storeId, receipt.orderId)),
        ),
        // The primary action on a read-only screen. There is nothing to edit
        // here, and getting the record out of the app and to the supplier is
        // the only thing anybody comes to this page to do.
        ReceiptDocumentButton(receipt: receipt),
      ],
      child: ReceiptDetailBody(storeId: storeId, receiptId: receiptId),
    );
  }
}
