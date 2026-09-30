import 'dart:io' show File, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../services/auth_service.dart';
import 'current_employee.dart';
import 'database/bootstrap.dart';
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
/// Defaults to the demo, which is what every screen test that pumps the app
/// without hydrating has always been.
DeviceAccess deviceAccessSnapshot = DeviceAccess.demo;

/// Test-only: seed [deviceAccessSnapshot] directly.
void seedDeviceAccessSnapshot(DeviceAccess access) {
  deviceAccessSnapshot = access;
}

/// What this installation is, and every step that changes it
/// (SYNC_PLAN.md, Phase 4).
///
/// The account flows live here rather than in the screens because each one
/// spans the server, the local database and both sessions, and has to leave
/// all of them consistent:
///
/// - [startDemo]: the demo, offline, as the app has always been;
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
    state = access;
    deviceAccessSnapshot = access;
  }

  /// Reads the mode from the database. Called by `main()` before the first
  /// frame, and after anything that changes it.
  Future<void> hydrate() async => _set(await _repository.read());

  /// Opens the demo: seeds it if the device is empty, and remembers the
  /// choice.
  Future<void> startDemo() async {
    final db = ref.read(databaseProvider);
    await seedIfEmpty(db);
    await _repository.writeDemo();
    await hydrate();
  }

  Future<AccountSummary> signIn(String email, String password) async {
    await _backend.signIn(email: email, password: password);
    return _backend.myAccount();
  }

  Future<AccountSummary> signUp(String email, String password) async {
    await _backend.signUp(email: email, password: password);
    return _backend.myAccount();
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
    required String password,
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
      password: password,
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

  /// Whether the device holds nothing, only the demo, or its own data.
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
    await _backend.registerDevice(
      await DeviceRepository(db).deviceId(),
      name: deviceDisplayName(),
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
    try {
      await _backend.signOut();
    } on AccountException {
      // Offline: the local session is dropped all the same.
    }
    await ref.read(currentEmployeeProvider.notifier).signOut();
    await _repository.wipe(
      deleteEmployeePhotos: ref.read(employeePhotoStoreProvider).deleteFor,
    );
    await hydrate();
  }

  /// Registers the device with the server, clears the demo if that is what
  /// the device held, and remembers the account.
  Future<void> _joinDevice(AccountSummary summary) async {
    final db = ref.read(databaseProvider);
    await _backend.registerDevice(
      await DeviceRepository(db).deviceId(),
      name: deviceDisplayName(),
    );

    // The demo never mixes with a restaurant's real data.
    if (state.mode != DeviceMode.account) {
      await ref.read(currentEmployeeProvider.notifier).signOut();
      await _repository.wipe(
        deleteEmployeePhotos: ref.read(employeePhotoStoreProvider).deleteFor,
      );
    }

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
