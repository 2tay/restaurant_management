// The login rules — CIN + PIN, the failed-attempt lockout, and the staff
// refusal.
//
// Ported from `test/auth_test.dart`: same names, same assertions, against the
// database credential layer instead of the in-memory one. Still fake (no
// backend, no real hash), but the state machine — attempts, lockout, reset on
// success — is real and pinned here. The lockout-timing tests keep pinning
// `now`.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/credential_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart' show EmployeeIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

/// CINs from the seed roster.
const _marcCin = '78.02.14-153.24'; // owner
const _elieCin = '03.06.09-334.02'; // Élise — staff, no app access

void main() {
  late AppDatabase db;
  late CredentialRepository credentials;

  setUp(() async {
    db = await openSeededDatabase();
    credentials = CredentialRepository(db);
  });

  group('authenticate', () {
    test('correct CIN + PIN signs the owner in and stamps the login', () async {
      final at = DateTime(2026, 8, 30, 9);
      final attempt = await credentials.authenticate(_marcCin, '1234', now: at);

      expect(attempt.outcome, LoginOutcome.success);
      expect(attempt.employee?.id, EmployeeIds.marc);
      expect(
        (await credentials.forEmployee(EmployeeIds.marc))!.lastLoginAt,
        at,
      );
    });

    test('an unknown CIN is rejected without touching anything', () async {
      final attempt = await credentials.authenticate('00.00.00-000.00', '1234');
      expect(attempt.outcome, LoginOutcome.unknownCin);
      expect(attempt.employee, isNull);
    });

    test('a wrong PIN counts as a failed attempt', () async {
      final attempt = await credentials.authenticate(_marcCin, '0000');
      expect(attempt.outcome, LoginOutcome.wrongPin);
      expect(
        (await credentials.forEmployee(EmployeeIds.marc))!.failedAttempts,
        1,
      );
    });

    test('the account locks on the ${AuthRules.maxFailedAttempts}th wrong PIN',
        () async {
      final at = DateTime(2026, 8, 30, 9);
      LoginAttempt? last;
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        last = await credentials.authenticate(_marcCin, '0000', now: at);
      }

      expect(last!.outcome, LoginOutcome.locked);
      final credential = (await credentials.forEmployee(EmployeeIds.marc))!;
      expect(credential.lockedUntil, at.add(AuthRules.lockoutDuration));
    });

    test('a locked account refuses even the correct PIN until it expires',
        () async {
      final locked = DateTime(2026, 8, 30, 9);
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        await credentials.authenticate(_marcCin, '0000', now: locked);
      }

      final duringLock = await credentials.authenticate(
        _marcCin,
        '1234',
        now: locked.add(const Duration(minutes: 1)),
      );
      expect(duringLock.outcome, LoginOutcome.locked);

      final afterLock = await credentials.authenticate(
        _marcCin,
        '1234',
        now: locked
            .add(AuthRules.lockoutDuration)
            .add(const Duration(minutes: 1)),
      );
      expect(afterLock.outcome, LoginOutcome.success);
      // A success wipes the counter and the lock.
      final credential = (await credentials.forEmployee(EmployeeIds.marc))!;
      expect(credential.failedAttempts, 0);
      expect(credential.lockedUntil, isNull);
    });

    test('a staff account is refused even with the right PIN, counters intact',
        () async {
      final attempt = await credentials.authenticate(_elieCin, '1234');
      expect(attempt.outcome, LoginOutcome.noAppAccess);
      expect(attempt.employee?.role, EmployeeRole.staff);

      final credential = (await credentials.forEmployee(EmployeeIds.elise))!;
      expect(credential.failedAttempts, 0);
      expect(credential.lastLoginAt, isNull);
    });
  });

  group('setPin / unlock', () {
    test('setPin replaces the PIN and clears any lockout', () async {
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        await credentials.authenticate(_marcCin, '0000');
      }
      expect(
        (await credentials.forEmployee(EmployeeIds.marc))!.lockedUntil,
        isNotNull,
      );

      final updated = await credentials.setPin(EmployeeIds.marc, '5678');
      expect(updated, isNotNull);
      expect(updated!.failedAttempts, 0);
      expect(updated.lockedUntil, isNull);

      expect(
        (await credentials.authenticate(_marcCin, '5678')).outcome,
        LoginOutcome.success,
      );
      expect(
        (await credentials.authenticate(_marcCin, '1234')).outcome,
        LoginOutcome.wrongPin,
      );
    });

    test('setPin rejects a PIN that is not ${AuthRules.pinLength} digits',
        () async {
      expect(await credentials.setPin(EmployeeIds.marc, '12'), isNull);
      expect(await credentials.setPin(EmployeeIds.marc, 'abcd'), isNull);
      expect(await credentials.setPin('nobody', '1234'), isNull);
    });

    test('unlock lifts a lockout early', () async {
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        await credentials.authenticate(_marcCin, '0000');
      }

      expect(await credentials.unlock(EmployeeIds.marc), isTrue);
      final credential = (await credentials.forEmployee(EmployeeIds.marc))!;
      expect(credential.failedAttempts, 0);
      expect(credential.lockedUntil, isNull);

      // Nothing to lift the second time.
      expect(await credentials.unlock(EmployeeIds.marc), isFalse);
    });
  });
}
