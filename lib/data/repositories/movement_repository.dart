import 'package:drift/drift.dart';

import '../../models/stock_movement.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';

/// The stock movement log.
///
/// Reads for now; stage 5 adds the writes, and when it does this becomes the
/// **only** file allowed to change `items.quantity` and `items.averageCost` —
/// always in the same transaction as the movement that explains the change.
class MovementRepository {
  const MovementRepository(this._db);

  final AppDatabase _db;

  /// Everything that moved in this establishment, newest first.
  Stream<List<StockMovement>> watchMovementsForStore(String storeId) =>
      _forStore(storeId).watch().map(_toMovements);

  Future<List<StockMovement>> movementsForStore(String storeId) =>
      _forStore(storeId).get().then(_toMovements);

  /// One article's history, newest first — the item detail timeline.
  Stream<List<StockMovement>> watchMovementsForItem(String itemId) =>
      _forItem(itemId).watch().map(_toMovements);

  Future<List<StockMovement>> movementsForItem(String itemId) =>
      _forItem(itemId).get().then(_toMovements);

  /// The dashboard's activity feed.
  Stream<List<StockMovement>> watchRecentActivity(
    String storeId, {
    int limit = 8,
  }) => (_forStore(storeId)..limit(limit)).watch().map(_toMovements);

  Future<List<StockMovement>> recentActivity(String storeId, {int limit = 8}) =>
      (_forStore(storeId)..limit(limit)).get().then(_toMovements);

  // ---------------------------------------------------------------------------

  /// Newest first, ties broken by id descending.
  ///
  /// The tiebreak is not decoration. Receiving a delivery writes one movement
  /// per line inside a single transaction, so several land on the same instant;
  /// without a second key "the movement that was just recorded" is whichever one
  /// SQLite happened to return, and a screen showing the top of this list would
  /// disagree with itself between rebuilds.
  ///
  /// Phase 1 got away with `insert(0, ...)` into a list. A table has no such
  /// memory, which is why the order has to be stated.
  SimpleSelectStatement<$StockMovementsTable, StockMovementRow> _forStore(
    String storeId,
  ) => _db.select(_db.stockMovements)
    ..where((m) => m.storeId.equals(storeId))
    ..orderBy(_newestFirst);

  SimpleSelectStatement<$StockMovementsTable, StockMovementRow> _forItem(
    String itemId,
  ) => _db.select(_db.stockMovements)
    ..where((m) => m.itemId.equals(itemId))
    ..orderBy(_newestFirst);

  static final List<OrderClauseGenerator<$StockMovementsTable>> _newestFirst =
      <OrderClauseGenerator<$StockMovementsTable>>[
        (m) => OrderingTerm(expression: m.occurredAt, mode: OrderingMode.desc),
        (m) => OrderingTerm(expression: m.id, mode: OrderingMode.desc),
      ];

  List<StockMovement> _toMovements(List<StockMovementRow> rows) =>
      rows.map(movementFromRow).toList();
}
