import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/order_status.dart';
import '../../models/notification_item.dart';
import '../../models/purchase_order.dart';
import '../database/app_database.dart';
import '../mappers/mappers.dart';
import 'account_repository.dart';
import 'sync_quiet.dart';

/// A commande's received quantities, worked out from its receipts
/// (SYNC_TESTS.md, findings F6 and F7).
///
/// A commande line holds "received so far" as one number, and a line is one
/// row: when two tablets offline each receive part of a commande, each adds
/// its own delivery to the number it knows, and the last one to reach the
/// server replaces the other. The receipts themselves are add-only and never
/// lost. So, like the stock in [StockLedger], every tablet recomputes the
/// lines from the receipts it holds after receiving rows, and gets the same
/// answer as every other tablet.
///
/// Quiet ([SyncQuiet]): every tablet recomputes for itself, so these writes
/// are not changes to send. `OrderRepository.confirmReceipt` keeps adding a
/// delivery to the lines directly, which gives the same numbers on the
/// tablet that received it.
///
/// It also spots **one delivery confirmed on two tablets** (F7). Each
/// receipt line keeps what was still outstanding when the van arrived. Two
/// tablets that did not see each other's receipt saw the same outstanding
/// quantity; when their receipts together bring in more than that, it may be
/// the same van recorded twice. Nothing is undone — a second van is possible
/// — but a manager is told, once, on every tablet.
class OrderLedger {
  OrderLedger(this._db);

  final AppDatabase _db;

  /// Recomputes [orderIds] and signals any delivery received twice. Returns
  /// the ids of the commandes whose lines or status changed.
  Future<Set<String>> rebuildOrders(Iterable<String> orderIds) async {
    final changed = <String>{};
    for (final id in orderIds.toSet()) {
      if (await rebuildOrder(id)) changed.add(id);
      await signalDoubleReceipts(id);
    }
    return changed;
  }

