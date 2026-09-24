# Fonts

## Montserrat

`Montserrat-Regular/Medium/SemiBold/Bold.ttf` — SIL Open Font License 1.1
(`Montserrat-OFL.txt`), © The Montserrat Project Authors.

The app's own typeface (`AppTypography.fontFamily`), declared under `fonts:` in
`pubspec.yaml`. Static weights rather than the variable font: Flutter picks the
right file from `FontWeight` with no `FontVariation` plumbing. Bundled, not
fetched at runtime — the app has to look the same in a storeroom with no signal.

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
