import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/formatters.dart';
import 'document_fonts.dart';
import 'receipt_document.dart';

/// Renders a [ReceiptDocument] to PDF bytes.
///
/// Pure: takes resolved data, returns bytes, touches no `BuildContext`, no mock
/// lists and no localisation lookup. That is what lets a test assert on a
/// document built from a literal.
///
/// Numbers go through [Formatters] rather than being formatted here, so the
/// `12,80 €` on the paper is produced by the same code as the `12,80 €` on the
/// screen. A document that formats its own money is how `1,250.00` ends up in
/// front of a Belgian supplier.
///
/// [fonts] is required rather than optional. Making it optional would leave a
/// path that produces a plausible-looking document with every euro sign
/// silently dropped, and a caller would only find out from a supplier.
Future<Uint8List> buildReceiptDocumentPdf(
  ReceiptDocument doc,
  DocumentFonts fonts,
) {
  final document = pw.Document(title: doc.reference, theme: fonts.theme);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 24),
      // Repeated on every page: a second sheet arriving on its own must still
      // say which delivery it belongs to.
      footer: (context) => _footer(doc, context),
      build: (context) => [
        _header(doc),
        pw.SizedBox(height: 18),
        _parties(doc),
        pw.SizedBox(height: 18),
        _linesTable(doc),
        pw.SizedBox(height: 10),
        _total(doc),
        pw.SizedBox(height: 18),
        _reserves(doc),
        if (doc.note != null) ...[pw.SizedBox(height: 14), _note(doc)],
        pw.SizedBox(height: 28),
        _signatures(doc),
      ],
    ),
  );

  return document.save();
}

// -----------------------------------------------------------------------------
// Palette
//
// Deliberately near-monochrome. This is a document that gets printed, faxed by
// somebody's accountant and photographed on a phone in a cold storeroom, so it
// has to survive being read in black and white. One accent carries the only
// thing colour is doing any work for: the discrepancies.
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// Blocks
// -----------------------------------------------------------------------------

pw.Widget _header(ReceiptDocument doc) {
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
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Divider(color: _rule, thickness: 0.8, height: 1),
    ],
  );
}

/// The supplier on the left, the delivery's own facts on the right.
pw.Widget _parties(ReceiptDocument doc) {
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
            _metaRow(doc.labels.orderReference, doc.orderReference),
            if (doc.orderSentAt != null)
              _metaRow(doc.labels.orderSent, doc.orderSentAt!),
            _metaRow(doc.labels.receivedAt, doc.receivedAt),
            _metaRow(doc.labels.receivedBy, doc.receivedByName),
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
        style: _style(
          size: emphasise ? 13 : 10,
          weight: pw.FontWeight.bold,
        ),
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
      // The issuer's VAT number only. A supplier's is not ours to assert.
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
        width: 92,
        child: pw.Text(label, style: _style(color: _muted)),
      ),
      pw.Expanded(
        child: pw.Text(value, style: _style(weight: pw.FontWeight.bold)),
      ),
    ],
  ),
);

// -----------------------------------------------------------------------------
// The table
// -----------------------------------------------------------------------------

pw.Widget _linesTable(ReceiptDocument doc) {
  final labels = doc.labels;

  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
      bottom: pw.BorderSide(color: _rule, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(3.2),
      1: pw.FlexColumnWidth(1.1),
      2: pw.FlexColumnWidth(1.1),
      3: pw.FlexColumnWidth(1),
      4: pw.FlexColumnWidth(1.2),
      5: pw.FlexColumnWidth(1.2),
      6: pw.FlexColumnWidth(1.2),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerFill),
        children: [
          _headCell(labels.columnItem, align: pw.TextAlign.left),
          _headCell(labels.columnOrdered),
          _headCell(labels.columnReceived),
          _headCell(labels.columnGap),
          _headCell(labels.columnOrderedPrice),
          _headCell(labels.columnActualPrice),
          _headCell(labels.columnTotal),
        ],
      ),
      for (final line in doc.lines) _lineRow(doc, line),
    ],
  );
}

