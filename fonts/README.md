# Fonts

## Roboto

`Roboto-Regular.ttf`, `Roboto-Bold.ttf` — Apache License 2.0, © Google.

Bundled for **PDF generation only**, not for the app's own text. The bon de
réception is built by `package:pdf`, whose built-in Helvetica is Latin-1 and
therefore cannot draw `€`, `—`, `−` or `•`. A delivery document with the euro
sign missing from every price is not a document anybody can send to a supplier,
so the faces are embedded rather than left to a runtime download — the app has
to produce the same paper in a storeroom with no signal.

Two weights, because that is what the document actually uses. Adding the other
four would cost a megabyte to render nothing.

Loaded by `lib/core/documents/document_fonts.dart` and declared under `assets:`
in `pubspec.yaml` rather than `fonts:` — Flutter never renders with them, the
PDF renderer just needs the bytes.
