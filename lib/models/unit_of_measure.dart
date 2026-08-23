/// A unit of measure — kilogramme (kg), litre (L), bac, caisse.
///
/// Like [Category], units are created in-app rather than hardcoded. A Belgian
/// kitchen counts beer in `bac` and produce in `caisse`, and no fixed list
/// would have guessed that.
class UnitOfMeasure {
  const UnitOfMeasure({
    required this.id,
    required this.storeId,
    required this.name,
    required this.abbreviation,
  });

  final String id;
  final String storeId;

  /// Full name, e.g. "Kilogramme". Shown in management screens.
  final String name;

  /// Short form, e.g. "kg". Shown next to every quantity in the app.
  final String abbreviation;

  /// See the note on [Category.copyWith] — a constructor convenience.
  UnitOfMeasure copyWith({String? name, String? abbreviation}) {
    return UnitOfMeasure(
      id: id,
      storeId: storeId,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
    );
  }
}
