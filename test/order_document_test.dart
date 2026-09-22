// The bon de commande: the PDF of an order, to send to its supplier.
//
// What these hold: every line of the order is on the document with its
// product's name, the total matches the order's, a draft says it is a draft,
// and the renderer produces a real PDF.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/documents/document_fonts.dart';
import 'package:stock_inventory/core/documents/order_document_pdf.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/core/utils/order_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart' show OrderIds;
import 'package:stock_inventory/features/orders/documents/order_export.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/l10n/app_localizations_fr.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/db_fixture.dart';

final AppLocalizations l10n = AppLocalizationsFr();

void main() {
  // The renderer loads its faces from the asset bundle.
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

  test('every line of the order is on the document, named', () async {
    final order = (await orders.order(OrderIds.sentGrossiste))!;
    final sources = (await orders.orderDocumentSources(order))!;

    final doc = OrderExport.buildDocument(l10n, sources);

    expect(doc.reference, order.reference);
    expect(doc.lines, hasLength(order.lines.length));
    for (final line in doc.lines) {
      expect(line.itemName, isNot('—'));
    }
    expect(doc.totalValue, closeTo(orderTotal(order), 0.001));
    expect(doc.isDraft, isFalse);
    expect(doc.fileName, endsWith('.pdf'));
  });

  test('a draft is stamped as one', () async {
    final all = await orders.orders(
      (await orders.order(OrderIds.sentGrossiste))!.storeId,
    );
    final draft = all.firstWhere(
      (order) => order.status == PurchaseOrderStatus.draft,
    );
    final sources = (await orders.orderDocumentSources(draft))!;

    expect(OrderExport.buildDocument(l10n, sources).isDraft, isTrue);
  });

  test('the renderer produces a PDF', () async {
    final order = (await orders.order(OrderIds.sentGrossiste))!;
    final sources = (await orders.orderDocumentSources(order))!;

    final bytes = await buildOrderDocumentPdf(
      OrderExport.buildDocument(l10n, sources),
      fonts,
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
