/// One restaurant location.
///
/// An owner account can hold several. Once a store is selected, every
/// inventory, supplier and report screen shows that store's data only —
/// enforced structurally by carrying the store id in the route path.
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.postalCode,
    required this.city,
    required this.phone,
    required this.createdAt,
    this.vatNumber,
    this.imageAsset,
  });

  final String id;
  final String name;
  final String addressLine;
  final String postalCode;
  final String city;
  final String phone;
  final DateTime createdAt;

  /// VAT number — `BE 0123.456.789`.
  ///
  /// Optional, and the only field here that exists for something outside the
  /// app: a bon de réception sent to a supplier is a business document, and a
  /// Belgian one carries the issuer's VAT number. Null is a legitimate state —
  /// a store created mid-service has better things to do than type it — and the
  /// document simply leaves the line out rather than printing an empty label.
  final String? vatNumber;

  /// Optional logo/photo. Null renders a generated initial tile instead.
  final String? imageAsset;
}
