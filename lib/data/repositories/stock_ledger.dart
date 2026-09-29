import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/utils/stock_cost.dart';
import '../../models/stock_movement.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'sync_quiet.dart';

/// What one movement does to an article's cost, and the unit cost it applied.
///
/// The rule [MovementRepository] applies when it files a movement, and the one
/// [StockLedger] replays. One function, so the live path and the rebuild
/// cannot drift apart.
///
/// [quantityBefore] and [averageCostBefore] are the article's figures before
/// the movement lands, which is what the weighted average averages against.
AppliedCost appliedCostOf({
  required double quantityBefore,
  required double? averageCostBefore,
  required StockMovement movement,
}) {
  switch (movement.type) {
    case StockMovementType.stockIn:
      // A delivery with no price recorded is not a free delivery, it is an
      // unrecorded price. Falling back to what the stock already cost leaves
      // the average where it was rather than dragging it towards zero, which
      // would quietly destroy the article's value.
      final unitCost = movement.unitPrice ?? averageCostBefore;
      if (unitCost == null) return const AppliedCost(null, null);

      return AppliedCost(
        costAfterStockIn(
          oldQuantity: quantityBefore,
          oldAverageCost: averageCostBefore,
          inQuantity: movement.quantity,
          inUnitPrice: unitCost,
        ),
        unitCost,
      );

    case StockMovementType.stockOut:
      // Unchanged, always. What left is valued at what it cost, which is what
      // makes a waste line answer "how many euros went in the bin".
      return AppliedCost(
        costAfterStockOut(averageCostBefore),
        averageCostBefore,
      );

    case StockMovementType.adjustment:
      // Also unchanged — no invoice was involved — except on an article whose
      // cost is still unknown, where there is nothing to preserve. That is the
      // opening balance, and the rule is stated in `stock_cost.dart` rather
      // than special-cased for one caller.
      //
      // `movement.unitCost` is an input here, the opening cost somebody typed.
      // Once filed it holds the cost the adjustment applied, which is the same
      // number whenever the input mattered: an input only counts while the
      // average is unknown, and then the applied cost *is* the input. That is
      // what lets a replay read it back.
      final cost = costAfterAdjustmentWithOpening(
        oldAverageCost: averageCostBefore,
        unitCost: movement.unitCost,
      );
      return AppliedCost(cost, cost);
  }
}

/// The cost figures a movement produced, on their way onto the movement.
class AppliedCost {
  const AppliedCost(this.averageCost, this.unitCost);

  /// The article's average once the movement landed. Null only when it was
  /// already unknown and the movement did not make it known.
  final double? averageCost;

  /// The cost per unit this movement itself applied.
  final double? unitCost;
}

/// Rebuilds an article's stock and cost from its movement log.
///
/// An article's `quantity` and `averageCost` are derived figures: its baseline
/// (`Items.baselineQuantity`, `Items.baselineAverageCost`) with every movement
/// not already in that baseline replayed on top, oldest first. The movement
/// repository keeps them current as it files movements, one at a time. This
/// recomputes them from scratch.
///
/// That matters once movements arrive from other devices (SYNC_PLAN.md,
/// Phase 6). The quantity is a plain sum, so arrival order cannot change it.
/// The average cost is a weighted average, so it can: a delivery recorded on a
/// tablet that was offline lands here after later movements were already
/// applied. Replaying in `occurredAt` order gives every device the same answer.
///
/// The replay also rewrites each movement's `unitCost` and `averageCostAfter`,
/// the audit trail of the average, so the log keeps explaining the figure.
///
/// ## A count is absolute at its own time
///
/// A physical count (an adjustment) records what somebody saw on the shelf:
/// `countedQuantity`. Its `quantity` is only the difference from what the
/// system believed then, `systemQuantity`. On one device the two readings
/// agree. Across devices they do not: a tablet counting 10 kg does not know
/// that another tablet recorded 3 kg going out a minute earlier.
///
/// So the replay treats the count as the truth at its moment. Reaching an
/// adjustment, it sets the stock to `countedQuantity` and rewrites the
/// movement's `systemQuantity` and `quantity` to match the history it now
/// knows. With 12 kg on file, a count of 10, and 3 kg out on another tablet:
///
/// * 3 kg out **before** the count: 12, 9, then counted 10. The count saw
///   the shelf after the 3 kg left, so 10 is right.
/// * 3 kg out **after** the count: 12, counted 10, then 7.
///
/// Adding the stored difference instead would give 7 both times, and the
/// first is wrong: the 3 kg would be taken off twice.
///
/// Ties on `occurredAt` break on `id`, the same order the history screen uses.
class StockLedger {
  const StockLedger(this._db);

