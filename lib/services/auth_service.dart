import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Real authentication against the sync server (SYNC_PLAN.md, Phase 4).
///
/// Two logins live in this app, and this file is only the first:
///
/// - the **account** login: an owner or manager's e-mail and password,
///   checked by Supabase. It decides which restaurant the device belongs to,
///   happens once per device, and stays signed in offline;
/// - the **employee** login: PIN and four-digit password, checked locally by
///   `CredentialRepository`. It decides who is at the tablet right now.
///
/// [AccountBackend] is the seam: the app uses [SupabaseAccountBackend], tests
/// use a fake, and a build with no server configured uses
/// [UnconfiguredAccountBackend]. Nothing outside this file imports Supabase.
abstract interface class AccountBackend {
  /// Whether a server is configured at all.
  bool get isAvailable;

  /// The signed-in account, restored from the device, or null.
  AccountUser? get currentUser;

  Future<AccountUser> signIn({required String email, required String password});

  /// Creates an account. Returns the signed-in user, or throws
  /// [AccountErrorCode.confirmEmail] when the server wants the address
  /// confirmed before the first sign-in.
  Future<AccountUser> signUp({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// The account's organization and role; both null before it has one.
  Future<AccountSummary> myAccount();

  /// Makes the signed-in user the owner of a new organization.
  Future<String> createOrganization(String name);

  /// Joins the organization behind a code an owner created.
  Future<String> joinOrganization(String code);

  /// A new join code for a manager. Owners only.
  Future<String> createJoinCode();

  Future<void> registerDevice(String deviceId, {String name = ''});

  Future<List<DeviceInfo>> devices();

  /// Unregisters a device. Owners only.
  Future<bool> removeDevice(String deviceId);

  /// Sends outbox entries to the server's `push_changes` (Phase 5). Each
  /// entry is `{id, table, row_key, store_id, payload}`; the answer has one
  /// [PushResult] per entry, in the same order.
  Future<List<PushResult>> pushChanges(
    String deviceId,
    List<Map<String, Object?>> changes,
  );

  /// The ids of every establishment of the account's restaurant (Phase 6).
  /// Asked of the server, not the device: a device that just joined has none.
  Future<List<String>> storeIds();

  /// One page of the server's `pull_changes`: what changed in [storeId]
  /// after change number [after], oldest first.
  Future<PullPage> pullChanges(String storeId, {required int after, int limit});

  /// Live updates for [storeIds] (Supabase realtime on `store_changes`).
  ///
  /// Emits [LiveSignal.changed] when the server's newest change number moves
  /// for one of them, and [LiveSignal.ready] each time the live connection
  /// is (re)established **and** actually watching, so whatever changed in
  /// between can be caught up. A dropped connection is also caught up by the
  /// periodic pass.
  Stream<LiveSignal> storeChanges(List<String> storeIds);

  /// Puts a photo in the private `photos` store at [path]
  /// (`<store>/<items|employees>/<file>`), replacing any file there
  /// (Phase 8).
  Future<void> uploadPhoto(
    String path,
    Uint8List bytes, {
    required String contentType,
  });

  /// The photo at [path], or null when the server has none.
  Future<Uint8List?> downloadPhoto(String path);

  /// Removes photos from the server. Missing ones are not an error.
  Future<void> removePhotos(List<String> paths);
}

/// What the live connection says (Phase 6).
enum LiveSignal {
  /// The connection is watching for changes, after opening or reopening.
  ready,

  /// Another device's change reached the server.
  changed,
}

/// One page of changes from the server.
class PullPage {
  const PullPage({
    required this.changes,
    required this.nextAfter,
    required this.hasMore,
  });

  final List<PulledChange> changes;

  /// The change number to ask after next time.
  final int nextAfter;
  final bool hasMore;
}

/// One row as the server has it now, deleted ones included.
class PulledChange {
  const PulledChange({
    required this.seq,
    required this.table,
    required this.row,
  });

  final int seq;

  /// The SQL name of the table, as in `SyncTables.synced`.
  final String table;

  /// The whole row, as the server's JSON.
  final Map<String, dynamic> row;
}

/// The server's answer for one outbox entry.
class PushResult {
  const PushResult({
    required this.id,
    required this.accepted,
    this.reason,
    this.message,
  });

  /// The outbox entry's id, as sent.
  final int id;
  final bool accepted;

  /// Why it was refused: `deleted`, `already_paid`, `device_unknown`, …
  final String? reason;

  /// The server's message, for `invalid`.
  final String? message;
}

class AccountUser {
  const AccountUser({required this.id, required this.email});

  final String id;
  final String email;
}

class AccountSummary {
  const AccountSummary({
    required this.userId,
    required this.email,
    this.organizationId,
    this.organizationName,
    this.role,
  });

  final String userId;
  final String email;
  final String? organizationId;
  final String? organizationName;

  /// `owner` or `manager`, as the server spells it.
  final String? role;

  bool get hasOrganization => organizationId != null;
}

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastSeenAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
}

enum AccountErrorCode {
  /// No server configured in this build.
  unavailable,