pw.TableRow _lineRow(ReceiptDocument doc, ReceiptDocumentLine line) {
  final flagged = line.gap != 0 || line.wasUnordered || line.priceMoved;

  return pw.TableRow(
    decoration: flagged
        ? const pw.BoxDecoration(color: _flagFill)
        : null,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.RichText(
          text: pw.TextSpan(
            text: line.itemName,
            style: _style(),
            children: [
              if (line.wasUnordered)
                pw.TextSpan(
                  text: '  ${doc.labels.unordered}',
                  style: _style(size: 7.5, color: _flag),
                ),
            ],
          ),
        ),
      ),
      // An unordered line has no ordered quantity to compare against, and
      // printing 0 would read as "we ordered none and they sent some", which is
      // an accusation rather than a fact.
      _cell(
        line.wasUnordered
            ? '—'
            : Formatters.quantityWithUnit(line.quantityOrdered, line.unit),
      ),
      _cell(
        Formatters.quantityWithUnit(line.quantityReceived, line.unit),
        weight: pw.FontWeight.bold,
      ),
      _cell(
        line.gap == 0
            ? '—'
            : Formatters.quantityDelta(line.gap, line.unit),
        color: line.gap == 0 ? _ink : _flag,
        weight: line.gap == 0 ? pw.FontWeight.normal : pw.FontWeight.bold,
      ),
      _cell(
        line.wasUnordered ? '—' : Formatters.price(line.orderedUnitPrice),
      ),
      _cell(
        Formatters.price(line.actualUnitPrice),
        color: line.priceMoved ? _flag : _ink,
        weight: line.priceMoved ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      _cell(Formatters.price(line.total)),
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

pw.Widget _cell(
  String text, {
  PdfColor color = _ink,
  pw.FontWeight weight = pw.FontWeight.normal,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  child: pw.Text(
    text,
    textAlign: pw.TextAlign.right,
    style: _style(color: color, weight: weight),
  ),
);

pw.Widget _total(ReceiptDocument doc) => pw.Row(
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

// -----------------------------------------------------------------------------
// Réserves
// -----------------------------------------------------------------------------

/// The section that makes this document worth sending.
///
/// Printed even when there is nothing to report: "livraison conforme" is a
/// statement that the delivery was checked, where an absent section only says
/// nobody wrote anything down.
pw.Widget _reserves(ReceiptDocument doc) {
  final hasReserves = doc.reserves.isNotEmpty;

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: hasReserves ? _flagFill : null,
      border: pw.Border.all(color: hasReserves ? _flag : _rule, width: 0.6),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          doc.labels.reserves,
          style: _style(
            size: 8,
            weight: pw.FontWeight.bold,
            color: hasReserves ? _flag : _muted,
          ),
        ),
        pw.SizedBox(height: 6),
        if (!hasReserves)
          pw.Text(doc.labels.noReserves, style: _style(color: _muted))
        else
          for (final reserve in doc.reserves)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('•  ', style: _style()),
                  pw.Expanded(child: pw.Text(reserve, style: _style())),
                ],
              ),
            ),
      ],
    ),
  );
}

pw.Widget _note(ReceiptDocument doc) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _blockLabel(doc.labels.noteLabel),
    pw.SizedBox(height: 3),
    pw.Text(doc.note!, style: _style()),
  ],
);

// -----------------------------------------------------------------------------
// Signatures and footer
// -----------------------------------------------------------------------------

/// Two boxes, because the case this document exists for is the one where the
/// driver is still standing there and the delivery is disputed.
pw.Widget _signatures(ReceiptDocument doc) => pw.Row(
  children: [
    pw.Expanded(child: _signatureBox(doc.labels.signatureReceiver)),
    pw.SizedBox(width: 32),
    pw.Expanded(child: _signatureBox(doc.labels.signatureDriver)),
  ],
);

pw.Widget _signatureBox(String label) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(label, style: _style(size: 8, color: _muted)),
    pw.SizedBox(height: 34),
    pw.Container(height: 0.6, color: _rule),
  ],
);

pw.Widget _footer(ReceiptDocument doc, pw.Context context) => pw.Padding(
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
