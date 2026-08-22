/// A supplier for one store.
class Supplier {
  const Supplier({
    required this.id,
    required this.storeId,
    required this.name,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.addressLine,
    required this.postalCode,
    required this.city,
    this.note,
  });

  final String id;
  final String storeId;
  final String name;
  final String contactName;
  final String email;
  final String phone;
  final String addressLine;
  final String postalCode;
  final String city;
  final String? note;
}
