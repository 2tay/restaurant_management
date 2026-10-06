import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/routes.dart';
import '../data/current_employee.dart';
import '../data/device_access.dart';
import '../data/providers.dart';
import '../data/repositories/device_repository.dart';
import '../models/employee.dart';

/// The owner's phone push (PUSH_NOTIFICATIONS.md), on the phone's side.
///
/// The server decides what to send and when; this device only says where.
/// While **the owner** is the one signed in on an account device, its
/// Firebase token is registered with the server (`register_push_device`).
/// Anyone else signed in — a manager at a shared tablet — or nobody, and it
/// is unregistered. Android only: elsewhere [pushMessagingProvider] is null
/// and nothing here runs.
///
/// [PushMessaging] is the seam: the app uses [FirebasePushMessaging], tests
/// a fake. Nothing else in the app imports Firebase.
abstract interface class PushMessaging {
  /// Asks the user, the first time, whether this app may show
  /// notifications. True when it may.
  Future<bool> requestPermission();

  /// This phone's address for pushes, or null when Firebase has none yet.
  Future<String?> token();

  /// A new address, when Firebase changes it.
  Stream<String> get tokenRefreshes;

  /// Drops this phone's address: a push sent to the old one bounces, and the
  /// server forgets it.
  Future<void> deleteToken();

  /// The push the app was opened from, when it was closed.
  Future<Map<String, String>?> initialTap();

  /// Pushes tapped while the app is running in the background.
  Stream<Map<String, String>> get taps;
}

class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Future<Map<String, String>?> initialTap() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _data(message);
  }

  @override
  Stream<Map<String, String>> get taps =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);

  static Map<String, String> _data(RemoteMessage message) => {
    for (final entry in message.data.entries) entry.key: '${entry.value}',
  };
}

/// The device's push messaging, or null where there is none (not Android, no
/// server configured, a test). Set by `main()`.
final Provider<PushMessaging?> pushMessagingProvider = Provider<PushMessaging?>(
  (ref) => null,
);

/// Where a tapped push opens: the Alertes of its store for a stock push, the
/// notifications for jours chargés. Null for a push this app does not know.
String? pushRoute(Map<String, String> data) {
  final storeId = data['store_id'];
  if (storeId == null || storeId.isEmpty) return null;
  return switch (data['kind']) {
    'outOfStock' || 'lowStock' => Routes.toAlerts(storeId),
    'busyDays' => Routes.toNotifications(storeId),
    _ => null,
  };
}

/// Keeps this device's registration in step with who is signed in. Its
/// state: whether the device is registered for the owner's pushes.
class PushController extends Notifier<bool> {
  final StreamController<String> _opens = StreamController<String>.broadcast();
  StreamSubscription<String>? _refreshes;
  StreamSubscription<Map<String, String>>? _taps;
  Future<void> _queue = Future.value();

  /// The route of each push the user taps, for the router to open.
  Stream<String> get opens => _opens.stream;

  @override
  bool build() {
    final messaging = ref.watch(pushMessagingProvider);
    ref.onDispose(() {
      _refreshes?.cancel();
      _taps?.cancel();
      _opens.close();
    });
    if (messaging == null) return false;

    ref.listen<DeviceAccess>(deviceAccessProvider, (previous, access) {
      // Leaving the account (signed out, possibly offline): this phone's
      // address goes, so nothing more reaches it even if the server could
      // not be told.
      if (previous?.mode == DeviceMode.account && !access.isAccount) {
        _enqueue(() async {
          try {
            await messaging.deleteToken();
          } catch (_) {
            // Offline: Firebase drops it later on its own.
          }
          state = false;
        });
      } else {
        _reconcile();
      }
    });
    ref.listen<Employee?>(currentEmployeeProvider, (previous, employee) {
      if (previous?.id != employee?.id || previous?.role != employee?.role) {
        _reconcile();
      }
    });
    _refreshes = messaging.tokenRefreshes.listen((_) => _reconcile());
    _taps = messaging.taps.listen(_open);

    // After build returns, so `state` exists when it is written.
    scheduleMicrotask(() async {
      _reconcile();
      try {
        final first = await messaging.initialTap();
        if (first != null) _open(first);
      } catch (_) {
        // No push to open.
      }
    });
    return false;
  }

  void _open(Map<String, String> data) {
    final route = pushRoute(data);
    if (route != null && !_opens.isClosed) _opens.add(route);
  }

  /// One registration change at a time, in order: an owner signing out
  /// right after signing in must not end registered.
  void _enqueue(Future<void> Function() step) {
    _queue = _queue.then((_) => step()).catchError((Object _) {});
  }

  void _reconcile() => _enqueue(_apply);

  Future<void> _apply() async {
    final messaging = ref.read(pushMessagingProvider);
    if (messaging == null || !ref.read(deviceAccessProvider).isAccount) return;

    final backend = ref.read(accountBackendProvider);
    final deviceId = await DeviceRepository(
      ref.read(databaseProvider),
    ).deviceId();
    final owner = ref.read(currentEmployeeProvider)?.role == EmployeeRole.owner;

    try {
      if (owner && await messaging.requestPermission()) {
        final token = await messaging.token();
        if (token != null) {
          await backend.registerPushDevice(deviceId, token);
          state = true;
          return;
        }
      }
      // Not the owner, or the owner said no: no push to this device.
      await backend.unregisterPushDevice(deviceId);
      state = false;
    } catch (_) {
      // Offline, or the server refused: the next sign-in, token change or
      // start tries again.
    }
  }
}

final NotifierProvider<PushController, bool> pushControllerProvider =
    NotifierProvider<PushController, bool>(PushController.new);
