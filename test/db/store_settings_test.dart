// Store settings and the session, against the database.
//
// Two small aggregates land together in Stage 7: the pointage / paie settings
// (a handful of columns on the establishment row) and the signed-in employee
// (one `meta` row). Ported from `mock_write_test.dart`'s "restores store
// settings" and from `mock_session.dart`'s round-trip.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/database/meta_keys.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart'
    show EmployeeIds, StoreIds;

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late StoreRepository stores;
  late SessionRepository session;

  setUp(() async {
    db = await openSeededDatabase();
    stores = StoreRepository(db);
    session = SessionRepository(db);
  });

  group('store settings', () {
    test('an edit persists and leaves the other fields alone', () async {
      final before = await stores.settings(StoreIds.sablon);

      final after = await stores.updateStoreSettings(
        StoreIds.sablon,
        maxBreakMinutes: 90,
        overtimeMultiplier: 2,
      );

      expect(after.maxBreakMinutes, 90);
      expect(after.overtimeMultiplier, 2);
      expect(after.openMinutes, before.openMinutes);
      expect(after.workingDaysPerMonth, before.workingDaysPerMonth);
      expect(after.stalePartialOrderDays, before.stalePartialOrderDays);

      // Reads back the same on a fresh query.
      expect(
        (await stores.settings(StoreIds.sablon)).maxBreakMinutes,
        90,
      );
    });

    test('a nonsense value is ignored, not stored', () async {
      final before = await stores.settings(StoreIds.sablon);

      final after = await stores.updateStoreSettings(
        StoreIds.sablon,
        openMinutes: -1,
        closeMinutes: 1440,
        maxBreakMinutes: 0,
        overtimeMultiplier: 0.5,
        workingDaysPerMonth: -3,
      );

      expect(after.openMinutes, before.openMinutes);
      expect(after.closeMinutes, before.closeMinutes);
      expect(after.maxBreakMinutes, before.maxBreakMinutes);
      expect(after.overtimeMultiplier, before.overtimeMultiplier);
      expect(after.workingDaysPerMonth, before.workingDaysPerMonth);
    });

    test('another establishment is unaffected', () async {
      final liegeBefore = await stores.settings(StoreIds.liege);
      await stores.updateStoreSettings(StoreIds.sablon, maxBreakMinutes: 90);
      expect(
        (await stores.settings(StoreIds.liege)).maxBreakMinutes,
        liegeBefore.maxBreakMinutes,
      );
    });

    test('a demo reset restores the shipped values', () async {
      final shipped = await stores.settings(StoreIds.sablon);
      await stores.updateStoreSettings(StoreIds.sablon, maxBreakMinutes: 90);

      await DemoRepository(db).resetDemo();

      expect(
        (await stores.settings(StoreIds.sablon)).maxBreakMinutes,
        shipped.maxBreakMinutes,
      );
    });
  });

  group('the session', () {
    test('signs in, resolves, and signs back out', () async {
      // The fixture opens signed in as the owner.
      expect((await session.currentEmployee())?.id, EmployeeIds.marc);

      final amelie = await session.signIn(EmployeeIds.amelie);
      expect(amelie?.id, EmployeeIds.amelie);
      expect(await session.currentEmployeeId(), EmployeeIds.amelie);

      await session.signOut();
      expect(await session.currentEmployeeId(), isNull);
      expect(await session.currentEmployee(), isNull);
    });

    test('signing in refreshes the acting name', () async {
      await session.signIn(EmployeeIds.amelie);
      final row = await (db.select(db.meta)
            ..where((m) => m.key.equals(MetaKeys.currentUserName)))
          .getSingle();
      expect(row.value, 'Amélie Vandenberghe');
    });

    test('signing in with an unknown id changes nothing', () async {
      final result = await session.signIn('employee-nope');
      expect(result, isNull);
      expect(await session.currentEmployeeId(), EmployeeIds.marc);
    });

    test('a stored id pointing at an archived employee still resolves',
        () async {
      // Camille is archived in the seed. Archiving does not sign you out —
      // that is Phase 3's problem.
      await session.signIn(EmployeeIds.camille);
      final resolved = await session.currentEmployee();
      expect(resolved?.id, EmployeeIds.camille);
      expect(resolved?.archivedAt, isNotNull);
    });

    test('a fresh repository over the same database reads the stored session',
        () async {
      await session.signIn(EmployeeIds.amelie);
      final fresh = SessionRepository(db);
      expect((await fresh.currentEmployee())?.id, EmployeeIds.amelie);
    });
  });

  group('currentEmployeeProvider', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('build() is signed out; hydrate() resolves the stored session',
        () async {
      final c = container();
      expect(c.read(currentEmployeeProvider), isNull);

      await c.read(currentEmployeeProvider.notifier).hydrate();
      expect(c.read(currentEmployeeProvider)?.id, EmployeeIds.marc);
    });

    test('signIn / signOut move the state and the meta row together', () async {
      final c = container();
      final notifier = c.read(currentEmployeeProvider.notifier);

      await notifier.signIn(EmployeeIds.amelie);
      expect(c.read(currentEmployeeProvider)?.id, EmployeeIds.amelie);
      expect(await session.currentEmployeeId(), EmployeeIds.amelie);

      await notifier.signOut();
      expect(c.read(currentEmployeeProvider), isNull);
      expect(await session.currentEmployeeId(), isNull);
    });
  });
}
