import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The faces a generated document is drawn with.
///
/// `package:pdf` falls back to its built-in Helvetica, which is Latin-1 and so
/// cannot draw `€`, `—`, `−` or `•` — it drops them silently and logs. A price
/// column with no euro signs is not something anybody can send to a supplier,
/// which makes embedding a real font a correctness requirement rather than
/// typography.
///
/// Loaded from the bundle rather than fetched at runtime: the app has to
/// produce the same document in a cold storeroom with no signal.
class DocumentFonts {
  const DocumentFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  /// Cached after the first load. The bytes are ~340 KB and identical every
  /// time; re-parsing them per document would make the second bon de réception
  /// as slow as the first for no reason.
  static Future<DocumentFonts>? _cached;

  static Future<DocumentFonts> load() =>
      _cached ??= _load();

  static Future<DocumentFonts> _load() async {
    final regular = await rootBundle.load('fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('fonts/Roboto-Bold.ttf');
    return DocumentFonts(
      regular: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
  }

  /// The theme every text style in a document inherits from.
  pw.ThemeData get theme =>
      pw.ThemeData.withFont(base: regular, bold: bold);
}
