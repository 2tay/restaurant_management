import '../models/supplier.dart';
import 'mock_stores.dart';

abstract final class SupplierIds {
  static const String grossisteCentral = 'sup-grossiste-central';
  static const String horecaSelect = 'sup-horeca-select';
  static const String maraicher = 'sup-maraicher';
  static const String boucherie = 'sup-boucherie';
  static const String brasseurs = 'sup-brasseurs';
  static const String cremerie = 'sup-cremerie';
  static const String maree = 'sup-maree';

  static const String liegeGrossiste = 'sup-liege-grossiste';
  static const String liegeBrasseurs = 'sup-liege-brasseurs';
}

/// Names are plausible-but-invented rather than real Belgian wholesalers.
/// Putting a real company's name next to invented pricing in a client demo
/// would be misleading, and the demo reads just as true without it.
const List<Supplier> mockSuppliers = [
Supplier(
    id: SupplierIds.grossisteCentral,
    storeId: StoreIds.sablon,
    name: 'Grossiste Central Bruxelles',
    contactName: 'Patrick Moreau',
    email: 'commandes@grossiste-central.be',
    phone: '+32 2 640 12 00',
    addressLine: 'Boulevard Industriel 45',
    postalCode: '1070',
    city: 'Anderlecht',
    note: 'Livraison les mardis et vendredis avant 10h.',
  ),
  Supplier(
    id: SupplierIds.horecaSelect,
    storeId: StoreIds.sablon,
    name: 'Horeca Select',
    contactName: 'Ingrid De Smet',
    email: 'sablon@horeca-select.be',
    phone: '+32 2 731 55 40',
    addressLine: 'Zoning Nord 8',
    postalCode: '1930',
    city: 'Zaventem',
    note: 'Commande minimum 250 €.',
  ),
  Supplier(
    id: SupplierIds.maraicher,
    storeId: StoreIds.sablon,
    name: 'Maraîcher Vandenbroucke',
    contactName: 'Luc Vandenbroucke',
    email: 'luc@maraicher-vdb.be',
    phone: '+32 476 21 33 87',
    addressLine: 'Chemin des Champs 3',
    postalCode: '1740',
    city: 'Ternat',
    note: 'Produits de saison, livraison directe du champ.',
  ),
  Supplier(
    id: SupplierIds.boucherie,
    storeId: StoreIds.sablon,
    name: 'Boucherie Lambrechts',
    contactName: 'Nathalie Lambrechts',
    email: 'contact@boucherie-lambrechts.be',
    phone: '+32 2 511 09 76',
    addressLine: 'Rue Haute 122',
    postalCode: '1000',
    city: 'Bruxelles',
  ),
  Supplier(
    id: SupplierIds.brasseurs,
    storeId: StoreIds.sablon,
    name: 'Brasseurs Réunis',
    contactName: 'Dirk Janssens',
    email: 'horeca@brasseurs-reunis.be',
    phone: '+32 3 234 88 10',
    addressLine: 'Havenlaan 210',
    postalCode: '2030',
    city: 'Antwerpen',
    note: 'Reprise des bacs vides à chaque livraison.',
  ),
  Supplier(
    id: SupplierIds.cremerie,
    storeId: StoreIds.sablon,
    name: 'Crémerie du Brabant',
    contactName: 'Sylvie Dupont',
    email: 'ventes@cremerie-brabant.be',
    phone: '+32 10 45 62 30',
    addressLine: 'Rue de la Laiterie 17',
    postalCode: '1300',
    city: 'Wavre',
  ),
  Supplier(
    id: SupplierIds.maree,
    storeId: StoreIds.sablon,
    name: 'Marée du Nord',
    contactName: 'Bart Vermeulen',
    email: 'orders@maree-du-nord.be',
    phone: '+32 59 32 14 05',
    addressLine: 'Visserskaai 22',
    postalCode: '8400',
    city: 'Oostende',
    note: 'Arrivage frais du jour, commande avant 6h.',
  ),
  Supplier(
    id: SupplierIds.liegeGrossiste,
    storeId: StoreIds.liege,
    name: 'Grossiste Meuse',
    contactName: 'Olivier Renard',
    email: 'info@grossiste-meuse.be',
    phone: '+32 4 252 67 41',
    addressLine: 'Quai de Rome 60',
    postalCode: '4000',
    city: 'Liège',
  ),
  Supplier(
    id: SupplierIds.liegeBrasseurs,
    storeId: StoreIds.liege,
    name: 'Brasseurs Réunis',
    contactName: 'Dirk Janssens',
    email: 'horeca@brasseurs-reunis.be',
    phone: '+32 3 234 88 10',
    addressLine: 'Havenlaan 210',
    postalCode: '2030',
    city: 'Antwerpen',
  ),
];