  final AppDatabase _db;

  /// Replays one article. Returns whether anything was written: false for a
  /// missing or deleted article, and for one whose figures were already right.
  ///
  /// Quiet (see [SyncQuiet]): the figures it writes are ones every device
  /// recomputes for itself, so they are not changes to send.
  Future<bool> rebuildItem(String itemId) {
    return SyncQuiet.run(_db, () async {
      final item = await (_db.select(_db.items)
            ..where((i) => i.id.equals(itemId) & i.deletedAt.isNull()))
          .getSingleOrNull();
      if (item == null) return false;

      final rows = await (_db.select(_db.stockMovements)
            ..where(
              (m) =>
                  m.itemId.equals(itemId) &
                  m.deletedAt.isNull() &
                  m.inBaseline.equals(false),
            )
            ..orderBy([
              (m) => OrderingTerm(expression: m.occurredAt),
              (m) => OrderingTerm(expression: m.id),
            ]))
          .get();

      var quantity = item.baselineQuantity;
      var averageCost = item.baselineAverageCost;
      DateTime? lastMovedAt;
      var wrote = false;

      for (final row in rows) {
        final applied = appliedCostOf(
          quantityBefore: quantity,
          averageCostBefore: averageCost,
          movement: movementFromRow(row),
        );

        // A count sets the stock to what was counted; see the class comment.
        final counted = row.type == StockMovementType.adjustment
            ? row.countedQuantity
            : null;
        final delta = counted == null ? row.quantity : counted - quantity;

        final countChanged =
            counted != null &&
            (!_same(row.quantity, delta) ||
                !_same(row.systemQuantity, quantity));
        if (countChanged ||
            !_same(row.unitCost, applied.unitCost) ||
            !_same(row.averageCostAfter, applied.averageCost)) {
          await (_db.update(
            _db.stockMovements,
          )..where((m) => m.id.equals(row.id))).write(
            StockMovementsCompanion(
              quantity: counted == null ? const Value.absent() : Value(delta),
              systemQuantity: counted == null
                  ? const Value.absent()
                  : Value(quantity),
              unitCost: Value(applied.unitCost),
              averageCostAfter: Value(applied.averageCost),
            ),
          );
          wrote = true;
        }

        quantity += delta;
        averageCost = applied.averageCost ?? averageCost;
        lastMovedAt = row.occurredAt;
      }

      if (!_same(item.quantity, quantity) ||
          !_same(item.averageCost, averageCost)) {
        await (_db.update(
          _db.items,
        )..where((i) => i.id.equals(itemId))).write(
          ItemsCompanion(
            quantity: Value(quantity),
            averageCost: Value(averageCost),
            // What the movement repository stamps: the time of the movement
            // that last moved the stock.
            updatedAt: Value(lastMovedAt ?? clock.now()),
          ),
        );
        wrote = true;
      }
      return wrote;
    });
  }

  /// Replays several articles. Returns the ids whose figures changed.
  Future<Set<String>> rebuildItems(Iterable<String> itemIds) async {
    final changed = <String>{};
    for (final id in itemIds.toSet()) {
      if (await rebuildItem(id)) changed.add(id);
    }
    return changed;
  }

  /// Replays every article of an establishment.
  Future<Set<String>> rebuildStore(String storeId) async {
    final ids = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.id])
          ..where(_db.items.storeId.equals(storeId) & _db.items.deletedAt.isNull()))
        .map((row) => row.read(_db.items.id)!)
        .get();
    return rebuildItems(ids);
  }

  /// Equal to well within a cent. Floating-point sums replayed in the same
  /// order come out identical; this only stops a rewrite over rounding noise.
  static bool _same(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a - b).abs() < 1e-9;
  }
}
