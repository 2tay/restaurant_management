// Team members, establishments, and the notification feed.
//
// These are here for coherence more than for complexity: once creating an
// article sticks, a team member that silently does not is more confusing than
// either behaviour would be on its own.
//
// Ported from `test/account_test.dart` — same tests, same assertions, against a
// database instead of a list. Two of them changed shape rather than wording:
// "marking one already read changes nothing" checked a global revision counter
// that no longer exists, and the establishment writes moved from
// `AccountMutations` to `StoreRepository`, where the reads already were.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart' show StoreIds;
import 'package:stock_inventory/models/models.dart';

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

  group('team', () {
    test('inviting adds an active member with no last-seen date', () async {
      final member = await account.invite(
        fullName: 'Nadia Haddad',
        email: 'nadia@brasserie-sablon.be',
        role: TeamRole.staff,
        storeIds: const [StoreIds.sablon],
      );

      expect(member, isNotNull);
      expect(member!.isActive, isTrue);
      expect(
        member.lastActiveAt,
        isNull,
        reason: 'somebody invited has not been anywhere yet',
      );
      expect(
        (await account.teamForStore(StoreIds.sablon)).map((m) => m.id),
        contains(member.id),
      );
    });

    test('refuses an email already on the team', () async {
      final existing = (await account.team()).first;

      expect(
        await account.invite(
          fullName: "Quelqu'un d'autre",
          email: existing.email.toUpperCase(),
          role: TeamRole.staff,
          storeIds: const [StoreIds.sablon],
        ),
        isNull,
        reason: 'email is how a real invitation gets addressed in Phase 3',
      );
    });

    test('an edit does not collide with its own email', () async {
      final member = (await account.team()).first;

      expect(
        await account.updateMember(member.id, email: member.email),
        isNotNull,
      );
    });

    test('refuses to remove the last owner', () async {
      final owners = (await account.team())
          .where((member) => member.role == TeamRole.owner)
          .toList();

      // Demote everybody but one.
      for (final owner in owners.skip(1)) {
        await account.updateMember(owner.id, role: TeamRole.manager);
      }

      final last = owners.first;
      expect(await account.isLastOwner(last.id), isTrue);
      expect(await account.removeMember(last.id), isFalse);
      expect(await account.teamMember(last.id), isNotNull);
    });

    test('removes an owner while another remains', () async {
      final owners = (await account.team())
          .where((member) => member.role == TeamRole.owner)
          .toList();

      if (owners.length < 2) {
        await account.invite(
          fullName: 'Second propriétaire',
          email: 'second@brasserie-sablon.be',
          role: TeamRole.owner,
          storeIds: const [StoreIds.sablon],
        );
      }

      final target = await account.ownerCount() > 1 ? owners.first : null;
      expect(target, isNotNull);
      expect(await account.removeMember(target!.id), isTrue);
      expect(await account.teamMember(target.id), isNull);
    });

    // The four that follow are new. `TeamMember.storeIds` was a field on an
    // object in memory in Phase 1 and is a join table now, and nothing pinned
    // how it is written.

    test('an invitation grants only the establishments it names', () async {
      final member = await account.invite(
        fullName: 'Nadia Haddad',
        email: 'nadia@brasserie-sablon.be',
        role: TeamRole.staff,
        storeIds: const [StoreIds.liege],
      );

      expect(member!.storeIds, [StoreIds.liege]);
      expect(
        (await account.teamForStore(StoreIds.sablon)).map((m) => m.id),
        isNot(contains(member.id)),
      );
      expect(
        (await account.teamForStore(StoreIds.liege)).map((m) => m.id),
        contains(member.id),
      );
    });

    test('the same establishment twice is granted once', () async {
      final member = await account.invite(
        fullName: 'Nadia Haddad',
        email: 'nadia@brasserie-sablon.be',
        role: TeamRole.staff,
        storeIds: const [StoreIds.sablon, StoreIds.sablon],
      );

      // Phase 1 stored the list as given and nothing noticed; the grant table's
      // primary key is the pair, so a repeated id would fail the insert.
      final stored = await account.teamMember(member!.id);
      expect(stored!.storeIds, [StoreIds.sablon]);
    });

    test('editing the establishments replaces the set', () async {
      final member = await account.invite(
        fullName: 'Nadia Haddad',
        email: 'nadia@brasserie-sablon.be',
        role: TeamRole.staff,
        storeIds: const [StoreIds.sablon, StoreIds.liege],
      );

      await account.updateMember(member!.id, storeIds: const [StoreIds.liege]);

      final stored = await account.teamMember(member.id);
      expect(stored!.storeIds, [StoreIds.liege]);
      expect(
        (await account.teamForStore(StoreIds.sablon)).map((m) => m.id),
        isNot(contains(member.id)),
        reason: 'a revoked establishment has to stop being listed',
      );
    });

    test('an edit that names no establishments leaves them alone', () async {
      final member = (await account.team()).firstWhere(
        (m) => m.storeIds.isNotEmpty,
      );

      await account.updateMember(member.id, fullName: 'Nom Corrigé');

      final stored = await account.teamMember(member.id);
      expect(stored!.fullName, 'Nom Corrigé');
      expect(stored.storeIds, member.storeIds);
    });

    test('removing a member takes their grants with them', () async {
      final member = await account.invite(
        fullName: 'Nadia Haddad',
        email: 'nadia@brasserie-sablon.be',
        role: TeamRole.staff,
        storeIds: const [StoreIds.sablon],
      );

      expect(await account.removeMember(member!.id), isTrue);
      expect(
        (await account.teamForStore(StoreIds.sablon)).map((m) => m.id),
        isNot(contains(member.id)),
        reason: 'a grant outliving its member would resurrect them if the id '
            'were ever reused',
      );
    });

    test('the acting user survives their own removal', () async {
      // `meta.currentUserId` is a plain string, not a foreign key, so removing
      // whoever it points at leaves it dangling. Every movement and every price
      // change is stamped with this person's name, so the fallback matters more
      // than the row does.
      final current = await account.currentUser();
      expect(current, isNotNull);

      await account.updateMember(current!.id, role: TeamRole.manager);
      expect(await account.removeMember(current.id), isTrue);

      final after = await account.currentUser();
      expect(after, isNotNull);
      expect(after!.id, isNot(current.id));
      expect(await account.currentUserName(), isNotEmpty);
    });
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