  /// Sets each line's received quantity to what the commande's receipts add
  /// up to, and an open commande's status to what its lines then imply.
  /// Returns whether anything was written.
  Future<bool> rebuildOrder(String orderId) {
    return SyncQuiet.run(_db, () async {
      final order =
          await (_db.select(_db.purchaseOrders)
                ..where((o) => o.id.equals(orderId) & o.deletedAt.isNull()))
              .getSingleOrNull();
      if (order == null) return false;

      final receipts = await _receiptLines(orderId);
      if (receipts.isEmpty) return false;

      final received = <String, double>{};
      final closedShort = <String>{};
      for (final (:line, receipt: _) in receipts) {
        if (line.wasUnordered) continue;
        received[line.itemId] =
            (received[line.itemId] ?? 0) + line.quantityReceived;
        if (line.closedShort) closedShort.add(line.itemId);
      }

      final lineRows =
          await (_db.select(_db.purchaseOrderLines)
                ..where((l) => l.orderId.equals(orderId) & l.deletedAt.isNull())
                ..orderBy([(l) => OrderingTerm(expression: l.position)]))
              .get();

      var wrote = false;
      final lines = [
        for (final row in lineRows)
          orderLineFromRow(row).copyWith(
            quantityReceived: received[row.itemId] ?? 0,
            // A line closed short on the commande itself, with no receipt
            // saying so, stays closed.
            closedShort: row.closedShort || closedShort.contains(row.itemId),
          ),
      ];
      for (final (index, line) in lines.indexed) {
        final row = lineRows[index];
        if (_same(row.quantityReceived, line.quantityReceived) &&
            row.closedShort == line.closedShort) {
          continue;
        }
        await (_db.update(
          _db.purchaseOrderLines,
        )..where((l) => l.id.equals(row.id))).write(
          PurchaseOrderLinesCompanion(
            quantityReceived: Value(line.quantityReceived),
            closedShort: Value(line.closedShort),
          ),
        );
        wrote = true;
      }

      // Only an open commande follows its lines: a draft has no receipts,
      // and a received or cancelled one is closed for good (the server's
      // rule too).
      if (order.status == PurchaseOrderStatus.sent ||
          order.status == PurchaseOrderStatus.partial) {
        final status = statusAfterReceipt(lines);
        if (status != order.status) {
          final lastReceipt = receipts
              .map((r) => r.receipt.receivedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          await (_db.update(
            _db.purchaseOrders,
          )..where((o) => o.id.equals(orderId))).write(
            PurchaseOrdersCompanion(
              status: Value(status),
              closedAt: Value(
                status == PurchaseOrderStatus.received ? lastReceipt : null,
              ),
            ),
          );
          wrote = true;
        }
      }
      return wrote;
    });
  }

  /// Signals each article of [orderId] that two or more receipts brought in
  /// while seeing the same outstanding quantity, for more than that quantity.
  /// Returns how many signals this tablet filed for the first time.
  Future<int> signalDoubleReceipts(String orderId) async {
    final order =
        await (_db.select(_db.purchaseOrders)
              ..where((o) => o.id.equals(orderId) & o.deletedAt.isNull()))
            .getSingleOrNull();
    if (order == null) return 0;

    // Per article and outstanding quantity seen: the receipt lines.
    final groups = <(String, double), List<_ReceiptLine>>{};
    for (final entry in await _receiptLines(orderId)) {
      final line = entry.line;
      if (line.wasUnordered || line.quantityReceived <= 0) continue;
      (groups[(line.itemId, line.quantityOrdered)] ??= []).add(entry);
    }

    var filed = 0;
    for (final MapEntry(key: (itemId, outstanding), value: entries)
        in groups.entries) {
      final receiptIds = {for (final e in entries) e.receipt.id};
      if (receiptIds.length < 2) continue;
      final total = entries.fold<double>(
        0,
        (sum, e) => sum + e.line.quantityReceived,
      );
      if (total <= outstanding + _epsilon) continue;

      if (await _signal(order, itemId, outstanding, entries)) filed++;
    }
    return filed;
  }

  Future<bool> _signal(
    PurchaseOrderRow order,
    String itemId,
    double outstanding,
    List<_ReceiptLine> entries,
  ) async {
    final item = await (_db.select(
      _db.items,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    final unit = item == null
        ? null
        : await (_db.select(
            _db.units,
          )..where((u) => u.id.equals(item.unitId))).getSingleOrNull();
    final abbreviation = unit?.abbreviation ?? '';
    String qty(double q) => Formatters.quantityWithUnit(q, abbreviation);

    final sorted = [...entries]
      ..sort((a, b) => a.receipt.receivedAt.compareTo(b.receipt.receivedAt));
    final who = [
      for (final e in sorted)
        '${qty(e.line.quantityReceived)} par ${e.receipt.receivedByName}',
    ];
    final name = item?.name ?? '';
    final title = 'Réception en double ? $name';
    final body =
        'Commande ${order.reference} : ${name.isEmpty ? 'un article' : name} '
        'a été reçu ${sorted.length} fois sur des tablettes différentes '
        '(${who.join(', ')}), alors que ${qty(outstanding)} étaient attendus. '
        'Si c\'est la même livraison, corrigez le stock par un comptage.';

    // One key per commande, article and outstanding quantity: every tablet
    // files the same row, and a third receipt rewords it.
    final id = AccountRepository.signalId(
      'double_receipt:${order.id}:$itemId:$outstanding',
    );
    final existing = await (_db.select(
      _db.notifications,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    if (existing == null || existing.body != body) {
      await SyncQuiet.loud(_db, () async {
        if (existing != null) {
          await (_db.update(
            _db.notifications,
          )..where((n) => n.id.equals(id))).write(
            NotificationsCompanion(title: Value(title), body: Value(body)),
          );
        } else {
          await _db
              .into(_db.notifications)
              .insert(
                NotificationsCompanion.insert(
                  id: id,
                  storeId: order.storeId,
                  kind: NotificationKind.delivery,
                  title: title,
                  body: body,
                  createdAt: clock.now(),
                  relatedItemId: Value(itemId),
                ),
              );
        }
      });
    }

    // The sync page notes it once per tablet, whichever tablet filed the
    // alert first — and not again once someone dismissed it there. The mark
    // is this tablet's own (`meta` never syncs).
    final mark = 'doubleReceiptNoted:$id';
    final noted = await (_db.select(
      _db.meta,
    )..where((m) => m.key.equals(mark))).getSingleOrNull();
    if (noted != null) return false;
    await _db
        .into(_db.meta)
        .insert(MetaCompanion.insert(key: mark, value: '1'));

    await _db
        .into(_db.syncErrors)
        .insert(
          SyncErrorsCompanion.insert(
            changedTable: 'goods_receipts',
            rowKey: id,
            storeId: order.storeId,
            payload: jsonEncode({
              'reference': order.reference,
              'item': name,
              'times': sorted.length,
            }),
            reason: 'resolved_double_receipt',
            rejectedAt: DateTime.now().toUtc(),
          ),
        );
    return true;
  }

  /// Every live receipt line of [orderId], with its receipt.
  Future<List<_ReceiptLine>> _receiptLines(String orderId) async {
    final query =
        _db.select(_db.goodsReceiptLines).join([
          innerJoin(
            _db.goodsReceipts,
            _db.goodsReceipts.id.equalsExp(_db.goodsReceiptLines.receiptId),
          ),
        ])..where(
          _db.goodsReceipts.orderId.equals(orderId) &
              _db.goodsReceipts.deletedAt.isNull() &
              _db.goodsReceiptLines.deletedAt.isNull(),
        );
    return [
      for (final row in await query.get())
        (
          line: row.readTable(_db.goodsReceiptLines),
          receipt: row.readTable(_db.goodsReceipts),
        ),
    ];
  }

  static const double _epsilon = 1e-9;

  static bool _same(double a, double b) => (a - b).abs() < _epsilon;
}

typedef _ReceiptLine = ({GoodsReceiptLineRow line, GoodsReceiptRow receipt});
