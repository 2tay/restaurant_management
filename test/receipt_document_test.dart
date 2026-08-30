// The bon de réception: the derived reference, the réserves, and the bytes.
//
// The document is a projection of an immutable record, so these tests are
// mostly about one question — does the paper say the same thing the receipt
// says? A réserve that fails to print is a dispute the restaurant silently
// drops, which is a worse failure than a crash.
//
// Ported from the mock lists to a database in Phase 2 stage 7. The plan said
// this needed only its `setUp` swapped, and that was true of the assertions but
// not of the call: `ReceiptExport.buildDocument` used to make its own lookups
// and now takes them, so every test here builds the sources first. The last
// test in the file — the one that clears a store's VAT number — is why the port
// waited for this stage rather than landing with the rest of receiving.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/documents/document_fonts.dart';
import 'package:stock_inventory/core/documents/receipt_document.dart';
import 'package:stock_inventory/core/documents/receipt_document_pdf.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/core/utils/order_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/features/orders/documents/receipt_export.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/l10n/app_localizations_fr.dart';
import 'package:stock_inventory/mock_data/mock_data.dart'
    show ItemIds, OrderIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import 'support/db_fixture.dart';

/// The generated French delegate, built directly. The document never needs a
/// widget tree, and neither should the test of it.
final AppLocalizations l10n = AppLocalizationsFr();

void main() {
  // The renderer loads its faces from the asset bundle, so the binding has to
  // exist before any of it runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  late DocumentFonts fonts;
  late AppDatabase db;
  late OrderRepository orders;

  setUpAll(() async {
    await initializeDateFormatting(Formatters.locale);
    fonts = await DocumentFonts.load();
  });

  setUp(() async {
    db = await openSeededDatabase();
    orders = OrderRepository(db);
  });

  /// Assembles the document for a receipt, the way the screen will.
  ///
  /// The lookups and the assembly are two steps now, which is the point of the
  /// split: everything below this line is a pure function of what it is handed.
  Future<ReceiptDocument> documentFor(GoodsReceipt receipt) async {
    final sources = await orders.receiptDocumentSources(receipt);
    expect(sources, isNotNull);
    return ReceiptExport.buildDocument(l10n, receipt, sources!);
  }

  /// A clean, complete delivery against the seeded sent commande.
  Future<GoodsReceipt> receiveExactly() async {
    final receipt = await orders.confirmReceipt(
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
    expect(receipt, isNotNull);
    return receipt!;
  }

  group('the derived reference', () {
    test('turns a commande number into a delivery number', () {
      expect(receiptReference('CMD-2026-014', 2), 'BR-2026-014/2');
    });

    test('prefixes an unexpected reference rather than mangling it', () {
      expect(receiptReference('2026/99', 1), 'BR-2026/99/1');
    });

    test('numbers deliveries in the order they happened', () async {
      await orders.send(OrderIds.sentGrossiste);

      final first = await orders.confirmReceipt(
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
      final second = await orders.confirmReceipt(
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

      expect(await orders.receiptReferenceOf(first!), 'BR-2026-017/1');
      expect(
        await orders.receiptReferenceOf(second!),
        'BR-2026-017/2',
        reason: 'a receipt cannot change its position in its commande',
      );
    });
  });

  group('réserves', () {
    test('a delivery matching the commande raises none', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await receiveExactly();

      expect((await documentFor(receipt)).reserves, isEmpty);
    });

    test('a short line closed short says the balance is not coming', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await orders.confirmReceipt(
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

      final document = await documentFor(receipt!);
      expect(document.reserves, hasLength(1));
      expect(document.reserves.single, contains('soldée'));
      expect(document.reserves.single, contains('7'));
    });

    test('a short line left open says the balance is still due', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await orders.confirmReceipt(
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

      expect((await documentFor(receipt!)).reserves.single, contains('dû'));
    });

    test('a price that moved raises its own réserve, signed', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await orders.confirmReceipt(
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

      expect(
        (await documentFor(receipt!)).reserves.single,
        contains('+10 %'),
      );
    });

    test('short and dearer raises two, so neither hides the other', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await orders.confirmReceipt(
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

      expect((await documentFor(receipt!)).reserves, hasLength(2));
    });

    test('an unordered line is reported as never having been ordered', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await orders.confirmReceipt(
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

      final document = await documentFor(receipt!);
      expect(document.reserves.single, contains('sans figurer'));
      expect(
        document.lines.single.gap,
        0,
        reason: 'an unordered line has nothing to be measured against',
      );
    });
  });

  group('the document', () {
    test('carries the store VAT number, and omits it when there is none', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await receiveExactly();

      final withVat = await documentFor(receipt);
      expect(withVat.issuer.vatNumber, contains('BE 0472.318.904'));

      await StoreRepository(db).updateStore(StoreIds.sablon, vatNumber: '');
      final without = await documentFor(receipt);
      expect(
        without.issuer.vatNumber,
        isNull,
        reason: 'an empty label is worse than an absent one',
      );
    });

    test('totals at the prices actually charged, not the ordered ones', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await orders.confirmReceipt(
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

      expect((await documentFor(receipt!)).totalValue, 140);
    });

    test('names its file after the reference, not the id', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await receiveExactly();

      expect((await documentFor(receipt)).fileName, 'BR-2026-017-1.pdf');
    });

    test('names an article that has since been deleted with a dash', () async {
      // New here, and only reachable now that the names are looked up rather
      // than read off an object the receipt still holds. A receipt is evidence:
      // it has to stay printable after the catalogue moves on.
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await receiveExactly();

      // Deletable because the commande it was on is finished: the delivery
      // completed it, so nothing is outstanding.
      expect(await ItemRepository(db).delete(ItemIds.poulet), isTrue);

      final document = await documentFor(receipt);
      expect(document.lines.single.itemName, '—');
      expect(document.lines.single.unit, isEmpty);
    });

    test('is drawn with an embedded face, not the Latin-1 fallback', () {
      // The guard on the asset wiring. Fall back to the built-in Helvetica and
      // the document still renders, still passes every other test here, and
      // reaches the supplier with the euro sign missing from every price.
      expect(fonts.regular.fontName, contains('Roboto'));
      expect(fonts.bold.fontName, contains('Roboto'));
    });

    test('renders to real PDF bytes', () async {
      await orders.send(OrderIds.sentGrossiste);
      final receipt = await receiveExactly();

      final bytes = await buildReceiptDocumentPdf(
        await documentFor(receipt),
        fonts,
      );

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
