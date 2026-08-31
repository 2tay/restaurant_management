import '../../../models/store.dart';
import 'reference.dart';

/// Store ids, referenced throughout the rest of the mock data.
abstract final class StoreIds {
  /// The flagship. Carries the full dataset.
  static const String sablon = 'store-sablon';

  /// A smaller second location. Deliberately holds a different, thinner set of
  /// items so switching stores visibly changes the screen — proving the store
  /// scoping works rather than just asserting it.
  static const String liege = 'store-liege';

  /// Brand new, zero items. Exists so every empty state can be demoed for real
  /// instead of being described.
  static const String saintGilles = 'store-saint-gilles';
}

final List<Store> mockStores = [
  Store(
    id: StoreIds.sablon,
    name: 'Brasserie du Sablon',
    addressLine: 'Rue de Rollebeek 12',
    postalCode: '1000',
    city: 'Bruxelles',
    phone: '+32 2 512 34 56',
    vatNumber: 'BE 0472.318.904',
    createdAt: monthsAgo(38),
  ),
  Store(
    id: StoreIds.liege,
    name: 'Le Comptoir de Liège',
    addressLine: "Rue du Pot d'Or 34",
    postalCode: '4000',
    city: 'Liège',
    phone: '+32 4 221 78 90',
    vatNumber: 'BE 0688.145.223',
    createdAt: monthsAgo(14),
  ),
  // No VAT number, deliberately: it is the brand-new store, and it proves the
  // document renders correctly for one that has not filled it in yet.
  Store(
    id: StoreIds.saintGilles,
    name: 'Taverne Saint-Gilles',
    addressLine: 'Chaussée de Waterloo 88',
    postalCode: '1060',
    city: 'Bruxelles',
    phone: '+32 2 538 11 22',
    createdAt: daysAgo(6),
  ),
];
