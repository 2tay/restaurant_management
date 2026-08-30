// The login rules — CIN + PIN, the failed-attempt lockout, and the staff
// refusal. Styled like orders_test.dart: this is the part of Phase 6 with
// actual behaviour, run against the in-memory credential layer.
//
// Still fake (no backend, no real hash), but the state machine — attempts,
// lockout, reset on success — is real and pinned here.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/credential_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

/// CINs from the seed roster.
const _marcCin = '78.02.14-153.24'; // owner
const _elieCin = '03.06.09-334.02'; // Élise — staff, no app access

void main() {
  setUp(restoreMockData);

  group('authenticate', () {
    test('correct CIN + PIN signs the owner in and stamps the login', () {
      final at = DateTime(2026, 8, 30, 9);
      final attempt = CredentialMutations.authenticate(
        _marcCin,
        '1234',
        now: at,
      );

      expect(attempt.outcome, LoginOutcome.success);
      expect(attempt.employee?.id, EmployeeIds.marc);
      expect(
        MockQueries.credentialForEmployee(EmployeeIds.marc)!.lastLoginAt,
        at,
      );
    });

    test('an unknown CIN is rejected without touching anything', () {
      final attempt = CredentialMutations.authenticate('00.00.00-000.00', '1234');
      expect(attempt.outcome, LoginOutcome.unknownCin);
      expect(attempt.employee, isNull);
    });

    test('a wrong PIN counts as a failed attempt', () {
      final attempt = CredentialMutations.authenticate(_marcCin, '0000');
      expect(attempt.outcome, LoginOutcome.wrongPin);
      expect(
        MockQueries.credentialForEmployee(EmployeeIds.marc)!.failedAttempts,
        1,
      );
    });

    test('the account locks on the ${AuthRules.maxFailedAttempts}th wrong PIN',
        () {
      final at = DateTime(2026, 8, 30, 9);
      LoginAttempt? last;
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        last = CredentialMutations.authenticate(_marcCin, '0000', now: at);
      }

      expect(last!.outcome, LoginOutcome.locked);
      final credential = MockQueries.credentialForEmployee(EmployeeIds.marc)!;
      expect(credential.lockedUntil, at.add(AuthRules.lockoutDuration));
    });

    test('a locked account refuses even the correct PIN until it expires', () {
      final locked = DateTime(2026, 8, 30, 9);
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        CredentialMutations.authenticate(_marcCin, '0000', now: locked);
      }

      final duringLock = CredentialMutations.authenticate(
        _marcCin,
        '1234',
        now: locked.add(const Duration(minutes: 1)),
      );
      expect(duringLock.outcome, LoginOutcome.locked);

      final afterLock = CredentialMutations.authenticate(
        _marcCin,
        '1234',
        now: locked.add(AuthRules.lockoutDuration).add(const Duration(minutes: 1)),
      );
      expect(afterLock.outcome, LoginOutcome.success);
      // A success wipes the counter and the lock.
      final credential = MockQueries.credentialForEmployee(EmployeeIds.marc)!;
      expect(credential.failedAttempts, 0);
      expect(credential.lockedUntil, isNull);
    });

    test('a staff account is refused even with the right PIN, counters intact',
        () {
      final attempt = CredentialMutations.authenticate(_elieCin, '1234');
      expect(attempt.outcome, LoginOutcome.noAppAccess);
      expect(attempt.employee?.role, EmployeeRole.staff);

      final credential = MockQueries.credentialForEmployee(EmployeeIds.elise)!;
      expect(credential.failedAttempts, 0);
      expect(credential.lastLoginAt, isNull);
    });
  });

  group('setPin / unlock', () {
    test('setPin replaces the PIN and clears any lockout', () {
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        CredentialMutations.authenticate(_marcCin, '0000');
      }
      expect(
        MockQueries.credentialForEmployee(EmployeeIds.marc)!.lockedUntil,
        isNotNull,
      );

      final updated = CredentialMutations.setPin(EmployeeIds.marc, '5678');
      expect(updated, isNotNull);
      expect(updated!.failedAttempts, 0);
      expect(updated.lockedUntil, isNull);

      expect(
        CredentialMutations.authenticate(_marcCin, '5678').outcome,
        LoginOutcome.success,
      );
      expect(
        CredentialMutations.authenticate(_marcCin, '1234').outcome,
        LoginOutcome.wrongPin,
      );
    });

    test('setPin rejects a PIN that is not ${AuthRules.pinLength} digits', () {
      expect(CredentialMutations.setPin(EmployeeIds.marc, '12'), isNull);
      expect(CredentialMutations.setPin(EmployeeIds.marc, 'abcd'), isNull);
      expect(CredentialMutations.setPin('nobody', '1234'), isNull);
    });

    test('unlock lifts a lockout early', () {
      for (var i = 0; i < AuthRules.maxFailedAttempts; i++) {
        CredentialMutations.authenticate(_marcCin, '0000');
      }

      expect(CredentialMutations.unlock(EmployeeIds.marc), isTrue);
      final credential = MockQueries.credentialForEmployee(EmployeeIds.marc)!;
      expect(credential.failedAttempts, 0);
      expect(credential.lockedUntil, isNull);

      // Nothing to lift the second time.
      expect(CredentialMutations.unlock(EmployeeIds.marc), isFalse);
    });
  });

  test('reset restores the credentials to the seed', () {
    CredentialMutations.setPin(EmployeeIds.marc, '9999');
    expect(
      CredentialMutations.authenticate(_marcCin, '9999').outcome,
      LoginOutcome.success,
    );

    MockWrite.reset();

    expect(
      CredentialMutations.authenticate(_marcCin, '1234').outcome,
      LoginOutcome.success,
    );
  });
}
