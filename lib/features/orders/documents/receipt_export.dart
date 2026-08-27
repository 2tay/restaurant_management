import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/documents/document_fonts.dart';
import '../../../core/documents/receipt_document.dart';
import '../../../core/documents/receipt_document_pdf.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/order_status.dart';
import '../../../l10n/app_localizations.dart';
import '../../../mock_data/mock_data.dart';
import '../../../models/models.dart';

/// Turns a stored [GoodsReceipt] into a bon de réception and hands it to the
/// platform.
///
/// The seam between the app and the document: everything above it works in ids
/// and models, everything below it works in resolved strings. Keeping the
/// assembly here rather than in the renderer is what lets the renderer be
/// tested without the mock data, and what will let Phase 2 swap the queries out
/// without the document noticing.
abstract final class ReceiptExport {
  /// Builds the document. Returns null when the receipt's store or supplier has
  /// gone missing — a state the app cannot reach, but one worth failing
  /// visibly rather than printing a header with blanks in it.
  static ReceiptDocument? buildDocument(
    AppLocalizations l10n,
    GoodsReceipt receipt, {
    DateTime? generatedAt,
  }) {
    final order = MockQueries.orderById(receipt.orderId);
    final store = MockQueries.storeById(receipt.storeId);
    if (order == null || store == null) return null;

    final supplier = MockQueries.supplierById(order.supplierId);
    if (supplier == null) return null;

    final now = generatedAt ?? DateTime.now();
    final lines = [for (final line in receipt.lines) _line(order, line)];

    return ReceiptDocument(
      labels: _labels(l10n, store, now),
      reference: MockQueries.receiptReferenceOf(receipt),
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
      orderReference: order.reference,
      orderSentAt: order.sentAt == null
          ? null
          : Formatters.date(order.sentAt!),
      receivedAt: Formatters.dateTime(receipt.receivedAt),
      receivedByName: receipt.receivedByName,
      lines: lines,
      reserves: _reserves(l10n, lines),
      totalValue: receiptValue(receipt),
      note: receipt.note,
      generatedAt: Formatters.dateTime(now),
    );
  }

