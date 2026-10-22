import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../services/auth_service.dart';
import 'current_employee.dart';
import 'providers.dart';
import 'repositories/device_access_repository.dart';
import 'repositories/device_repository.dart';
import 'repositories/employee_repository.dart';
import 'repositories/local_data_repository.dart';
import 'repositories/store_repository.dart';

export 'repositories/device_access_repository.dart'
    show DeviceAccess, DeviceMode;
export 'repositories/local_data_repository.dart' show LocalDataKind;

/// A synchronous snapshot of [deviceAccessProvider], for the router's guard,
/// which runs inside a go_router `redirect` and cannot await. Same pattern as
/// `currentEmployeeSnapshot`.
///
/// Defaults to [DeviceAccess.local], which is what every screen test that
/// pumps the app without hydrating runs as. `main()` hydrates it before the
/// first frame.
DeviceAccess deviceAccessSnapshot = DeviceAccess.local;

/// Test-only: seed [deviceAccessSnapshot] directly.
void seedDeviceAccessSnapshot(DeviceAccess access) {
  deviceAccessSnapshot = access;
}

/// Rings when the device stops belonging to anything (an account sign-out),
/// for the router to run its guard again: it sends the device to the welcome
/// screen, whichever page was open. The router only runs its guard when
/// someone navigates, and the page that signed out may be gone by then.
///
/// Only then: in the other changes (an account joined, its data arrived) the
/// account pages finish what they show and navigate themselves, and a guard
/// running underneath them would cut that short.
final DeviceSignOutSignal deviceSignOutSignal = DeviceSignOutSignal();

class DeviceSignOutSignal extends ChangeNotifier {
  void ring() => notifyListeners();
}

/// What this installation is, and every step that changes it
/// (SYNC_PLAN.md, Phase 4).
///
/// The account flows live here rather than in the screens because each one
/// spans the server, the local database and both sessions, and has to leave
/// all of them consistent:
///
/// - [signIn] / [signUp]: the account login. They do not change the device
///   yet; the screen then either finishes ([finishWithAccount]) or sets up
///   a restaurant ([createRestaurant]) / joins one ([joinWithCode]);
/// - [signOutAccount]: signs the account out and wipes the device.
class DeviceAccessController extends Notifier<DeviceAccess> {
  @override
  DeviceAccess build() => deviceAccessSnapshot;

  AccountBackend get _backend => ref.read(accountBackendProvider);
  DeviceAccessRepository get _repository =>
      DeviceAccessRepository(ref.read(databaseProvider));

  void _set(DeviceAccess access) {
    final signedOut =
        access.mode == DeviceMode.none && state.mode != DeviceMode.none;
    // The router's copy first: setting `state` runs listeners at once, and a
    // listener that navigates sends the router reading this copy.
    deviceAccessSnapshot = access;
    state = access;
    if (signedOut) deviceSignOutSignal.ring();
  }

  /// Reads the mode from the database. Called by `main()` before the first
  /// frame, and after anything that changes it.
  Future<void> hydrate() async => _set(await _repository.read());

  Future<AccountSummary> signIn(String email, String password) async {
    await _backend.signIn(email: email, password: password);
    return _backend.myAccount();
  }

  Future<AccountSummary> signUp(String email, String password) async {
    await _backend.signUp(email: email, password: password);
    return _backend.myAccount();
  }

  /// Signs this device's account in again after its session expired, keeping
  /// everything on the device: the changes waiting to be sent leave with the
  /// next pass.
  ///
  /// The e-mail is the device's own, but its account may since belong to
  /// another restaurant; sending this device's data there would mix two
  /// restaurants, so that sign-in is undone and refused.
  Future<void> reconnect(String password) async {
    await _backend.signIn(email: state.accountEmail ?? '', password: password);
    final summary = await _backend.myAccount();
    if (summary.organizationId != state.organizationId) {
      await _backend.signOut();
      throw const AccountException(AccountErrorCode.otherRestaurant);
    }
  }

  /// The signed-in account, when a sign-in happened earlier (a set-up page
  /// reopened after the app restarted).
  Future<AccountSummary?> currentSummary() async {
    if (_backend.currentUser == null) return null;
    return _backend.myAccount();
  }

  /// A signed-up owner's first restaurant: the organization on the server,
  /// then, on this device, the first establishment and the owner as its first
  /// employee, signed in. Those two rows are ordinary writes, so they wait in
  /// the outbox for the first sync (Phase 5).
  ///
  /// Resumable: if an earlier attempt created the organization and then lost
  /// the network, it is used rather than refused.
  Future<Employee> createRestaurant({
    required String restaurantName,
    required String city,
    required String phone,
    required String firstName,
    required String lastName,
    required String pin,
  }) async {
    var summary = await _backend.myAccount();
    if (!summary.hasOrganization) {
      await _backend.createOrganization(restaurantName.trim());
      summary = await _backend.myAccount();
    }

    await _joinDevice(summary);

    final db = ref.read(databaseProvider);
    final store = await StoreRepository(db).createStore(
      name: restaurantName,
      addressLine: '',
      postalCode: '',
      city: city,
      phone: phone,
    );
    final owner = await EmployeeRepository(db).create(
      storeId: store.id,
      firstName: firstName,
      lastName: lastName,
      pin: pin,
      phone: phone,
      email: summary.email,
      role: EmployeeRole.owner,
      pay: 0,
    );
    if (owner == null) {
      throw const AccountException(
        AccountErrorCode.unknown,
        'owner not created',
      );
    }

    await ref.read(currentEmployeeProvider.notifier).signIn(owner.id);
    await hydrate();
    return owner;
  }

