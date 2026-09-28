import '../../core/utils/formatters.dart';
import '../../models/item.dart';
import '../../models/notification_item.dart';
import '../database/app_database.dart';
import '../repositories/account_repository.dart';

/// What turns the notification centre from a seeded list into a record of what
/// happened.
///
/// Until now nothing in the app ever wrote a notification: the feed held ten
/// rows from `seed/dataset/notifications.dart` and the bell counted them
/// forever. This is the other half — the repositories call in after a write has
/// succeeded, and the engine decides whether that event is worth saying out
/// loud.
///
/// Three rules, and they are the whole design:
///
/// - **The preference is checked before anything is composed.** A kind switched
///   off produces no row at all. Filtering the feed instead would leave the
///   notification unread on the bell, which is the opposite of what the switch
///   promises.
/// - **Only transitions are notified.** Stock that is already low does not
///   re-announce itself every service; see [stockMoved].
/// - **A failure here never fails the write.** Every entry point swallows its
///   own errors: a delivery that was received is received, and a feed entry that
///   could not be filed is not a reason to roll it back. That is deliberate, and
///   it is the only place in this codebase where an exception is dropped.
///
/// Called from inside the caller's transaction, so a rolled-back movement takes
/// its notification with it.
class NotificationEngine {
  const NotificationEngine(this._db);

  final AppDatabase _db;

  /// An article's quantity changed. Notifies only the crossing.
  ///
  /// [before] is the article as it stood, [after] the quantity it now holds.
  /// "Was above the line, is now at or under it" is the whole test: an article
  /// that was already low stays quiet, which is what stops one struggling
  /// product from owning the feed.
  ///
  /// Hitting zero outranks going low — an article at zero is not "also low", it
  /// is out, and it gets the one notification that says so.
  Future<void> stockMoved({required Item before, required double after}) async {
    await _guard(() async {
      if (!await _allows(before.storeId, (row) => row.notifyLowStock)) return;

      final wasOut = before.quantity <= 0;
      final isOut = after <= 0;
      final wasLow = before.quantity <= before.lowStockThreshold;
      final isLow = after <= before.lowStockThreshold;

      final unit = await _unitOf(before.unitId);
      final account = AccountRepository(_db);

      if (isOut && !wasOut) {
        await account.emit(
          storeId: before.storeId,
          kind: NotificationKind.outOfStock,
          title: 'Rupture de stock : ${before.name}',
          body:
              'Il ne reste plus de ${_lower(before.name)}. Seuil : '
              '${Formatters.quantityWithUnit(before.lowStockThreshold, unit)}.',
          relatedItemId: before.id,
        );
        return;
      }

      if (isLow && !wasLow) {
        await account.emit(
          storeId: before.storeId,
          kind: NotificationKind.lowStock,
          title: 'Stock faible : ${before.name}',
          body:
              'Il reste ${Formatters.quantityWithUnit(after, unit)}, sous le '
              'seuil de '
              '${Formatters.quantityWithUnit(before.lowStockThreshold, unit)}.',
          relatedItemId: before.id,
        );
      }
    });
  }

  /// A physical count disagreed with the system by enough to be worth a second
  /// look.
  ///
  /// "Enough" is a fifth of what was on the shelf, and never less than a whole
  /// unit: a proportion alone would flag half a gram off two grams of saffron,
  /// and a fixed quantity alone would flag two kilos off four hundred.
  Future<void> adjustmentRecorded({
    required Item before,
    required double systemQuantity,
    required double countedQuantity,
  }) async {
    await _guard(() async {
      if (!await _allows(before.storeId, (row) => row.notifyLargeAdjustment)) {
        return;
      }

      // An opening balance is recorded as a count from zero on an article that
      // held zero — `recordOpeningBalance` goes through the same path. It is
      // not a discrepancy: there was nothing for the count to disagree with,
      // and flagging it would greet every new article with a warning.
      if (systemQuantity == 0 && before.quantity == 0) return;

      final delta = countedQuantity - systemQuantity;
      final magnitude = delta.abs();
      if (magnitude < 1) return;
      if (systemQuantity > 0 && magnitude < systemQuantity * 0.2) return;

      final unit = await _unitOf(before.unitId);
      await AccountRepository(_db).emit(
        storeId: before.storeId,
        kind: NotificationKind.largeAdjustment,
        title: 'Ajustement important : ${before.name}',
        body:
            'Comptage physique '
            '${Formatters.quantityWithUnit(countedQuantity, unit)} contre '
            '${Formatters.quantityWithUnit(systemQuantity, unit)} au système, '
            'soit ${Formatters.quantityDelta(delta, unit)}.',
        relatedItemId: before.id,
      );
    });
  }

