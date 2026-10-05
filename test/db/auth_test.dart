// The login rules — email + PIN (the CIN), the staff and archive refusals —
// and the PIN confirmation the pointage board and the payroll screen ask for.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart' show EmployeeIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

/// Emails and PINs from the seed roster.
const _marcEmail = 'marc.delvaux@brasserie-sablon.be'; // owner
const _marcPin = '78.02.14-153.24';
const _elieEmail = 'elise.dupont@brasserie-sablon.be'; // Élise — staff
const _eliePin = '03.06.09-334.02';
const _amelieEmail = 'amelie.v@brasserie-sablon.be'; // manager
const _ameliePin = '89.07.30-201.44';

void main() {
  late AppDatabase db;
  late CredentialRepository credentials;

  setUp(() async {
    db = await openSeededDatabase();
    credentials = CredentialRepository(db);
  });

  group('authenticate', () {
    test('the right email + PIN signs the owner in', () async {
      final attempt = await credentials.authenticate(_marcEmail, _marcPin);
      expect(attempt.outcome, LoginOutcome.success);
      expect(attempt.employee?.id, EmployeeIds.marc);
    });

    test('tolerates stray spaces and capitals', () async {
      final attempt = await credentials.authenticate(
        '  Marc.Delvaux@Brasserie-Sablon.be ',
        ' $_marcPin ',
      );
      expect(attempt.outcome, LoginOutcome.success);
    });

    test('an unknown email is refused', () async {
      final attempt = await credentials.authenticate('nobody@x.be', _marcPin);
      expect(attempt.outcome, LoginOutcome.unknownEmail);
      expect(attempt.employee, isNull);
    });

    test("a wrong PIN is refused — another employee's PIN too", () async {
      for (final typed in ['00.00.00-000.00', _ameliePin, '']) {
        final attempt = await credentials.authenticate(_marcEmail, typed);
        expect(attempt.outcome, LoginOutcome.wrongPin, reason: typed);
        expect(attempt.employee, isNull);
      }
    });

    test('nothing locks: the right PIN passes after many misses', () async {
      for (var i = 0; i < 10; i++) {
        await credentials.authenticate(_marcEmail, '0000');
      }
      expect(
        (await credentials.authenticate(_marcEmail, _marcPin)).outcome,
        LoginOutcome.success,
      );
    });

    test('a staff account is refused, once its PIN matched', () async {
      final attempt = await credentials.authenticate(_elieEmail, _eliePin);
      expect(attempt.outcome, LoginOutcome.noAppAccess);
      expect(attempt.employee?.role, EmployeeRole.staff);
      // Without the PIN, nothing tells the account apart.
      expect(
        (await credentials.authenticate(_elieEmail, '0000')).outcome,
        LoginOutcome.wrongPin,
      );
    });
  });

  group('archived employees', () {
    // Amélie, a manager — Marc, the only owner, cannot be archived at all.
    test('an archived employee is refused, even with the right PIN', () async {
      await EmployeeRepository(db).archive(EmployeeIds.amelie);

      final attempt = await credentials.authenticate(_amelieEmail, _ameliePin);
      expect(attempt.outcome, LoginOutcome.archived);
      expect(attempt.employee?.id, EmployeeIds.amelie);
    });

    test('restoring gives access back', () async {
      final repo = EmployeeRepository(db);
      await repo.archive(EmployeeIds.amelie);
      await repo.restore(EmployeeIds.amelie);

      final attempt = await credentials.authenticate(_amelieEmail, _ameliePin);
      expect(attempt.outcome, LoginOutcome.success);
    });
  });

  // The identity confirmation the pointage board and the payroll screen ask
  // for: the person's PIN, checked strictly against the expected employee.
  // Unlimited attempts, no lockout.
  group('verifyPin', () {
    test("the expected employee's PIN passes", () async {
      expect(await credentials.verifyPin(_marcPin, EmployeeIds.marc), isTrue);
      // Tolerates the stray spaces a kiosk keyboard adds.
      expect(
        await credentials.verifyPin(' $_marcPin ', EmployeeIds.marc),
        isTrue,
      );
    });

    test("another employee's valid PIN is refused (strict match)", () async {
      expect(await credentials.verifyPin(_eliePin, EmployeeIds.marc), isFalse);
    });

    test('an unknown PIN is refused', () async {
      expect(
        await credentials.verifyPin('00.00.00-000.00', EmployeeIds.marc),
        isFalse,
      );
    });

    test('misses are unlimited', () async {
      for (var i = 0; i < 10; i++) {
        expect(await credentials.verifyPin('0000', EmployeeIds.marc), isFalse);
      }
      expect(await credentials.verifyPin(_marcPin, EmployeeIds.marc), isTrue);
    });
  });
}