  /// Builds the document and opens the platform share sheet.
  ///
  /// [Printing.sharePdf] is what makes the manual send work everywhere the app
  /// runs: the share sheet on Android and iOS — which is where WhatsApp and
  /// Gmail are — a download in the browser, and the save dialog on desktop.
  /// One call rather than a platform switch.
  ///
  /// Returns false when the document could not be built, so the caller can say
  /// so rather than leaving a button that silently does nothing.
  static Future<bool> share(
    BuildContext context,
    GoodsReceipt receipt,
  ) async {
    final document = buildDocument(AppLocalizations.of(context), receipt);
    if (document == null) return false;

    final bytes = await buildReceiptDocumentPdf(
      document,
      await DocumentFonts.load(),
    );
    await Printing.sharePdf(bytes: bytes, filename: document.fileName);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  static ReceiptDocumentLine _line(PurchaseOrder order, GoodsReceiptLine line) {
    final item = MockQueries.itemById(line.itemId);

    return ReceiptDocumentLine(
      itemName: item?.name ?? '—',
      unit: item == null ? '' : MockQueries.unitAbbreviationOf(item.unitId),
      quantityOrdered: line.quantityOrdered,
      quantityReceived: line.quantityReceived,
      // The receipt records what was charged but not what was agreed, so the
      // ordered price is read back off the order line. Falls back to the
      // charged price, which reports no movement — better than inventing a
      // baseline and printing a réserve about a difference from nothing.
      orderedUnitPrice: _orderedPriceFor(order, line),
      actualUnitPrice: line.actualUnitPrice,
      wasUnordered: line.wasUnordered,
      closedShort: line.closedShort,
      note: line.note,
    );
  }

  static double _orderedPriceFor(PurchaseOrder order, GoodsReceiptLine line) {
    if (line.wasUnordered) return line.actualUnitPrice;
    for (final ordered in order.lines) {
      if (ordered.itemId == line.itemId) return ordered.unitPrice;
    }
    return line.actualUnitPrice;
  }

  // ---------------------------------------------------------------------------
  // Réserves
  // ---------------------------------------------------------------------------

  /// Phrases every objection the delivery earned, in line order.
  ///
  /// Phrased here rather than in the renderer because this is where the
  /// localised, parameterised strings live. The renderer receives sentences and
  /// only has to lay them out.
  ///
  /// A line can raise more than one: short *and* dearer than agreed is two
  /// separate things to take up with the supplier, and merging them into one
  /// sentence would let the price change hide behind the shortage.
  static List<String> _reserves(
    AppLocalizations l10n,
    List<ReceiptDocumentLine> lines,
  ) {
    final reserves = <String>[];

    for (final line in lines) {
      final quantity = Formatters.quantityWithUnit(line.gap.abs(), line.unit);

      if (line.wasUnordered) {
        reserves.add(
          l10n.receiptDocReserveUnordered(
            line.itemName,
            Formatters.quantityWithUnit(line.quantityReceived, line.unit),
          ),
        );
      } else if (line.gap < 0) {
        final ordered = Formatters.quantityWithUnit(
          line.quantityOrdered,
          line.unit,
        );
        reserves.add(
          line.closedShort
              ? l10n.receiptDocReserveShortClosed(
                  line.itemName,
                  quantity,
                  ordered,
                )
              : l10n.receiptDocReserveShortOpen(
                  line.itemName,
                  quantity,
                  ordered,
                ),
        );
      } else if (line.gap > 0) {
        reserves.add(l10n.receiptDocReserveOver(line.itemName, quantity));
      }

      if (line.priceMoved) {
        reserves.add(
          l10n.receiptDocReservePrice(
            line.itemName,
            Formatters.price(line.orderedUnitPrice),
            Formatters.price(line.actualUnitPrice),
            _percentDelta(line.orderedUnitPrice, line.actualUnitPrice),
          ),
        );
      }

      if (line.note != null && line.note!.isNotEmpty) {
        reserves.add(l10n.receiptDocReserveNote(line.itemName, line.note!));
      }
    }

    return reserves;
  }

  /// `+7,1 %` / `−4,2 %`.
  ///
  /// Signed, because "the price changed by 7 %" is not a complaint and "the
  /// price went up 7 %" is. Falls back to an absolute figure against a zero
  /// baseline, where there is no percentage to quote.
  static String _percentDelta(double oldPrice, double newPrice) {
    if (oldPrice <= 0) return Formatters.priceDelta(newPrice);
    final change = (newPrice - oldPrice) / oldPrice;
    final sign = change < 0 ? '−' : '+';
    return '$sign${Formatters.percent(change.abs())}';
  }

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  static ReceiptDocumentLabels _labels(
    AppLocalizations l10n,
    Store store,
    DateTime generatedAt,
  ) => ReceiptDocumentLabels(
    title: l10n.receiptDocTitle,
    supplierBlock: l10n.receiptDocSupplierBlock,
    orderReference: l10n.receiptDocOrderReference,
    orderSent: l10n.receiptDocOrderSent,
    receivedAt: l10n.receiptDocReceivedAt,
    receivedBy: l10n.receiptDocReceivedBy,
    columnItem: l10n.receiptDocColumnItem,
    columnOrdered: l10n.receiptDocColumnOrdered,
    columnReceived: l10n.receiptDocColumnReceived,
    columnGap: l10n.receiptDocColumnGap,
    columnOrderedPrice: l10n.receiptDocColumnOrderedPrice,
    columnActualPrice: l10n.receiptDocColumnActualPrice,
    columnTotal: l10n.receiptDocColumnTotal,
    unordered: l10n.receiptDocUnordered,
    reserves: l10n.receiptDocReserves,
    noReserves: l10n.receiptDocNoReserves,
    totalLabel: l10n.receiptDocTotalLabel,
    noteLabel: l10n.receiptDocNoteLabel,
    signatureReceiver: l10n.receiptDocSignatureReceiver,
    signatureDriver: l10n.receiptDocSignatureDriver,
    footer: l10n.receiptDocFooter(Formatters.dateTime(generatedAt)),
    vatNumber: store.vatNumber == null
        ? null
        : l10n.receiptDocVatNumber(store.vatNumber!),
  );
}
