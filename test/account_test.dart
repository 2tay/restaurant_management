// Team members, stores, and the notification feed.
//
// These are here for coherence more than for complexity: once creating an
// article sticks, a team member that silently does not is more confusing than
// either behaviour would be on its own.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

void main() {
  setUp(restoreMockData);

  group('team', () {
    test('inviting adds an active member with no last-seen date', () {
      final member = AccountMutations.invite(
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
        MockQueries.teamForStore(StoreIds.sablon).map((m) => m.id),
        contains(member.id),
      );
    });

    test('refuses an email already on the team', () {
      final existing = mockTeam.first;

      expect(
        AccountMutations.invite(
          fullName: 'Quelqu\'un d\'autre',
          email: existing.email.toUpperCase(),
          role: TeamRole.staff,
          storeIds: const [StoreIds.sablon],
        ),
        isNull,
        reason: 'email is how a real invitation gets addressed in Phase 2',
      );
    });

    test('an edit does not collide with its own email', () {
      final member = mockTeam.first;

      expect(
        AccountMutations.updateMember(member.id, email: member.email),
        isNotNull,
      );
    });

    test('refuses to remove the last owner', () {
      final owners = mockTeam
          .where((member) => member.role == TeamRole.owner)
          .toList();

      // Demote everybody but one.
      for (final owner in owners.skip(1)) {
        AccountMutations.updateMember(owner.id, role: TeamRole.manager);
      }

      final last = owners.first;
      expect(AccountMutations.isLastOwner(last.id), isTrue);
      expect(AccountMutations.removeMember(last.id), isFalse);
      expect(MockQueries.teamMemberById(last.id), isNotNull);
    });

    test('removes an owner while another remains', () {
      final owners = mockTeam
          .where((member) => member.role == TeamRole.owner)
          .toList();

      if (owners.length < 2) {
        AccountMutations.invite(
          fullName: 'Second propriétaire',
          email: 'second@brasserie-sablon.be',
          role: TeamRole.owner,
          storeIds: const [StoreIds.sablon],
        );
      }

      final target = MockQueries.ownerCount() > 1 ? owners.first : null;
      expect(target, isNotNull);
      expect(AccountMutations.removeMember(target!.id), isTrue);
      expect(MockQueries.teamMemberById(target.id), isNull);
    });
  });

  group('stores', () {
    test('a new store starts genuinely empty', () {
      final store = AccountMutations.createStore(
        name: 'Friterie du Midi',
        addressLine: 'Chaussée de Mons 12',
        postalCode: '1070',
        city: 'Anderlecht',
        phone: '+32 2 555 00 00',
      );

      // Categories, units, items and suppliers are all per-store by design, so
      // a new shop inherits nothing. What the user sees next is every empty
      // state in the app, doing its job.
      expect(MockQueries.itemsForStore(store.id), isEmpty);
      expect(MockQueries.categoriesForStore(store.id), isEmpty);
      expect(MockQueries.unitsForStore(store.id), isEmpty);
      expect(MockQueries.suppliersForStore(store.id), isEmpty);
      expect(MockQueries.ordersForStore(store.id), isEmpty);
      expect(MockQueries.stockValuation(store.id), 0);
    });

    test('is reachable by id straight away', () {
      final store = AccountMutations.createStore(
        name: 'Friterie du Midi',
        addressLine: 'Chaussée de Mons 12',
        postalCode: '1070',
        city: 'Anderlecht',
        phone: '+32 2 555 00 00',
      );

      expect(MockQueries.storeById(store.id), isNotNull);
      expect(MockQueries.storeByIdOrFirst(store.id).id, store.id);
    });

    test('an edit keeps the id, so nothing routed by it breaks', () {
      final updated = AccountMutations.updateStore(
        StoreIds.sablon,
        name: 'Brasserie du Grand Sablon',
      );

      expect(updated!.id, StoreIds.sablon);
      expect(MockQueries.itemsForStore(StoreIds.sablon), isNotEmpty);
    });
  });

  group('notifications', () {
    test('marking one read lowers the unread count', () {
      final unread = MockQueries.notificationsForStore(
        StoreIds.sablon,
      ).firstWhere((n) => !n.isRead);
      final before = MockQueries.unreadNotificationCount(StoreIds.sablon);

      expect(AccountMutations.markRead(unread.id), isTrue);
      expect(
        MockQueries.unreadNotificationCount(StoreIds.sablon),
        before - 1,
      );
    });

    test('marking one already read changes nothing', () {
      final unread = MockQueries.notificationsForStore(
        StoreIds.sablon,
      ).firstWhere((n) => !n.isRead);

      AccountMutations.markRead(unread.id);
      final revision = MockWrite.revision.value;

      expect(AccountMutations.markRead(unread.id), isFalse);
      expect(
        MockWrite.revision.value,
        revision,
        reason: 'nothing changed, so nothing should redraw',
      );
    });

    test('marking all read returns how many actually changed', () {
      final before = MockQueries.unreadNotificationCount(StoreIds.sablon);
      expect(before, greaterThan(0));

      expect(AccountMutations.markAllRead(StoreIds.sablon), before);
      expect(MockQueries.unreadNotificationCount(StoreIds.sablon), 0);

      // Second time there is nothing to do, so the screen can stay quiet.
      expect(AccountMutations.markAllRead(StoreIds.sablon), 0);
    });

    test('marking all read leaves other stores alone', () {
      final otherBefore = MockQueries.unreadNotificationCount(StoreIds.liege);

      AccountMutations.markAllRead(StoreIds.sablon);

      expect(MockQueries.unreadNotificationCount(StoreIds.liege), otherBefore);
    });
  });
}
