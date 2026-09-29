// The real account backend against a running Supabase (SYNC_PLAN.md,
// Phase 4).
//
// Skipped unless the server is named. With the local stack running:
//
//   supabase start
//   flutter test test/integration --dart-define-from-file=config/local.json
//
// Every run signs up fresh addresses, so it can be repeated against the same
// local database; `supabase db reset` clears them.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_inventory/core/config/env.dart';
import 'package:stock_inventory/services/auth_service.dart';

void main() {
  final skip = Env.hasServer
      ? false
      : 'no server: run with --dart-define-from-file=config/local.json';

  SupabaseAccountBackend backendFor() => SupabaseAccountBackend(
    SupabaseClient(
      Env.supabaseUrl,
      Env.supabasePublishableKey,
      // The app's client (`Supabase.initialize`) gets persistent storage for
      // the PKCE flow; a bare test client has none, so it uses the implicit
      // flow. Sign-up and sign-in with a password behave the same.
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    ),
  );

  final run = DateTime.now().microsecondsSinceEpoch;
  final ownerEmail = 'owner-$run@example.test';
  final managerEmail = 'manager-$run@example.test';
  const password = 'motdepasse-local';

  test('an owner signs up, creates a restaurant, invites a manager, '
      'and manages devices', () async {
    final owner = backendFor();
    await owner.signUp(email: ownerEmail, password: password);
    expect(owner.currentUser?.email, ownerEmail);

    var summary = await owner.myAccount();
    expect(summary.hasOrganization, isFalse);

    await owner.createOrganization('Resto $run');
    summary = await owner.myAccount();
    expect(summary.organizationName, 'Resto $run');
    expect(summary.role, 'owner');

    await owner.registerDevice('device-$run-a', name: 'Cuisine');
    final code = await owner.createJoinCode();
    expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));

    final manager = backendFor();
    await manager.signUp(email: managerEmail, password: password);
    await expectLater(
      manager.joinOrganization('WRONG234'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.code,
          'code',
          AccountErrorCode.invalidCode,
        ),
      ),
    );
    await manager.joinOrganization(code.toLowerCase());
    final managerSummary = await manager.myAccount();
    expect(managerSummary.organizationId, summary.organizationId);
    expect(managerSummary.role, 'manager');
    await manager.registerDevice('device-$run-b', name: 'Bar');

    await expectLater(
      manager.createJoinCode(),
      throwsA(
        isA<AccountException>().having(
          (e) => e.code,
          'code',
          AccountErrorCode.notAllowed,
        ),
      ),
    );

    final devices = await owner.devices();
    expect(
      devices.map((d) => d.id),
      containsAll(['device-$run-a', 'device-$run-b']),
    );
    expect(await owner.removeDevice('device-$run-b'), isTrue);
    expect(
      (await owner.devices()).map((d) => d.id),
      isNot(contains('device-$run-b')),
    );

    await owner.signOut();
    expect(owner.currentUser, isNull);
  }, skip: skip);

  test('errors come back as codes the screens can word', () async {
    final backend = backendFor();
    await expectLater(
      backend.signIn(email: 'nobody-$run@example.test', password: 'whatever1'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.code,
          'code',
          AccountErrorCode.badCredentials,
        ),
      ),
    );
    await expectLater(
      backend.signUp(email: ownerEmail, password: password),
      throwsA(
        isA<AccountException>().having(
          (e) => e.code,
          'code',
          AccountErrorCode.emailTaken,
        ),
      ),
    );
    await expectLater(
      backendFor().signUp(email: 'short-$run@example.test', password: 'abc'),
      throwsA(
        isA<AccountException>().having(
          (e) => e.code,
          'code',
          AccountErrorCode.weakPassword,
        ),
      ),
    );
  }, skip: skip);
}