  // ---------------------------------------------------------------------------
  // Data already on the device (SYNC_PLAN.md, Phase 9)
  // ---------------------------------------------------------------------------

  LocalDataRepository get _local =>
      LocalDataRepository(ref.read(databaseProvider));

  /// Whether the device holds nothing, only an old demo, or its own data.
  Future<LocalDataKind> localData() => _local.kind();

  /// The names of the device's own establishments.
  Future<List<String>> ownStoreNames() => _local.ownStoreNames();

  /// Whether the account's restaurant already has establishments on the
  /// server.
  Future<bool> accountHasData() async =>
      (await _backend.storeIds()).isNotEmpty;

  /// Saves the device's data to a backup file, before the account's data
  /// replaces it. Returns the file, for the screen to name.
  Future<File> backupLocalData() async =>
      _local.exportBackup(await ref.read(backupDirectoryProvider)());

  /// Keeps the device's own data and sends it to the account: "Envoyer mes
  /// données". The demo establishments, if any, are removed first; every
  /// remaining row and photo is queued, and the next sync sends them.
  Future<void> adoptLocalData(AccountSummary summary) async {
    final db = ref.read(databaseProvider);
    final device = DeviceRepository(db);
    await device.saveNumber(
      await _backend.registerDevice(
        await device.deviceId(),
        name: deviceDisplayName(),
      ),
    );
    await _local.removeDemo();
    await _repository.writeAccount(
      email: summary.email,
      organizationId: summary.organizationId!,
      organizationName: summary.organizationName ?? '',
      role: summary.role ?? 'manager',
    );
    await _local.queueEverything();
    await hydrate();
  }

  /// A new restaurant made of the device's own data.
  Future<void> createRestaurantFromLocalData(String restaurantName) async {
    var summary = await _backend.myAccount();
    if (!summary.hasOrganization) {
      await _backend.createOrganization(restaurantName.trim());
      summary = await _backend.myAccount();
    }
    await adoptLocalData(summary);
  }

  /// Saves the device's data to a file, then ties the device to the account,
  /// whose data replaces it. Returns the backup file.
  Future<File> backupAndFinish(AccountSummary summary) async {
    final file = await backupLocalData();
    await finishWithAccount(summary);
    return file;
  }

  /// Joins the restaurant behind an owner's code, then ties the device to it.
  Future<void> joinWithCode(String code) async {
    await _backend.joinOrganization(code);
    await finishWithAccount(await _backend.myAccount());
  }

  /// Ties this device to the account's restaurant. Its data arrives with the
  /// first sync; until then the app shows the waiting screen.
  Future<void> finishWithAccount(AccountSummary summary) async {
    await _joinDevice(summary);
    await hydrate();
  }

  /// Signs the account out and wipes the device, so a lost or handed-over
  /// tablet keeps nothing of the restaurant. The screen warns first when
  /// changes are still waiting to be sent.
  Future<void> signOutAccount() async {
    // While still signed in: a signed-out phone must not keep getting the
    // owner's pushes (PUSH_NOTIFICATIONS.md). Offline, `PushController`
    // deletes the phone's Firebase token instead, and the server forgets the
    // phone the first time a push to it bounces.
    try {
      await _backend.unregisterPushDevice(
        await DeviceRepository(ref.read(databaseProvider)).deviceId(),
      );
    } on AccountException {
      // Offline, or nothing was registered.
    }
    try {
      await _backend.signOut();
    } on AccountException {
      // Offline: the local session is dropped all the same.
    }
    await ref.read(currentEmployeeProvider.notifier).signOut();
    // The device belongs to nothing before the wipe starts: the router leaves
    // the restaurant's screens for the welcome one, rather than showing them
    // empty (« Aucun établissement ») while their rows disappear, and sync
    // stops before the queue it reads is cleared.
    _set(const DeviceAccess(mode: DeviceMode.none, hasLocalData: false));
    await _repository.wipe(
      deleteEmployeePhotos: ref.read(employeePhotoStoreProvider).deleteFor,
    );
    await hydrate();
  }

  /// Registers the device with the server, clears whatever the device held
  /// before, and remembers the account.
  Future<void> _joinDevice(AccountSummary summary) async {
    final db = ref.read(databaseProvider);
    final device = DeviceRepository(db);
    final number = await _backend.registerDevice(
      await device.deviceId(),
      name: deviceDisplayName(),
    );

    // An old demo never mixes with a restaurant's real data; data of the
    // device's own reached here only after the screens offered to keep it.
    if (state.mode != DeviceMode.account) {
      await ref.read(currentEmployeeProvider.notifier).signOut();
      await _repository.wipe(
        deleteEmployeePhotos: ref.read(employeePhotoStoreProvider).deleteFor,
      );
    }

    // After the wipe, which clears every `meta` key but the device id.
    await device.saveNumber(number);
    await _repository.writeAccount(
      email: summary.email,
      organizationId: summary.organizationId!,
      organizationName: summary.organizationName ?? '',
      role: summary.role ?? 'manager',
    );
  }


}

final NotifierProvider<DeviceAccessController, DeviceAccess>
deviceAccessProvider = NotifierProvider<DeviceAccessController, DeviceAccess>(
  DeviceAccessController.new,
);

/// This installation's name as the server and the sync page show it: the
/// computer's name and its system, like `CUISINE-PC (windows)`.
String deviceDisplayName() {
  try {
    return '${Platform.localHostname} (${Platform.operatingSystem})';
  } catch (_) {
    return '';
  }
}