  /// The server could not be reached.
  network,
  badCredentials,
  emailTaken,
  weakPassword,

  /// The account exists but its e-mail address is not confirmed yet.
  confirmEmail,
  invalidCode,
  alreadyMember,
  notAllowed,

  /// The account's session ended and could not be renewed: sign in again.
  sessionExpired,
  unknown,
}

class AccountException implements Exception {
  const AccountException(this.code, [this.detail]);

  final AccountErrorCode code;
  final String? detail;

  @override
  String toString() =>
      'AccountException($code${detail == null ? '' : ': $detail'})';
}

/// The backend of a build with no server: everything refuses politely.
class UnconfiguredAccountBackend implements AccountBackend {
  const UnconfiguredAccountBackend();

  static const _refusal = AccountException(AccountErrorCode.unavailable);

  @override
  bool get isAvailable => false;

  @override
  AccountUser? get currentUser => null;

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) => Future.error(_refusal);

  @override
  Future<AccountUser> signUp({
    required String email,
    required String password,
  }) => Future.error(_refusal);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) => Future.error(_refusal);

  @override
  Future<AccountSummary> myAccount() => Future.error(_refusal);

  @override
  Future<String> createOrganization(String name) => Future.error(_refusal);

  @override
  Future<String> joinOrganization(String code) => Future.error(_refusal);

  @override
  Future<String> createJoinCode() => Future.error(_refusal);

  @override
  Future<void> registerDevice(String deviceId, {String name = ''}) =>
      Future.error(_refusal);

  @override
  Future<List<DeviceInfo>> devices() => Future.error(_refusal);

  @override
  Future<bool> removeDevice(String deviceId) => Future.error(_refusal);

  @override
  Future<List<PushResult>> pushChanges(
    String deviceId,
    List<Map<String, Object?>> changes,
  ) => Future.error(_refusal);

  @override
  Future<List<String>> storeIds() => Future.error(_refusal);

  @override
  Future<PullPage> pullChanges(
    String storeId, {
    required int after,
    int limit = 500,
  }) => Future.error(_refusal);

  @override
  Stream<LiveSignal> storeChanges(List<String> storeIds) =>
      const Stream.empty();

  @override
  Future<void> uploadPhoto(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) => Future.error(_refusal);

  @override
  Future<Uint8List?> downloadPhoto(String path) => Future.error(_refusal);

  @override
  Future<void> removePhotos(List<String> paths) => Future.error(_refusal);
}

/// The real one, over `supabase_flutter`. Supabase keeps the session on the
/// device and refreshes it when it can, so a signed-in tablet stays signed in
/// through a day without Wi-Fi.
class SupabaseAccountBackend implements AccountBackend {
  const SupabaseAccountBackend(this._client);

  final SupabaseClient _client;

  @override
  bool get isAvailable => true;

