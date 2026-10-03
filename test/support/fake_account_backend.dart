// An in-memory account server for tests (SYNC_PLAN.md, Phase 4).
//
// Behaves like the real functions in supabase/migrations/: one organization
// per user, owners invite with a one-time code, devices register to one
// organization. `failNext` makes the next call throw, to test error paths.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stock_inventory/services/auth_service.dart';

class FakeAccountBackend implements AccountBackend {
  final Map<String, _FakeUser> _users = {};
  final Map<String, String> _organizations = {}; // id -> name
  final Map<String, String> _codes = {}; // code -> organization id
  final Map<String, DeviceInfo> registeredDevices = {};
  final Map<String, String> _deviceOrganization = {};

  _FakeUser? _current;
  int createOrganizationCalls = 0;

  /// Thrown by the next call, then cleared.
  AccountException? failNext;

  /// Creates a user who already exists on the server.
  void addUser(
    String email,
    String password, {
    String? organizationId,
    String role = 'owner',
  }) {
    _users[email] = _FakeUser(
      id: 'user-${_users.length + 1}',
      email: email,
      password: password,
      organizationId: organizationId,
      role: organizationId == null ? null : role,
    );
  }

  /// Creates an organization directly, as another device would have.
  String addOrganization(String name) {
    final id = 'org-${_organizations.length + 1}';
    _organizations[id] = name;
    return id;
  }

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  _FakeUser _signedIn() {
    final user = _current;
    if (user == null) throw const AccountException(AccountErrorCode.notAllowed);
    return user;
  }

  @override
  bool get isAvailable => true;

