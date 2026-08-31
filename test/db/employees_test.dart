// Personnel records — create, edit, archive, restore.
//
// Ported from `test/employees_test.dart`: same names, same assertions, against a
// database instead of a global list. Two rules run through all of it: CIN and
// email are unique account-wide (not per store), and removal is a soft archive
// that never touches history and can be undone.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/employee_status.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/mock_data/mock_data.dart'
    show EmployeeIds, StoreIds;
import 'package:stock_inventory/models/models.dart';

import '../support/db_fixture.dart';

void main() {
  late AppDatabase db;
  late EmployeeRepository employees;
  late CredentialRepository credentials;

  setUp(() async {
    db = await openSeededDatabase();
    employees = EmployeeRepository(db);
    credentials = CredentialRepository(db);
  });

  Future<Employee?> create({
    String storeId = StoreIds.sablon,
    String firstName = 'Test',
    String lastName = 'Personne',
    String cin = '00.00.00-000.00',
    String phone = '+32 400 00 00 00',
    String email = 'test.personne@example.be',
    EmployeeRole role = EmployeeRole.staff,
    ContractType contractType = ContractType.fixed,
    double pay = 2000,
    String? pin,
  }) => employees.create(
    storeId: storeId,
    firstName: firstName,
    lastName: lastName,
    cin: cin,
    phone: phone,
    email: email,
    role: role,
    contractType: contractType,
    pay: pay,
    pin: pin,
  );

  group('creating', () {
    test('adds the employee and returns it', () async {
      final before = (await employees.employees(StoreIds.sablon)).length;
      final created = await create();

      expect(created, isNotNull);
      expect(
        (await employees.employees(StoreIds.sablon)).length,
        before + 1,
      );
      expect(await employees.employee(created!.id), isNotNull);
    });

    test('refuses an empty required field', () async {
      expect(await create(firstName: '  '), isNull);
      expect(await create(cin: ''), isNull);
      expect(await create(email: ''), isNull);
    });

    test('refuses a CIN already used, ignoring case and spacing', () async {
      final existing = (await employees.employee(EmployeeIds.marc))!;
      expect(await create(cin: ' ${existing.cin.toUpperCase()} '), isNull);
    });

    test('refuses an email already used anywhere on the account', () async {
      final existing = (await employees.employee(EmployeeIds.marc))!;
      // Same email, different store — still refused, unlike the old per-store
      // team rule.
      expect(
        await create(
          storeId: StoreIds.liege,
          email: existing.email.toUpperCase(),
        ),
        isNull,
      );
    });

    test('a refused create writes nothing', () async {
      final before = (await employees.employees(StoreIds.sablon)).length;
      await create(email: '');
      expect((await employees.employees(StoreIds.sablon)).length, before);
    });

    test('with a PIN, the credential lands in the same transaction', () async {
      final created = (await create(pin: '4321'))!;

      final credential = await credentials.forEmployee(created.id);
      expect(credential, isNotNull);
      expect(
        (await credentials.authenticate(created.cin, '4321')).employee?.id,
        created.id,
      );
    });

    test('a bad PIN refuses the whole create', () async {
      final before = (await employees.employees(StoreIds.sablon)).length;

      expect(await create(pin: '12'), isNull);
      expect(
        (await employees.employees(StoreIds.sablon)).length,
        before,
        reason: 'no employee row without its credential',
      );
    });
  });

  group('editing', () {
    test("a rename does not collide with the employee's own CIN or email",
        () async {
      final e = (await employees.employee(EmployeeIds.marc))!;
      expect(
        await employees.update(e.id, cin: e.cin, email: e.email),
        isNotNull,
      );
    });

    test("refuses another employee's CIN or email", () async {
      final a = (await employees.employee(EmployeeIds.marc))!;
      final b = (await employees.employee(EmployeeIds.amelie))!;
      expect(await employees.update(a.id, cin: b.cin), isNull);
      expect(await employees.update(a.id, email: b.email), isNull);
      expect(
        (await employees.employee(a.id))!.cin,
        a.cin,
        reason: 'a refused edit must not half-apply',
      );
    });

    test('clearSchedule wipes a custom start/end back to store hours', () async {
      final elise = (await employees.employee(EmployeeIds.elise))!;
      expect(elise.scheduledStartMinutes, isNotNull);

      final updated = await employees.update(elise.id, clearSchedule: true);
      expect(updated!.scheduledStartMinutes, isNull);
      expect(updated.scheduledEndMinutes, isNull);
    });
  });

  group('archive and restore', () {
    test('archive sets archivedAt and refuses a second time', () async {
      const id = EmployeeIds.karim;
      expect(await employees.archive(id), isTrue);
      expect((await employees.employee(id))!.archivedAt, isNotNull);
      expect(await employees.archive(id), isFalse);
    });

    test('restore clears archivedAt and refuses when not archived', () async {
      expect(await employees.restore(EmployeeIds.karim), isFalse);

      await employees.archive(EmployeeIds.karim);
      expect(await employees.restore(EmployeeIds.karim), isTrue);
      expect((await employees.employee(EmployeeIds.karim))!.archivedAt, isNull);
    });

    test('update can never change archivedAt', () async {
      final camille = (await employees.employee(EmployeeIds.camille))!;
      expect(camille.archivedAt, isNotNull);

      final updated = await employees.update(camille.id, pay: 15);
      expect(updated!.archivedAt, camille.archivedAt);
    });

    test('an archived employee is off the active roster but still resolvable',
        () async {
      final active = await employees.activeEmployees(StoreIds.sablon);
      expect(
        active.any((e) => e.id == EmployeeIds.camille),
        isFalse,
        reason: 'Camille is archived in the seed',
      );
      expect(await employees.employee(EmployeeIds.camille), isNotNull);
      expect(
        isEmployeeActive((await employees.employee(EmployeeIds.camille))!),
        isFalse,
      );
    });
  });
}
