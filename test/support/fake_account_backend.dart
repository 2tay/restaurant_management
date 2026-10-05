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

  /// The next `pushChanges` saves its batch, then the answer is lost on the
  /// way back, as when the Wi-Fi drops at the wrong second.
  bool loseAnswerOnce = false;

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

    final answers = [
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
          final table = change['table']! as String;
          final refusal = _paidDayRefusal(table, sent, existing, columns);
          if (refusal != null) {
            return PushResult(
              id: change['id']! as int,
              accepted: false,
              reason: refusal.reason,
              restore: refusal.restore,
            );
          }
          final conflict = _conflictRefusal(table, sent, existing, change);
          if (conflict != null) {
            return PushResult(
              id: change['id']! as int,
              accepted: false,
              reason: conflict,
            );
          }
          // As `push_changes`: a watched column the server holds with
          // another value than this edit started from was changed
          // meanwhile by another tablet.
          final base = change['base'] as Map<String, Object?>?;
          final overwrote = existing == null || base == null
              ? const <String>[]
              : [
                  for (final MapEntry(key: column, value: before)
                      in base.entries)
                    if (existing[column] != before &&
                        existing[column] != sent[column])
                      column,
                ];
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
          return PushResult(
            id: change['id']! as int,
            accepted: true,
            overwrote: overwrote,
          );
        }(),
    ];
    if (loseAnswerOnce) {
      loseAnswerOnce = false;
      throw const AccountException(AccountErrorCode.network);
    }
    return answers;
  }

  /// As `push_changes`' other rules (supabase/migrations/…_employees.sql):
  /// a row cannot move to another store, a deleted row stays deleted, and a
  /// commande's status only moves forward and stays closed once closed.
  static String? _conflictRefusal(
    String table,
    Map<String, Object?> sent,
    Map<String, Object?>? existing,
    Map<String, Object?> change,
  ) {
    if (existing == null) return null;
    if (table != 'stores' && existing['store_id'] != change['store_id']) {
      return 'store_changed';
    }
    if (existing['deleted_at'] != null && sent['deleted_at'] == null) {
      return 'deleted';
    }
    if (table == 'purchase_orders' && sent['status'] != existing['status']) {
      if (existing['status'] == 'received' ||
          existing['status'] == 'cancelled') {
        return 'status_closed';
      }
      const rank = {
        'draft': 0,
        'sent': 1,
        'partial': 2,
        'cancelled': 2,
        'received': 3,
      };
      if (rank[sent['status']]! < rank[existing['status']]!) {
        return 'status_backwards';
      }
    }
    return null;
  }

  /// As `push_changes` (SYNC_PERSONNEL_PLAN.md, step 7): a day another
  /// payment took first (PA1), and a paid day frozen (PA2).
  ({String reason, List<({String table, Map<String, Object?> row})> restore})?
  _paidDayRefusal(
    String table,
    Map<String, Object?> sent,
    Map<String, Object?>? existing,
    List<Object?>? columns,
  ) {
    Map<String, Object?>? row(String table, Object? id) =>
        id == null ? null : serverRows['$table|$id'];

    if (table == 'attendances' &&
        existing?['payroll_period_id'] != null &&
        sent['payroll_period_id'] != null &&
        sent['payroll_period_id'] != existing!['payroll_period_id']) {
      return (
        reason: 'day_already_paid',
        restore: [
          (
            table: 'payroll_periods',
            row: row('payroll_periods', existing['payroll_period_id'])!,
          ),
          (table: 'attendances', row: existing),
        ],
      );
    }

    bool paid(Object? attendanceId) =>
        row('attendances', attendanceId)?['payroll_period_id'] != null;
    final paidDay = switch (table) {
      'attendances' => existing?['payroll_period_id'] != null,
      'attendance_sessions' =>
        paid(existing?['attendance_id']) || paid(sent['attendance_id']),
      'attendance_pauses' => [existing?['session_id'], sent['session_id']]
          .any((s) => paid(row('attendance_sessions', s)?['attendance_id'])),
      _ => false,
    };
    if (!paidDay) return null;

    final differs =
        existing == null ||
        [
          for (final c in columns ?? sent.keys)
            if (c != 'id' && c != 'updated_at' && c != 'payroll_period_id') c,
        ].any((c) => existing[c] != sent[c]);
    if (!differs) return null;
    return (
      reason: 'paid_day_frozen',
      restore: [
        // A day comes back with its payment, so its link holds.
        if (table == 'attendances' && existing != null)
          (
            table: 'payroll_periods',
            row: row('payroll_periods', existing['payroll_period_id'])!,
          ),
        if (existing != null) (table: table, row: existing),
      ],
    );
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