  @override
  AccountUser? get currentUser => _current == null
      ? null
      : AccountUser(id: _current!.id, email: _current!.email);

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) async {
    _maybeFail();
    final user = _users[email.trim()];
    if (user == null || user.password != password) {
      throw const AccountException(AccountErrorCode.badCredentials);
    }
    _current = user;
    return AccountUser(id: user.id, email: user.email);
  }

  @override
  Future<AccountUser> signUp({
    required String email,
    required String password,
  }) async {
    _maybeFail();
    if (_users.containsKey(email.trim())) {
      throw const AccountException(AccountErrorCode.emailTaken);
    }
    addUser(email.trim(), password);
    return signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _maybeFail();
    _current = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async => _maybeFail();

  @override
  Future<AccountSummary> myAccount() async {
    _maybeFail();
    final user = _signedIn();
    return AccountSummary(
      userId: user.id,
      email: user.email,
      organizationId: user.organizationId,
      organizationName: user.organizationId == null
          ? null
          : _organizations[user.organizationId],
      role: user.role,
    );
  }

  @override
  Future<String> createOrganization(String name) async {
    _maybeFail();
    final user = _signedIn();
    if (user.organizationId != null) {
      throw const AccountException(AccountErrorCode.alreadyMember);
    }
    createOrganizationCalls++;
    final id = addOrganization(name);
    user
      ..organizationId = id
      ..role = 'owner';
    return id;
  }

  @override
  Future<String> joinOrganization(String code) async {
    _maybeFail();
    final user = _signedIn();
    if (user.organizationId != null) {
      throw const AccountException(AccountErrorCode.alreadyMember);
    }
    final normalized = code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    final organization = _codes.remove(normalized);
    if (organization == null) {
      throw const AccountException(AccountErrorCode.invalidCode);
    }
    user
      ..organizationId = organization
      ..role = 'manager';
    return organization;
  }

  @override
  Future<String> createJoinCode() async {
    _maybeFail();
    final user = _signedIn();
    if (user.role != 'owner') {
      throw const AccountException(AccountErrorCode.notAllowed);
    }
    final code = 'CODE${_codes.length + 1}XYZ'.substring(0, 8);
    _codes[code] = user.organizationId!;
    return code;
  }

  /// A code for [organizationId], as its owner would have made.
  String codeFor(String organizationId) {
    final code = 'JOIN${_codes.length + 1}ABC'.substring(0, 8);
    _codes[code] = organizationId;
    return code;
  }

  @override
  Future<void> registerDevice(String deviceId, {String name = ''}) async {
    _maybeFail();
    final user = _signedIn();
    final existing = _deviceOrganization[deviceId];
    if (existing != null && existing != user.organizationId) {
      throw const AccountException(AccountErrorCode.notAllowed);
    }
    _deviceOrganization[deviceId] = user.organizationId!;
    registeredDevices[deviceId] = DeviceInfo(
      id: deviceId,
      name: name,
      createdAt: DateTime(2026, 9, 29),
    );
  }

  @override
  Future<List<DeviceInfo>> devices() async {
    _maybeFail();
    final user = _signedIn();
    return [
      for (final entry in registeredDevices.entries)
        if (_deviceOrganization[entry.key] == user.organizationId) entry.value,
    ];
  }

  @override
  Future<bool> removeDevice(String deviceId) async {
    _maybeFail();
    _deviceOrganization.remove(deviceId);
    return registeredDevices.remove(deviceId) != null;
  }

  // --- Receiving changes (Phase 5) -----------------------------------------

  /// What the server holds, by `table|row_key`: the last accepted payload.
  final Map<String, Map<String, Object?>> serverRows = {};

  /// Entries per `pushChanges` call, in call order.
  final List<int> batchSizes = [];

  /// Returns a refusal reason for a change, or null to accept it.
  String? Function(Map<String, Object?> change)? rejectWhen;

  /// Runs inside `pushChanges` before it answers: a test uses it to edit a
  /// row while its change is travelling.
  Future<void> Function()? duringPush;

  @override
  Future<List<PushResult>> pushChanges(
    String deviceId,
    List<Map<String, Object?>> changes,
  ) async {
    _maybeFail();
    _signedIn();
    batchSizes.add(changes.length);
    await duringPush?.call();

    if (!registeredDevices.containsKey(deviceId)) {
      return [
        for (final change in changes)
          PushResult(
            id: change['id']! as int,
            accepted: false,
            reason: 'device_unknown',
          ),
      ];
    }

    return [
      for (final change in changes)
        () {
          final reason = rejectWhen?.call(change);
          if (reason != null) {
            return PushResult(
              id: change['id']! as int,
              accepted: false,
              reason: reason,
            );
          }
          final key = '${change['table']}|${change['row_key']}';
          final sent =
              jsonDecode(change['payload']! as String) as Map<String, Object?>;
          // As `push_changes`: an edit that names its columns overwrites
          // those (and the stamp) on a row the server has; the rest stays.
          final columns = change['columns'] as List<Object?>?;
          final existing = serverRows[key];
          final row = columns == null || existing == null
              ? sent
              : {
                  ...existing,
                  for (final column in [...columns, 'updated_at'])
                    column! as String: sent[column],
                };
          serverRows[key] = row;
          final storeId = change['store_id']! as String;
          if (change['table'] == 'stores') {
            _storeOrganization[storeId] = _signedIn().organizationId!;
          }
          _pullable[key] = (
            seq: ++_seq,
            storeId: storeId,
            table: change['table']! as String,
            row: row,
          );
          _live.add(storeId);
          return PushResult(id: change['id']! as int, accepted: true);
        }(),
    ];
  }

  // --- Handing changes back (Phase 6) --------------------------------------

  int _seq = 0;
  final Map<String, String> _storeOrganization = {};
  final Map<
    String,
    ({int seq, String storeId, String table, Map<String, Object?> row})
  >
  _pullable = {};
  final StreamController<String> _live = StreamController<String>.broadcast();

  /// Pages handed out by `pullChanges`, in call order: `(storeId, after)`.
  final List<(String, int)> pulls = [];

  /// Fails the pull after this many pages, once, to test a resumed download.
  int? failPullAfterPages;

  @override
  Future<List<String>> storeIds() async {
    _maybeFail();
    final organization = _signedIn().organizationId;
    return [
      for (final entry in _storeOrganization.entries)
        if (entry.value == organization) entry.key,
    ];
  }

  @override
  Future<PullPage> pullChanges(
    String storeId, {
    required int after,
    int limit = 500,
  }) async {
    _maybeFail();
    _signedIn();
    final remaining = failPullAfterPages;
    if (remaining != null) {
      if (remaining == 0) {
        failPullAfterPages = null;
        throw const AccountException(AccountErrorCode.network);
      }
      failPullAfterPages = remaining - 1;
    }
    pulls.add((storeId, after));

    final newer =
        _pullable.values
            .where((r) => r.storeId == storeId && r.seq > after)
            .toList()
          ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = newer.take(limit).toList();
    return PullPage(
      changes: [
        for (final r in page)
          PulledChange(seq: r.seq, table: r.table, row: Map.of(r.row)),
      ],
      nextAfter: page.isEmpty ? after : page.last.seq,
      hasMore: newer.length > limit,
    );
  }

  @override
  Stream<LiveSignal> storeChanges(List<String> storeIds) =>
      _live.stream.where(storeIds.contains).map((_) => LiveSignal.changed);

  // --- Photos (Phase 8) ------------------------------------------------------

  /// The photo store: path -> bytes.
  final Map<String, Uint8List> photos = {};

  /// Paths removed, in call order.
  final List<String> removedPhotos = [];

  @override
  Future<void> uploadPhoto(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    _maybeFail();
    _signedIn();
    photos[path] = bytes;
  }

  @override
  Future<Uint8List?> downloadPhoto(String path) async {
    _maybeFail();
    _signedIn();
    return photos[path];
  }

  @override
  Future<void> removePhotos(List<String> paths) async {
    _maybeFail();
    _signedIn();
    for (final path in paths) {
      photos.remove(path);
      removedPhotos.add(path);
    }
  }
}

class _FakeUser {
  _FakeUser({
    required this.id,
    required this.email,
    required this.password,
    this.organizationId,
    this.role,
  });

  final String id;
  final String email;
  final String password;
  String? organizationId;
  String? role;
}
