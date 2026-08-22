import '../models/unit_of_measure.dart';
import 'mock_stores.dart';

abstract final class UnitIds {
  static const String kg = 'unit-kg';
  static const String gramme = 'unit-g';
  static const String litre = 'unit-l';
  static const String centilitre = 'unit-cl';
  static const String piece = 'unit-piece';
  static const String caisse = 'unit-caisse';
  static const String bac = 'unit-bac';
  static const String botte = 'unit-botte';

  static const String liegeKg = 'unit-liege-kg';
  static const String liegeBac = 'unit-liege-bac';
  static const String liegePiece = 'unit-liege-piece';
}

/// Note `bac` and `caisse`: a Belgian kitchen counts beer by the crate and
/// produce by the case, and no hardcoded unit list would have guessed that.
/// This is exactly why units are user-created.
const List<UnitOfMeasure> mockUnits = [
  UnitOfMeasure(
    id: UnitIds.kg,
    storeId: StoreIds.sablon,
    name: 'Kilogramme',
    abbreviation: 'kg',
  ),
  UnitOfMeasure(
    id: UnitIds.gramme,
    storeId: StoreIds.sablon,
    name: 'Gramme',
    abbreviation: 'g',
  ),
  UnitOfMeasure(
    id: UnitIds.litre,
    storeId: StoreIds.sablon,
    name: 'Litre',
    abbreviation: 'L',
  ),
  UnitOfMeasure(
    id: UnitIds.centilitre,
    storeId: StoreIds.sablon,
    name: 'Centilitre',
    abbreviation: 'cl',
  ),
  UnitOfMeasure(
    id: UnitIds.piece,
    storeId: StoreIds.sablon,
    name: 'Pièce',
    abbreviation: 'pce',
  ),
  UnitOfMeasure(
    id: UnitIds.caisse,
    storeId: StoreIds.sablon,
    name: 'Caisse',
    abbreviation: 'caisse',
  ),
  UnitOfMeasure(
    id: UnitIds.bac,
    storeId: StoreIds.sablon,
    name: 'Bac',
    abbreviation: 'bac',
  ),
  UnitOfMeasure(
    id: UnitIds.botte,
    storeId: StoreIds.sablon,
    name: 'Botte',
    abbreviation: 'botte',
  ),
  UnitOfMeasure(
    id: UnitIds.liegeKg,
    storeId: StoreIds.liege,
    name: 'Kilogramme',
    abbreviation: 'kg',
  ),
  UnitOfMeasure(
    id: UnitIds.liegeBac,
    storeId: StoreIds.liege,
    name: 'Bac',
    abbreviation: 'bac',
  ),
  UnitOfMeasure(
    id: UnitIds.liegePiece,
    storeId: StoreIds.liege,
    name: 'Pièce',
    abbreviation: 'pce',
  ),
];