  /// A supplier's price for an article moved.
  ///
  /// The one notification this app exists to provide: forty cents on a kilo is
  /// invisible on an invoice and material over a quarter. Both directions are
  /// reported — a drop is as worth knowing as a rise, and only one of them is
  /// bad news.
  Future<void> priceChanged({
    required String storeId,
    required String itemId,
    required String itemName,
    required String supplierId,
    required String supplierName,
    required double from,
    required double to,
    required String unitAbbreviation,
  }) async {
    await _guard(() async {
      if (from == to) return;
      if (!await _allows(storeId, (row) => row.notifyPriceChange)) return;

      // A price that starts at zero has no percentage to report — it was not
      // really a price, it was a blank.
      final share = from > 0 ? (to - from) / from * 100 : null;
      final movement = share == null
          ? ''
          : ', soit ${Formatters.priceDelta(share)} %';

      await AccountRepository(_db).emit(
        storeId: storeId,
        kind: NotificationKind.priceChange,
        title: '${to > from ? 'Hausse' : 'Baisse'} de prix : $itemName',
        body:
            '$supplierName est passé de ${Formatters.price(from)} à '
            '${Formatters.price(to)} le $unitAbbreviation$movement.',
        relatedItemId: itemId,
        relatedSupplierId: supplierId,
      );
    });
  }

  /// A delivery was received against a commande.
  ///
  /// One notification per delivery, not per line — a receipt of twenty articles
  /// is one thing that happened. Off by default, and short-windowed, because
  /// whoever is standing at the back door with the crates already knows.
  Future<void> deliveryReceived({
    required String storeId,
    required String supplierId,
    required String supplierName,
    required int lineCount,
    required String receivedBy,
  }) async {
    await _guard(() async {
      if (!await _allows(storeId, (row) => row.notifyDeliveries)) return;

      await AccountRepository(_db).emit(
        storeId: storeId,
        kind: NotificationKind.delivery,
        title: 'Livraison enregistrée',
        body: '$supplierName — $lineCount produits reçus par $receivedBy.',
        relatedSupplierId: supplierId,
        // Two deliveries from two suppliers in the same hour are two events,
        // and this kind carries no article to tell them apart — so the window
        // is only long enough to swallow a double-tapped confirmation.
        window: const Duration(minutes: 2),
      );
    });
  }

  // ---------------------------------------------------------------------------

  /// Whether the establishment wants to hear about this kind of event.
  ///
  /// A store that has gone missing answers "no": there is nobody to tell.
  Future<bool> _allows(
    String storeId,
    bool Function(StoreRow) preference,
  ) async {
    final row = await (_db.select(
      _db.stores,
    )..where((s) => s.id.equals(storeId))).getSingleOrNull();
    return row != null && preference(row);
  }

  /// The unit's abbreviation — "kg", "bac" — which every quantity in the app is
  /// written with. Falls back to none rather than to a guess.
  Future<String> _unitOf(String unitId) async {
    final row = await (_db.select(
      _db.units,
    )..where((u) => u.id.equals(unitId))).getSingleOrNull();
    return row?.abbreviation ?? '';
  }

  /// Runs [body], and lets nothing out of it.
  ///
  /// See the class comment: the feed is a courtesy on top of the write, never a
  /// condition of it.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on Object {
      // Deliberately silent. There is no user-facing recovery for "the feed
      // entry could not be filed", and surfacing it would turn a delivery that
      // was received into a failure on screen.
    }
  }

  /// A product name as it reads mid-sentence.
  String _lower(String name) =>
      name.isEmpty ? name : name[0].toLowerCase() + name.substring(1);
}