  @override
  AccountUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null
        ? null
        : AccountUser(id: user.id, email: user.email ?? '');
  }

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _userOf(response.user);
  });

  @override
  Future<AccountUser> signUp({
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw const AccountException(AccountErrorCode.confirmEmail);
    }
    return _userOf(response.user);
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email.trim()));

  @override
  Future<AccountSummary> myAccount() => _guard(() async {
    final data = await _client.rpc('my_account') as Map<String, dynamic>;
    return AccountSummary(
      userId: data['user_id'] as String,
      email: (data['email'] as String?) ?? '',
      organizationId: data['organization_id'] as String?,
      organizationName: data['organization_name'] as String?,
      role: data['role'] as String?,
    );
  });

  @override
  Future<String> createOrganization(String name) => _guard(
    () async =>
        await _client.rpc('create_organization', params: {'p_name': name})
            as String,
  );

  @override
  Future<String> joinOrganization(String code) => _guard(
    () async =>
        await _client.rpc('join_organization', params: {'p_code': code})
            as String,
  );

  @override
  Future<String> createJoinCode() =>
      _guard(() async => await _client.rpc('create_join_code') as String);

  @override
  Future<void> registerDevice(String deviceId, {String name = ''}) => _guard(
    () => _client.rpc(
      'register_device',
      params: {'p_device_id': deviceId, 'p_name': name},
    ),
  );

  @override
  Future<List<DeviceInfo>> devices() => _guard(() async {
    final rows = await _client
        .from('devices')
        .select('id, name, created_at, last_seen_at')
        .order('created_at');
    return [
      for (final row in rows)
        DeviceInfo(
          id: row['id'] as String,
          name: row['name'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          lastSeenAt: row['last_seen_at'] == null
              ? null
              : DateTime.parse(row['last_seen_at'] as String).toLocal(),
        ),
    ];
  });

  @override
  Future<bool> removeDevice(String deviceId) => _guard(
    () async =>
        await _client.rpc('remove_device', params: {'p_device_id': deviceId})
            as bool,
  );

  @override
  Future<List<PushResult>> pushChanges(
    String deviceId,
    List<Map<String, Object?>> changes,
  ) => _guard(() async {
    if (_client.auth.currentSession == null) {
      throw const AccountException(AccountErrorCode.sessionExpired);
    }
    final answer =
        await _client.rpc(
              'push_changes',
              params: {'p_device_id': deviceId, 'p_changes': changes},
            )
            as List<dynamic>;
    return [
      for (final item in answer.cast<Map<String, dynamic>>())
        PushResult(
          id: (item['id'] as num).toInt(),
          accepted: item['status'] == 'accepted',
          reason: item['reason'] as String?,
          message: item['message'] as String?,
        ),
    ];
  });

  @override
  Future<List<String>> storeIds() => _guard(() async {
    if (_client.auth.currentSession == null) {
      throw const AccountException(AccountErrorCode.sessionExpired);
    }
    // Row level security returns the caller's organization's stores only.
    final rows = await _client.from('stores').select('id').order('created_at');
    return [for (final row in rows) row['id'] as String];
  });

  @override
  Future<PullPage> pullChanges(
    String storeId, {
    required int after,
    int limit = 500,
  }) => _guard(() async {
    if (_client.auth.currentSession == null) {
      throw const AccountException(AccountErrorCode.sessionExpired);
    }
    final answer =
        await _client.rpc(
              'pull_changes',
              params: {
                'p_store_id': storeId,
                'p_after': after,
                'p_limit': limit,
              },
            )
            as Map<String, dynamic>;
    return PullPage(
      changes: [
        for (final item
            in (answer['changes'] as List).cast<Map<String, dynamic>>())
          PulledChange(
            seq: (item['seq'] as num).toInt(),
            table: item['table'] as String,
            row: (item['row'] as Map).cast<String, dynamic>(),
          ),
      ],
      nextAfter: (answer['next_after'] as num).toInt(),
      hasMore: answer['has_more'] == true,
    );
  });

  @override
  Stream<LiveSignal> storeChanges(List<String> storeIds) {
    if (storeIds.isEmpty) return const Stream.empty();
    late final RealtimeChannel channel;
    late final StreamController<LiveSignal> controller;
    controller = StreamController<LiveSignal>(
      onListen: () {
        channel = _client
            .channel(
              'store-changes-${storeIds.join(',').hashCode}',
              // "Subscribed" arrives before the server is actually watching
              // the table: its replication starts a moment later, and a
              // change in between is missed. With this, the server says when
              // it is really ready (a `system` event), and that is when the
              // catch-up pass runs.
              opts: const RealtimeChannelConfig(replicationReady: true),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'store_changes',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.inFilter,
                column: 'store_id',
                value: storeIds,
              ),
              callback: (_) => controller.add(LiveSignal.changed),
            )
            .onSystemEvents((payload) {
              if (payload is Map && payload['status'] == 'ok') {
                controller.add(LiveSignal.ready);
              }
            })
            .subscribe();
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  static const String _photoBucket = 'photos';

  @override
  Future<void> uploadPhoto(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) => _guard(
    () => _client.storage
        .from(_photoBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        ),
  );

  @override
  Future<Uint8List?> downloadPhoto(String path) => _guard(() async {
    try {
      return await _client.storage.from(_photoBucket).download(path);
    } on StorageException catch (error) {
      if (error.statusCode == '404' ||
          error.statusCode == '400' ||
          error.message.toLowerCase().contains('not found')) {
        return null;
      }
      rethrow;
    }
  });

  @override
  Future<void> removePhotos(List<String> paths) => _guard(() async {
    if (paths.isEmpty) return;
    await _client.storage.from(_photoBucket).remove(paths);
  });

  AccountUser _userOf(User? user) {
    if (user == null) throw const AccountException(AccountErrorCode.unknown);
    return AccountUser(id: user.id, email: user.email ?? '');
  }

  /// Turns Supabase's errors into the few the screens can put into words.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AccountException {
      rethrow;
    } on AuthException catch (error) {
      throw AccountException(_authCode(error), error.message);
    } on PostgrestException catch (error) {
      throw AccountException(_databaseCode(error.code), error.message);
    } on StorageException catch (error) {
      throw AccountException(
        error.statusCode == '403'
            ? AccountErrorCode.notAllowed
            : AccountErrorCode.unknown,
        error.message,
      );
    } catch (error) {
      // Socket errors, timeouts: the server was not reached.
      final text = error.toString();
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('TimeoutException') ||
          text.contains('HandshakeException')) {
        throw AccountException(AccountErrorCode.network, text);
      }
      throw AccountException(AccountErrorCode.unknown, text);
    }
  }

  static AccountErrorCode _authCode(AuthException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return AccountErrorCode.badCredentials;
      case 'user_already_exists':
      case 'email_exists':
        return AccountErrorCode.emailTaken;
      case 'weak_password':
        return AccountErrorCode.weakPassword;
      case 'email_not_confirmed':
        return AccountErrorCode.confirmEmail;
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'session_not_found':
      case 'session_expired':
        return AccountErrorCode.sessionExpired;
    }
    if (error is AuthRetryableFetchException) return AccountErrorCode.network;
    return AccountErrorCode.unknown;
  }

  /// The SQLSTATE codes the server functions raise (supabase/migrations/).
  static AccountErrorCode _databaseCode(String? code) {
    switch (code) {
      case 'P0002':
        return AccountErrorCode.invalidCode;
      case '23505':
        return AccountErrorCode.alreadyMember;
      case '42501':
        return AccountErrorCode.notAllowed;
      // PostgREST: the access token expired or is invalid.
      case 'PGRST301':
      case 'PGRST303':
        return AccountErrorCode.sessionExpired;
    }
    return AccountErrorCode.unknown;
  }
}
