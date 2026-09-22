import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/documents/document_fonts.dart';
import '../../../core/documents/order_document.dart';
import '../../../core/documents/order_document_pdf.dart';
import '../../../core/documents/receipt_document.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/order_status.dart';
import '../../../data/view_models/order_document_sources.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/models.dart';

/// Turns a [PurchaseOrder] into a bon de commande and hands it to the
/// platform — to send to the supplier.
///
/// The same seam as [ReceiptExport]: above it ids and models, below it
/// resolved strings, so the renderer never touches the data layer.
abstract final class OrderExport {
  static OrderDocument buildDocument(
    AppLocalizations l10n,
    OrderDocumentSources sources, {
    DateTime? generatedAt,
  }) {
    final order = sources.order;
    final store = sources.store;
    final supplier = sources.supplier;
    final now = generatedAt ?? DateTime.now();

    return OrderDocument(
      labels: OrderDocumentLabels(
        title: l10n.orderDocTitle,
        draft: l10n.orderDocDraft,
        supplierBlock: l10n.receiptDocSupplierBlock,
        deliverTo: l10n.orderDocDeliverTo,
        orderDate: l10n.orderDocDate,
        sentAt: l10n.receiptDocOrderSent,
        columnItem: l10n.receiptDocColumnItem,
        columnQuantity: l10n.orderDocColumnQuantity,
        columnUnitPrice: l10n.orderDocColumnUnitPrice,
        columnTotal: l10n.orderDocColumnTotal,
        totalLabel: l10n.orderDocTotalLabel,
        noteLabel: l10n.receiptDocNoteLabel,
        closing: l10n.orderDocClosing,
        footer: l10n.orderDocFooter(Formatters.dateTime(now)),
      ),
      reference: order.reference,
      issuer: ReceiptParty(
        name: store.name,
        addressLine: store.addressLine,
        postalCode: store.postalCode,
        city: store.city,
        phone: store.phone,
        vatNumber: store.vatNumber == null
            ? null
            : l10n.receiptDocVatNumber(store.vatNumber!),
      ),
      supplier: ReceiptParty(
        name: supplier.name,
        addressLine: supplier.addressLine,
        postalCode: supplier.postalCode,
        city: supplier.city,
        phone: supplier.phone,
        email: supplier.email,
        contactName: supplier.contactName,
      ),
      createdAt: Formatters.date(order.createdAt),
      sentAt: order.sentAt == null ? null : Formatters.date(order.sentAt!),
      isDraft: order.status == PurchaseOrderStatus.draft,
      lines: [
        for (final line in order.lines)
          OrderDocumentLine(
            itemName: sources.items[line.itemId]?.name ?? '—',
            unit: sources.items[line.itemId]?.unit ?? '',
            quantity: line.quantityOrdered,
            unitPrice: line.unitPrice,
          ),
      ],
      totalValue: orderTotal(order),
      note: order.note,
      generatedAt: Formatters.dateTime(now),
    );
  }

  /// Builds the PDF and opens the platform's share sheet — the save dialog on
  /// desktop, a download in the browser, the share sheet (mail, WhatsApp) on a
  /// phone. Returns false when the order could not be resolved.
  static Future<bool> share(
    BuildContext context,
    OrderDocumentSources? sources,
  ) async {
    if (sources == null) return false;

    final document = buildDocument(AppLocalizations.of(context), sources);
    final bytes = await buildOrderDocumentPdf(
      document,
      await DocumentFonts.load(),
    );
    await Printing.sharePdf(bytes: bytes, filename: document.fileName);
    return true;
  }
}
