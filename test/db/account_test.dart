// Establishments and the notification feed.
//
// Ported from `test/account_test.dart` — same assertions, against a database
// instead of a list. The team was dropped from the database (that module still
// runs on `lib/mock_data/`), so those tests are gone; the establishment writes
// moved from `AccountMutations` to `StoreRepository`, where the reads already
// were, and "marking one already read changes nothing" checked a global
// revision counter that no longer exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart' show StoreIds;

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late AccountRepository account;
  late StoreRepository stores;

  setUp(() async {
    db = await openSeededDatabase();
    account = AccountRepository(db);
    stores = StoreRepository(db);
  });

  group('establishments', () {
    test('a new one starts genuinely empty', () async {
      final store = await stores.createStore(
        name: 'Friterie du Midi',
        addressLine: 'Chaussée de Mons 12',
        postalCode: '1070',
        city: 'Anderlecht',
        phone: '+32 2 555 00 00',
      );

      // Categories, units, articles and suppliers are all per-establishment by
      // design, so a new shop inherits nothing. What the user sees next is every
      // empty state in the app, doing its job.
      expect(await ItemRepository(db).items(store.id), isEmpty);
      expect(await CatalogRepository(db).categories(store.id), isEmpty);
      expect(await CatalogRepository(db).units(store.id), isEmpty);
      expect(await SupplierRepository(db).suppliers(store.id), isEmpty);
      expect(await OrderRepository(db).orders(store.id), isEmpty);
      expect(await ReportRepository(db).stockValuation(store.id), 0);
    });

    test('is reachable by id straight away', () async {
      final store = await stores.createStore(
        name: 'Friterie du Midi',
        addressLine: 'Chaussée de Mons 12',
        postalCode: '1070',
        city: 'Anderlecht',
        phone: '+32 2 555 00 00',
      );

      expect(await stores.store(store.id), isNotNull);
      expect((await stores.watchStoreOrFirst(store.id).first)!.id, store.id);
    });

    test('an edit keeps the id, so nothing routed by it breaks', () async {
      final updated = await stores.updateStore(
        StoreIds.sablon,
        name: 'Brasserie du Grand Sablon',
      );

      expect(updated!.id, StoreIds.sablon);
      expect(await ItemRepository(db).items(StoreIds.sablon), isNotEmpty);
    });

    test('clearing the VAT number is not the same as leaving it', () async {
      final before = (await stores.store(StoreIds.sablon))!.vatNumber;
      expect(before, isNotNull);

      // null leaves it alone.
      await stores.updateStore(StoreIds.sablon, city: 'Bruxelles');
      expect((await stores.store(StoreIds.sablon))!.vatNumber, before);

      // '' clears it — and so does whitespace, because an empty label on the
      // bon de réception reads as a rendering bug rather than a missing value.
      await stores.updateStore(StoreIds.sablon, vatNumber: '   ');
      expect((await stores.store(StoreIds.sablon))!.vatNumber, isNull);
    });

    test('the stale-order threshold is per establishment', () async {
      expect(await stores.stalePartialOrderDays(StoreIds.sablon), 7);

      expect(
        await stores.setStalePartialOrderDays(StoreIds.sablon, 21),
        isTrue,
      );

      expect(await stores.stalePartialOrderDays(StoreIds.sablon), 21);
      expect(
        await stores.stalePartialOrderDays(StoreIds.liege),
        7,
        reason: 'it was a mutable global in Phase 1, shared by every store',
      );
    });

    test('refuses a threshold that would flag everything or nothing', () async {
      expect(await stores.setStalePartialOrderDays(StoreIds.sablon, 0), isFalse);
      expect(
        await stores.setStalePartialOrderDays(StoreIds.sablon, -3),
        isFalse,
      );
      expect(await stores.stalePartialOrderDays(StoreIds.sablon), 7);
    });
  });

  group('notifications', () {
    test('marking one read lowers the unread count', () async {
      final unread = (await account.notifications(
        StoreIds.sablon,
      )).firstWhere((n) => !n.isRead);
      final before = await account.unreadNotificationCount(StoreIds.sablon);

      expect(await account.markRead(unread.id), isTrue);
      expect(await account.unreadNotificationCount(StoreIds.sablon), before - 1);
    });

    test('marking one already read changes nothing', () async {
      final unread = (await account.notifications(
        StoreIds.sablon,
      )).firstWhere((n) => !n.isRead);

      await account.markRead(unread.id);
      final before = await account.unreadNotificationCount(StoreIds.sablon);

      // Phase 1 asserted on a global revision counter here, which no longer
      // exists. The property that counter existed to provide is that a second
      // call reports no change and leaves the count where it was.
      expect(await account.markRead(unread.id), isFalse);
      expect(await account.unreadNotificationCount(StoreIds.sablon), before);
    });

    test('marking all read returns how many actually changed', () async {
      final before = await account.unreadNotificationCount(StoreIds.sablon);
      expect(before, greaterThan(0));

      expect(await account.markAllRead(StoreIds.sablon), before);
      expect(await account.unreadNotificationCount(StoreIds.sablon), 0);

      // Second time there is nothing to do, so the screen can stay quiet.
      expect(await account.markAllRead(StoreIds.sablon), 0);
    });

    test('marking all read leaves other establishments alone', () async {
      final otherBefore = await account.unreadNotificationCount(StoreIds.liege);

      await account.markAllRead(StoreIds.sablon);

      expect(await account.unreadNotificationCount(StoreIds.liege), otherBefore);
    });
  });
}
