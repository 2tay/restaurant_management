/// One restaurant location.
///
/// An owner account can hold several. Once a store is selected, every
/// inventory, supplier, report and team screen shows that store's data only —
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
    this.imageAsset,
  });

  final String id;
  final String name;
  final String addressLine;
  final String postalCode;
  final String city;
  final String phone;
  final DateTime createdAt;

  /// Optional logo/photo. Null renders a generated initial tile instead.
  final String? imageAsset;
}
