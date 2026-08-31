// Not a test so much as a way to look at the thing.
//
// Writes a bon de réception carrying every case the document has to handle —
// short and closed, short and open, over-delivered, unordered, a price that
// moved — to build/ so it can be opened. Kept in the test folder because that
// is where the machinery to build one already lives.
//
// Run with: flutter test test/document_preview_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/documents/document_fonts.dart';
import 'package:stock_inventory/core/documents/receipt_document_pdf.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/features/orders/documents/receipt_export.dart';
import 'package:stock_inventory/l10n/app_localizations_fr.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show ItemIds, OrderIds;

import 'support/db_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes a sample bon de réception to build/', () async {
    await initializeDateFormatting(Formatters.locale);
    final l10n = AppLocalizationsFr();
    final orders = OrderRepository(await openSeededDatabase());

    await orders.send(OrderIds.sentGrossiste);
    final receipt = await orders.confirmReceipt(
      orderId: OrderIds.sentGrossiste,
      lines: const [
        // Short, dearer than agreed, and closed: the argument for the feature.
        ReceiptDraftLine(
          itemId: ItemIds.poulet,
          quantityOrdered: 15,
          quantityReceived: 11,
          orderedUnitPrice: 12.40,
          actualUnitPrice: 13.90,
          closeShort: true,
          note: '2 cageots abîmés, repris par le chauffeur',
        ),
        // Short but still expected.
        ReceiptDraftLine(
          itemId: ItemIds.riz,
          quantityOrdered: 25,
          quantityReceived: 15,
          orderedUnitPrice: 2.10,
          actualUnitPrice: 2.10,
        ),
        // Turned up without being ordered.
        ReceiptDraftLine(
          itemId: ItemIds.creme,
          quantityOrdered: 0,
          quantityReceived: 6,
          orderedUnitPrice: 4.25,
          actualUnitPrice: 4.25,
          wasUnordered: true,
        ),
      ],
      receivedByName: 'Marc Delvaux',
      note: 'Livraison reçue à 14h32, chauffeur pressé — contrôle fait à deux.',
    );

    final sources = await orders.receiptDocumentSources(receipt!);
    final document = ReceiptExport.buildDocument(l10n, receipt, sources!);
    final bytes = await buildReceiptDocumentPdf(
      document,
      await DocumentFonts.load(),
    );

    final file = File('build/${document.fileName}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);

    expect(await file.length(), greaterThan(1000));
    // ignore: avoid_print
    print('Wrote ${file.path}');
  });
}
