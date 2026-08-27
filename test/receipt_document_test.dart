// The bon de réception: the derived reference, the réserves, and the bytes.
//
// The document is a projection of an immutable record, so these tests are
// mostly about one question — does the paper say the same thing the receipt
// says? A réserve that fails to print is a dispute the restaurant silently
// drops, which is a worse failure than a crash.
//
// The mock lists are global and mutable, so every test restores them — see
// test/support/mock_reset.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/documents/document_fonts.dart';
import 'package:stock_inventory/core/documents/receipt_document.dart';
import 'package:stock_inventory/core/documents/receipt_document_pdf.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/core/utils/order_status.dart';
import 'package:stock_inventory/features/orders/documents/receipt_export.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/l10n/app_localizations_fr.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

/// The generated French delegate, built directly. The document never needs a
/// widget tree, and neither should the test of it.
final AppLocalizations l10n = AppLocalizationsFr();

void main() {
  // The renderer loads its faces from the asset bundle, so the binding has to
  // exist before any of it runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  late DocumentFonts fonts;

  setUpAll(() async {
    await initializeDateFormatting(Formatters.locale);
    fonts = await DocumentFonts.load();
  });
  setUp(restoreMockData);

  group('the derived reference', () {
    test('turns a commande number into a delivery number', () {
      expect(receiptReference('CMD-2026-014', 2), 'BR-2026-014/2');
    });

    test('prefixes an unexpected reference rather than mangling it', () {
      expect(receiptReference('2026/99', 1), 'BR-2026/99/1');
    });

    test('numbers deliveries in the order they happened', () {
      OrderMutations.send(OrderIds.sentGrossiste);

      final first = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      );
      final second = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.riz,
            quantityOrdered: 25,
            quantityReceived: 25,
            orderedUnitPrice: 2.10,
            actualUnitPrice: 2.10,
          ),
        ],
      );

      expect(MockQueries.receiptReferenceOf(first), 'BR-2026-017/1');
      expect(
        MockQueries.receiptReferenceOf(second),
        'BR-2026-017/2',
        reason: 'a receipt cannot change its position in its order',
      );
    });
  });

  group('réserves', () {
    test('a delivery matching the order raises none', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = _receiveExactly();

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.reserves, isEmpty);
    });

    test('a short line closed short says the balance is not coming', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 8,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
            closeShort: true,
          ),
        ],
      );

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.reserves, hasLength(1));
      expect(document.reserves.single, contains('soldée'));
      expect(document.reserves.single, contains('7'));
    });

    test('a short line left open says the balance is still due', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 8,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 12.80,
          ),
        ],
      );

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.reserves.single, contains('dû'));
    });

    test('a price that moved raises its own réserve, signed', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 15,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 14.08,
          ),
        ],
      );

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.reserves.single, contains('+10 %'));
    });

    test('short and dearer raises two, so neither hides behind the other', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 8,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 14.08,
            closeShort: true,
          ),
        ],
      );

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.reserves, hasLength(2));
    });

    test('an unordered line is reported as never having been ordered', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.creme,
            quantityOrdered: 0,
            quantityReceived: 2,
            orderedUnitPrice: 4.25,
            actualUnitPrice: 4.25,
            wasUnordered: true,
          ),
        ],
      );

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.reserves.single, contains('sans figurer'));
      expect(
        document.lines.single.gap,
        0,
        reason: 'an unordered line has nothing to be measured against',
      );
    });
  });

  group('the document', () {
    test('carries the store VAT number, and omits it when there is none', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = _receiveExactly();

      final withVat = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(withVat.issuer.vatNumber, contains('BE 0472.318.904'));

      AccountMutations.updateStore(StoreIds.sablon, vatNumber: '');
      final without = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(
        without.issuer.vatNumber,
        isNull,
        reason: 'an empty label is worse than an absent one',
      );
    });

    test('totals at the prices actually charged, not the ordered ones', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = OrderMutations.confirmReceipt(
        orderId: OrderIds.sentGrossiste,
        lines: const [
          ReceiptDraftLine(
            itemId: ItemIds.poulet,
            quantityOrdered: 15,
            quantityReceived: 10,
            orderedUnitPrice: 12.80,
            actualUnitPrice: 14.00,
          ),
        ],
      );

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.totalValue, 140);
    });

    test('names its file after the reference, not the id', () {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = _receiveExactly();

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      expect(document.fileName, 'BR-2026-017-1.pdf');
    });

    test('is drawn with an embedded face, not the Latin-1 fallback', () {
      // The guard on the asset wiring. Fall back to the built-in Helvetica and
      // the document still renders, still passes every other test here, and
      // reaches the supplier with the euro sign missing from every price.
      expect(fonts.regular.fontName, contains('Roboto'));
      expect(fonts.bold.fontName, contains('Roboto'));
    });

    test('renders to real PDF bytes', () async {
      OrderMutations.send(OrderIds.sentGrossiste);
      final receipt = _receiveExactly();

      final document = ReceiptExport.buildDocument(l10n, receipt)!;
      final bytes = await buildReceiptDocumentPdf(document, fonts);

      expect(bytes.length, greaterThan(1000));
      expect(
        String.fromCharCodes(bytes.take(4)),
        '%PDF',
        reason: 'anything else is not a file a supplier can open',
      );
    });

    test('renders a delivery with every kind of réserve on it', () async {
      final document = ReceiptDocument(
        labels: _labelsFor(l10n),
        reference: 'BR-2026-014/2',
        issuer: const ReceiptParty(
          name: 'Brasserie du Sablon',
          addressLine: 'Rue de Rollebeek 12',
          postalCode: '1000',
          city: 'Bruxelles',
          vatNumber: 'TVA BE 0472.318.904',
        ),
        supplier: const ReceiptParty(
          name: 'Grossiste Central',
          addressLine: 'Quai des Usines 4',
          postalCode: '1000',
          city: 'Bruxelles',
        ),
        orderReference: 'CMD-2026-014',
        receivedAt: '27/08/2026 à 14:32',
        orderSentAt: '22/08/2026',
        receivedByName: 'Marc Delvaux',
        generatedAt: '27/08/2026 à 14:33',
        lines: const [
          ReceiptDocumentLine(
            itemName: 'Blanc de poulet',
            unit: 'kg',
            quantityOrdered: 10,
            quantityReceived: 8,
            orderedUnitPrice: 11.95,
            actualUnitPrice: 12.80,
            closedShort: true,
          ),
          ReceiptDocumentLine(
            itemName: 'Crème fraîche',
            unit: 'L',
            quantityOrdered: 0,
            quantityReceived: 2,
            orderedUnitPrice: 4.25,
            actualUnitPrice: 4.25,
            wasUnordered: true,
          ),
        ],
        reserves: const ['Une réserve.', 'Une autre.'],
        totalValue: 110.90,
        note: '2 cageots abîmés, repris par le chauffeur.',
      );

      final bytes = await buildReceiptDocumentPdf(document, fonts);
      expect(bytes.length, greaterThan(1000));
    });
  });
}

/// A clean, complete delivery against the seeded sent order.
GoodsReceipt _receiveExactly() => OrderMutations.confirmReceipt(
  orderId: OrderIds.sentGrossiste,
  lines: const [
    ReceiptDraftLine(
      itemId: ItemIds.poulet,
      quantityOrdered: 15,
      quantityReceived: 15,
      orderedUnitPrice: 12.80,
      actualUnitPrice: 12.80,
    ),
  ],
);

ReceiptDocumentLabels _labelsFor(AppLocalizations l10n) =>
    ReceiptDocumentLabels(
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
      footer: l10n.receiptDocFooter('27/08/2026 à 14:33'),
      vatNumber: l10n.receiptDocVatNumber('BE 0472.318.904'),
    );
