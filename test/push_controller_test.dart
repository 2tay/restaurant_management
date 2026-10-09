// The owner's phone push, on the phone's side (PUSH_NOTIFICATIONS.md): the
// device is registered while the owner is the one signed in, and only then.
//
// Firebase is `_FakeMessaging`, the server `FakeAccountBackend`. What the
// server does with the token is tested in supabase/tests/database/push.test.sql.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/device_access.dart';
import 'package:stock_inventory/data/employee_photo_store.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/services/auth_service.dart';
import 'package:stock_inventory/services/push_service.dart';

import 'support/db_fixture.dart';
import 'support/fake_account_backend.dart';

void main() {
  late FakeAccountBackend server;
  late _FakeMessaging messaging;

  setUp(() {
    server = FakeAccountBackend();
    messaging = _FakeMessaging();
    seedCurrentEmployeeSnapshot(null);
  });

  tearDown(() {
    seedDeviceAccessSnapshot(DeviceAccess.demo);
    seedCurrentEmployeeSnapshot(null);
  });

  /// Lets the controller's queued steps run.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// A seeded device signed in to the owner's account, nobody at it yet.
  Future<(ProviderContainer, String)> accountDevice({
    bool account = true,
  }) async {
    final AppDatabase db = await openSeededDatabase();
    if (account) {
      final org = server.addOrganization('Resto');
      server.addUser('owner@example.be', 'pw', organizationId: org);
      await server.signIn(email: 'owner@example.be', password: 'pw');
      await DeviceAccessRepository(db).writeAccount(
        email: 'owner@example.be',
        organizationId: org,
        organizationName: 'Resto',
        role: 'owner',
      );
    }
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBackendProvider.overrideWithValue(server),
        pushMessagingProvider.overrideWithValue(messaging),
        employeePhotoStoreProvider.overrideWithValue(_NoPhotos()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(deviceAccessProvider.notifier).hydrate();
    container.read(pushControllerProvider);
    await settle();
    return (container, await DeviceRepository(db).deviceId());
  }

  Future<void> signIn(ProviderContainer c, String employeeId) async {
    await c.read(currentEmployeeProvider.notifier).signIn(employeeId);
    await settle();
  }

  test('the owner signing in registers the phone', () async {
    final (c, deviceId) = await accountDevice();
    expect(server.pushTokens, isEmpty);

    await signIn(c, EmployeeIds.marc);

    expect(messaging.permissionAsked, isTrue);
    expect(server.pushTokens, {deviceId: 'token-1'});
    expect(c.read(pushControllerProvider), isTrue);
  });

  test('a manager signing in gets no push', () async {
    final (c, _) = await accountDevice();

    await signIn(c, EmployeeIds.amelie);

    expect(server.pushTokens, isEmpty);
    expect(c.read(pushControllerProvider), isFalse);
  });

  test('a manager taking over a tablet stops the owner\'s pushes', () async {
    final (c, _) = await accountDevice();
    await signIn(c, EmployeeIds.marc);
    expect(server.pushTokens, isNotEmpty);

    await signIn(c, EmployeeIds.amelie);

    expect(server.pushTokens, isEmpty);
  });

  test('the owner signing out stops the pushes', () async {
    final (c, _) = await accountDevice();
    await signIn(c, EmployeeIds.marc);

    await c.read(currentEmployeeProvider.notifier).signOut();
    await settle();

    expect(server.pushTokens, isEmpty);
    expect(c.read(pushControllerProvider), isFalse);
  });

  test('the owner saying no to notifications registers nothing', () async {
    messaging.allowed = false;
    final (c, _) = await accountDevice();

    await signIn(c, EmployeeIds.marc);

    expect(server.pushTokens, isEmpty);
  });

  test('a new token from Firebase is sent again', () async {
    final (c, deviceId) = await accountDevice();
    await signIn(c, EmployeeIds.marc);

    messaging.currentToken = 'token-2';
    messaging.refreshes.add('token-2');
    await settle();

    expect(server.pushTokens, {deviceId: 'token-2'});
  });

  test('offline, signing in registers nothing and breaks nothing', () async {
    final (c, _) = await accountDevice();
    server.failNext = const AccountException(AccountErrorCode.network);

    await signIn(c, EmployeeIds.marc);

    expect(server.pushTokens, isEmpty);
    expect(c.read(pushControllerProvider), isFalse);
  });

  test('signing the account out of the phone drops its address', () async {
    final (c, _) = await accountDevice();
    await signIn(c, EmployeeIds.marc);

    await c.read(deviceAccessProvider.notifier).signOutAccount();
    await settle();

    expect(server.pushTokens, isEmpty, reason: 'unregistered while online');
    expect(messaging.deleted, isTrue, reason: 'and the address dropped');
  });

  test('the demo never registers', () async {
    final (c, _) = await accountDevice(account: false);

    await signIn(c, EmployeeIds.marc);

    expect(messaging.permissionAsked, isFalse);
    expect(server.pushTokens, isEmpty);
  });

  test('a tapped push opens its page', () async {
    final (c, _) = await accountDevice();
    final opened = <String>[];
    c.read(pushControllerProvider.notifier).opens.listen(opened.add);

    messaging.tapped.add({'store_id': StoreIds.sablon, 'kind': 'outOfStock'});
    await settle();

    expect(opened, [Routes.toAlerts(StoreIds.sablon)]);
  });

  test('each kind opens where it is about', () {
    expect(pushRoute({'store_id': 's1', 'kind': 'lowStock'}),
        Routes.toAlerts('s1'));
    expect(pushRoute({'store_id': 's1', 'kind': 'outOfStock'}),
        Routes.toAlerts('s1'));
    expect(pushRoute({'store_id': 's1', 'kind': 'busyDays'}),
        Routes.toNotifications('s1'));
    expect(pushRoute({'store_id': 's1', 'kind': 'clockIn'}),
        Routes.toNotifications('s1'));
    expect(pushRoute({'store_id': 's1', 'kind': 'clockOut'}),
        Routes.toNotifications('s1'));
    expect(pushRoute({'store_id': 's1', 'kind': 'priceChange'}), isNull);
    expect(pushRoute({'kind': 'lowStock'}), isNull);
  });
}

class _FakeMessaging implements PushMessaging {
  bool allowed = true;
  bool permissionAsked = false;
  bool deleted = false;
  String? currentToken = 'token-1';
  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<Map<String, String>> tapped =
      StreamController.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionAsked = true;
    return allowed;
  }

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Future<void> deleteToken() async => deleted = true;

  @override
  Future<Map<String, String>?> initialTap() async => null;

  @override
  Stream<Map<String, String>> get taps => tapped.stream;
}

class _NoPhotos extends EmployeePhotoStore {
  @override
  Future<void> deleteFor(String employeeId) async {}
}
