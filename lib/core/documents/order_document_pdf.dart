import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/formatters.dart';
import 'document_fonts.dart';
import 'order_document.dart';
import 'receipt_document.dart';

/// Renders an [OrderDocument] — the bon de commande — to PDF bytes.
///
/// Pure, like the bon de réception's renderer: resolved data in, bytes out,
/// no `BuildContext`. Money goes through [Formatters] so the paper says
/// `12,80 €` exactly as the screen does.
///
/// The two documents share their look on purpose — same header, same party
/// blocks, same near-monochrome table — so a supplier holding both sees one
/// business, not two.
Future<Uint8List> buildOrderDocumentPdf(
  OrderDocument doc,
  DocumentFonts fonts,
) {
  final document = pw.Document(title: doc.reference, theme: fonts.theme);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 24),
      // On every page: a second sheet on its own still names its order.
      footer: (context) => _footer(doc, context),
      build: (context) => [
        _header(doc),
        pw.SizedBox(height: 18),
        _parties(doc),
        pw.SizedBox(height: 18),
        _linesTable(doc),
        pw.SizedBox(height: 10),
        _total(doc),
        if (doc.note != null && doc.note!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _note(doc),
        ],
        pw.SizedBox(height: 24),
        pw.Text(doc.labels.closing, style: _style(color: _muted)),
      ],
    ),
  );

  return document.save();
}

const PdfColor _ink = PdfColors.black;
const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _rule = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _headerFill = PdfColor.fromInt(0xFFF3F4F6);
const PdfColor _flag = PdfColor.fromInt(0xFF92400E);
const PdfColor _flagFill = PdfColor.fromInt(0xFFFEF3C7);

pw.TextStyle _style({
  double size = 9,
  PdfColor color = _ink,
  pw.FontWeight weight = pw.FontWeight.normal,
}) => pw.TextStyle(fontSize: size, color: color, fontWeight: weight);

pw.Widget _header(OrderDocument doc) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _partyBlock(doc.issuer, emphasise: true)),
          pw.SizedBox(width: 24),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                doc.labels.title,
                style: _style(size: 16, weight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(doc.reference, style: _style(size: 11, color: _muted)),
              if (doc.isDraft) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _flagFill,
                    border: pw.Border.all(color: _flag, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    doc.labels.draft,
                    style: _style(
                      size: 8,
                      color: _flag,
                      weight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Divider(color: _rule, thickness: 0.8, height: 1),
    ],
  );
}

/// The supplier on the left; the order's facts and where to deliver on the
/// right.
pw.Widget _parties(OrderDocument doc) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _blockLabel(doc.labels.supplierBlock),
            pw.SizedBox(height: 4),
            _partyBlock(doc.supplier),
          ],
        ),
      ),
      pw.SizedBox(width: 24),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _metaRow(doc.labels.orderDate, doc.createdAt),
            if (doc.sentAt != null) _metaRow(doc.labels.sentAt, doc.sentAt!),
            pw.SizedBox(height: 8),
            _blockLabel(doc.labels.deliverTo),
            pw.SizedBox(height: 4),
            pw.Text(doc.issuer.name, style: _style(weight: pw.FontWeight.bold)),
            if (doc.issuer.addressLine.isNotEmpty)
              pw.Text(doc.issuer.addressLine, style: _style(color: _muted)),
            if (doc.issuer.cityLine.isNotEmpty)
              pw.Text(doc.issuer.cityLine, style: _style(color: _muted)),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _partyBlock(ReceiptParty party, {bool emphasise = false}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        party.name,
        style: _style(size: emphasise ? 13 : 10, weight: pw.FontWeight.bold),
      ),
      if (party.contactName != null && party.contactName!.isNotEmpty)
        pw.Text(party.contactName!, style: _style(color: _muted)),
      if (party.addressLine.isNotEmpty)
        pw.Text(party.addressLine, style: _style(color: _muted)),
      if (party.cityLine.isNotEmpty)
        pw.Text(party.cityLine, style: _style(color: _muted)),
      if (party.phone != null && party.phone!.isNotEmpty)
        pw.Text(party.phone!, style: _style(color: _muted)),
      if (party.email != null && party.email!.isNotEmpty)
        pw.Text(party.email!, style: _style(color: _muted)),
      if (emphasise && party.vatNumber != null)
        pw.Text(party.vatNumber!, style: _style(color: _muted)),
    ],
  );
}

pw.Widget _blockLabel(String text) => pw.Text(
  text.toUpperCase(),
  style: _style(size: 8, color: _muted, weight: pw.FontWeight.bold),
);

pw.Widget _metaRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 80,
        child: pw.Text(label, style: _style(color: _muted)),
      ),
      pw.Expanded(
        child: pw.Text(value, style: _style(weight: pw.FontWeight.bold)),
      ),
    ],
  ),
);

pw.Widget _linesTable(OrderDocument doc) {
  final labels = doc.labels;

  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
      bottom: pw.BorderSide(color: _rule, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(1.4),
      3: pw.FlexColumnWidth(1.4),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerFill),
        children: [
          _headCell(labels.columnItem, align: pw.TextAlign.left),
          _headCell(labels.columnQuantity),
          _headCell(labels.columnUnitPrice),
          _headCell(labels.columnTotal),
        ],
      ),
      for (final line in doc.lines)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              child: pw.Text(line.itemName, style: _style()),
            ),
            _cell(
              Formatters.quantityWithUnit(line.quantity, line.unit),
              weight: pw.FontWeight.bold,
            ),
            _cell(Formatters.price(line.unitPrice)),
            _cell(Formatters.price(line.total)),
          ],
        ),
    ],
  );
}

pw.Widget _headCell(String text, {pw.TextAlign align = pw.TextAlign.right}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: _style(size: 8, weight: pw.FontWeight.bold),
      ),
    );

pw.Widget _cell(String text, {pw.FontWeight weight = pw.FontWeight.normal}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: _style(weight: weight),
      ),
    );

pw.Widget _total(OrderDocument doc) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.end,
  children: [
    pw.Text(doc.labels.totalLabel, style: _style(color: _muted)),
    pw.SizedBox(width: 12),
    pw.Text(
      Formatters.price(doc.totalValue),
      style: _style(size: 12, weight: pw.FontWeight.bold),
    ),
  ],
);

pw.Widget _note(OrderDocument doc) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _blockLabel(doc.labels.noteLabel),
    pw.SizedBox(height: 3),
    pw.Text(doc.note!, style: _style()),
  ],
);

pw.Widget _footer(OrderDocument doc, pw.Context context) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 10),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(doc.labels.footer, style: _style(size: 7.5, color: _muted)),
      pw.Text(
        '${doc.reference}   ${context.pageNumber}/${context.pagesCount}',
        style: _style(size: 7.5, color: _muted),
      ),
    ],
  ),
);
