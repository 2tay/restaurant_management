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
    }
    return AccountErrorCode.unknown;
  }
}
