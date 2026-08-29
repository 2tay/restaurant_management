import 'package:drift/drift.dart';

import '../../core/utils/stock_cost.dart';
import '../../models/item.dart';
import '../../models/stock_movement.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'account_repository.dart';
import 'new_id.dart';

/// The stock movement log.
///
/// **This is the only file in the app that changes an item's quantity, and the
/// only one that changes its average cost.** Every other path — a delivery
/// received against a commande, a manual stock-in, a stock-out mid-service, a
/// physical count, the opening balance on a brand-new article — comes through
/// here and leaves a movement behind.
///
/// That single-writer rule is what makes the movement history mean something.
/// If a screen could set a quantity directly, "quantity equals opening balance
/// plus the sum of its movements" would stop holding, and the log would become a
/// partial record that looks complete — worse than no log at all.
/// `tool/ux_audit.py` enforces it mechanically.
///
/// Cost is held to the same standard. `Item.averageCost` is path-dependent — it
/// depends on the order deliveries happened in — so it is stored rather than
/// derived, and storing a running total is only safe while exactly one place
/// advances it. Every movement records both the cost it applied and the average
/// it produced, so the number stays auditable and rebuildable.
///
/// The arithmetic lives in `core/utils/stock_cost.dart` and is used here
/// unchanged, so it can be tested without writing to anything.
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
  // Writes — the only place quantity and average cost move
  // ---------------------------------------------------------------------------

  /// A delivery arriving.
  ///
  /// [orderId] and [receiptId] are set when this came from receiving a commande,
  /// and null when somebody bought 5 kg of tomatoes at the market on the way in.
  /// Both paths are legitimate and both land in the same log.
  Future<StockMovement> recordStockIn({
    required String storeId,
    required String itemId,
    required double quantity,
    String? supplierId,
    double? unitPrice,
    DateTime? occurredAt,
    String? userName,
    String? orderId,
    String? receiptId,
    String? note,
  }) async {
    return _record(
      StockMovement(
        id: newId(),
        storeId: storeId,
        itemId: itemId,
        type: StockMovementType.stockIn,
        quantity: quantity.abs(),
        occurredAt: occurredAt ?? DateTime.now(),
        userName: userName ?? await _defaultUserName(),
        supplierId: supplierId,
        unitPrice: unitPrice,
        orderId: orderId,
        receiptId: receiptId,
        note: note,
      ),
    );
  }

  /// Stock consumed or lost.
  ///
  /// The quantity is stored negative whatever sign the caller passes, so the log
  /// always adds up.
  ///
  /// **Nothing stops this taking an item below zero, deliberately.** Refusing
  /// would make staff either lie to the app or give up on it, and negative stock
  /// is a useful signal in its own right — it means a delivery went unrecorded.
  /// The stock-out screen warns before submitting; the adjustment screen is how
  /// it gets put right.
  Future<StockMovement> recordStockOut({
    required String storeId,
    required String itemId,
    required double quantity,
    required StockOutReason reason,
    DateTime? occurredAt,
    String? userName,
    String? note,
  }) async {
    return _record(
      StockMovement(
        id: newId(),
        storeId: storeId,
        itemId: itemId,
        type: StockMovementType.stockOut,
        quantity: -quantity.abs(),
        occurredAt: occurredAt ?? DateTime.now(),
        userName: userName ?? await _defaultUserName(),
        reason: reason,
        note: note,
      ),
    );
  }

  /// A physical count disagreed with the system and the system was corrected.
  ///
  /// Carries both figures rather than only the difference, because "we thought
  /// 40, we counted 31" is the useful record and "-9" on its own is not.
  ///
  /// [unitCost] is normally left alone: a count corrects a quantity, not a
  /// price, so units found or missing move at whatever the stock already cost.
  /// It is offered only for the opening balance, where the article has no cost
  /// yet and there is nothing to preserve.
  Future<StockMovement> recordAdjustment({
    required String storeId,
    required String itemId,
    required double systemQuantity,
    required double countedQuantity,
    DateTime? occurredAt,
    String? userName,
    double? unitCost,
    String? note,
  }) async {
    return _record(
      StockMovement(
        id: newId(),
        storeId: storeId,
        itemId: itemId,
        type: StockMovementType.adjustment,
        // Signed by the direction of the correction, so the movement still sums
        // correctly against the item's quantity.
        quantity: countedQuantity - systemQuantity,
        occurredAt: occurredAt ?? DateTime.now(),
        userName: userName ?? await _defaultUserName(),
        systemQuantity: systemQuantity,
        countedQuantity: countedQuantity,
        unitCost: unitCost,
        note: note,
      ),
    );
  }

  /// The stock a brand-new article starts with.
  ///
  /// Recorded as an adjustment from zero rather than written straight onto the
  /// article. Creating one with 40 kg in it *is* a stock change, and if the form
  /// set the number directly the movement log would be incomplete from the
  /// article's first day. It also means a new article's history opens with a
  /// line explaining where its stock came from, instead of an unexplained 40
  /// with no entries — which reads as a bug.
  ///
  /// [unitCost] is what that opening stock was bought at, and it is the one
  /// adjustment permitted to set an article's cost: there is no earlier cost for
  /// it to overwrite. Null leaves the cost unknown, and the article contributes
  /// nothing to the valuation until a real delivery arrives. Understating beats
  /// inventing.
  ///
  /// Returns null for a zero quantity — an article that starts empty starts with
  /// no history rather than with a movement that moved nothing.
  Future<StockMovement?> recordOpeningBalance({
    required String storeId,
    required String itemId,
    required double quantity,
    double? unitCost,
    String? userName,
    String? note,
  }) async {
    if (quantity == 0) return null;
    return recordAdjustment(
      storeId: storeId,
      itemId: itemId,
      systemQuantity: 0,
      countedQuantity: quantity,
      userName: userName,
      unitCost: unitCost,
      note: note,
    );
  }

  // ---------------------------------------------------------------------------

  /// Files the movement and moves the stock, as one transaction.
  ///
  /// The read of the article and the write back to it happen **inside** the
  /// transaction. Phase 1 could read a list element and write it back a line
  /// later with nothing in between; here two stock-outs from a double-tapped
  /// button are genuinely concurrent futures, and a read outside the transaction
  /// would let the second one apply to a quantity the first had already changed.
  ///
  /// It nests: `confirmReceipt` opens a transaction and calls this once per
  /// line, and drift turns the inner ones into savepoints. That is what makes a
  /// half-applied delivery impossible rather than merely unlikely.
  Future<StockMovement> _record(StockMovement draft) {
    return _db.transaction(() async {
      final row =
          await (_db.select(_db.items)
                ..where((i) => i.id.equals(draft.itemId)))
              .getSingleOrNull();

      if (row == null) {
        // Phase 1 filed the movement anyway, with no cost figures, because a
        // list cannot refuse. A foreign key can, and this says so in words
        // rather than as a constraint violation from three frames down.
        throw StateError(
          'No article ${draft.itemId} to move stock for. A movement without an '
          'article is not a record of anything.',
        );
      }

      final item = itemFromRow(row);
      final applied = _costOf(item, draft);

      // The cost is worked out from the quantity *before* the movement is
      // applied, because that is what the weighted average averages against.
      // The other way round produces numbers that look entirely plausible and
      // are wrong, which is the worst way for a money figure to fail.
      await (_db.update(_db.items)..where((i) => i.id.equals(item.id))).write(
        ItemsCompanion(
          quantity: Value(item.quantity + draft.quantity),
          updatedAt: Value(draft.occurredAt),
          // Absent rather than null when the cost is still unknown, mirroring
          // the `copyWith` this replaces: an average that was never known is
          // left alone rather than written as null over itself.
          averageCost: applied.averageCost == null
              ? const Value.absent()
              : Value(applied.averageCost),
        ),
      );

      final recorded = StockMovement(
        id: draft.id,
        storeId: draft.storeId,
        itemId: draft.itemId,
        type: draft.type,
        quantity: draft.quantity,
        occurredAt: draft.occurredAt,
        userName: draft.userName,
        supplierId: draft.supplierId,
        unitPrice: draft.unitPrice,
        reason: draft.reason,
        systemQuantity: draft.systemQuantity,
        countedQuantity: draft.countedQuantity,
        unitCost: applied.unitCost,
        averageCostAfter: applied.averageCost,
        orderId: draft.orderId,
        receiptId: draft.receiptId,
        note: draft.note,
      );

      await _db.into(_db.stockMovements).insert(movementToRow(recorded));
      return recorded;
    });
  }

  /// What this movement does to the article's cost, and at what unit cost.
  _AppliedCost _costOf(Item item, StockMovement movement) {
    switch (movement.type) {
      case StockMovementType.stockIn:
        // A delivery with no price recorded is not a free delivery, it is an
        // unrecorded price. Falling back to what the stock already cost leaves
        // the average where it was rather than dragging it towards zero, which
        // would quietly destroy the article's value.
        final unitCost = movement.unitPrice ?? item.averageCost;
        if (unitCost == null) return const _AppliedCost(null, null);

        return _AppliedCost(
          costAfterStockIn(
            oldQuantity: item.quantity,
            oldAverageCost: item.averageCost,
            inQuantity: movement.quantity,
            inUnitPrice: unitCost,
          ),
          unitCost,
        );

      case StockMovementType.stockOut:
        // Unchanged, always. What left is valued at what it cost, which is what
        // makes a waste line answer "how many euros went in the bin".
        return _AppliedCost(
          costAfterStockOut(item.averageCost),
          item.averageCost,
        );

      case StockMovementType.adjustment:
        // Also unchanged — no invoice was involved — except on an article whose
        // cost is still unknown, where there is nothing to preserve. That is the
        // opening balance, and the rule is stated in `stock_cost.dart` rather
        // than special-cased for one caller.
        final cost = costAfterAdjustmentWithOpening(
          oldAverageCost: item.averageCost,
          unitCost: movement.unitCost,
        );
        return _AppliedCost(cost, cost);
    }
  }

  Future<String> _defaultUserName() => AccountRepository(_db).currentUserName();
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

/// The cost figures a movement produced, on their way onto the movement.
class _AppliedCost {
  const _AppliedCost(this.averageCost, this.unitCost);

  /// The article's average once the movement landed.
  final double? averageCost;

  /// The cost per unit this movement itself applied.
  final double? unitCost;
}
