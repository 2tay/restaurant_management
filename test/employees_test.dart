// Personnel records — create, edit, archive, restore.
//
// Two rules run through all of it: CIN and email are unique account-wide (not
// per store, unlike the old team lookup), and removal is a soft archive that
// never touches history and can be undone.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/employee_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

Employee? _create({
  String storeId = StoreIds.sablon,
  String firstName = 'Test',
  String lastName = 'Personne',
  String cin = '00.00.00-000.00',
  String phone = '+32 400 00 00 00',
  String email = 'test.personne@example.be',
  EmployeeRole role = EmployeeRole.staff,
  ContractType contractType = ContractType.fixed,
  double pay = 2000,
}) => EmployeeMutations.create(
  storeId: storeId,
  firstName: firstName,
  lastName: lastName,
  cin: cin,
  phone: phone,
  email: email,
  role: role,
  contractType: contractType,
  pay: pay,
);

void main() {
  setUp(restoreMockData);

  group('creating', () {
    test('adds the employee and returns it', () {
      final before = MockQueries.employeesForStore(StoreIds.sablon).length;
      final created = _create();

      expect(created, isNotNull);
      expect(
        MockQueries.employeesForStore(StoreIds.sablon).length,
        before + 1,
      );
      expect(MockQueries.employeeById(created!.id), isNotNull);
    });

    test('refuses an empty required field', () {
      expect(_create(firstName: '  '), isNull);
      expect(_create(cin: ''), isNull);
      expect(_create(email: ''), isNull);
    });

    test('refuses a CIN already used, ignoring case and spacing', () {
      final existing = mockEmployees.first;
      expect(_create(cin: ' ${existing.cin.toUpperCase()} '), isNull);
    });

    test('refuses an email already used anywhere on the account', () {
      final existing = mockEmployees.first;
      // Same email, different store — still refused, unlike the old per-store
      // team rule.
      expect(
        _create(storeId: StoreIds.liege, email: existing.email.toUpperCase()),
        isNull,
      );
    });
  });

  group('editing', () {
    test('a rename does not collide with the employee\'s own CIN or email', () {
      final e = mockEmployees.first;
      expect(
        EmployeeMutations.update(e.id, cin: e.cin, email: e.email),
        isNotNull,
      );
    });

    test('refuses another employee\'s CIN or email', () {
      final a = mockEmployees[0];
      final b = mockEmployees[1];
      expect(EmployeeMutations.update(a.id, cin: b.cin), isNull);
      expect(EmployeeMutations.update(a.id, email: b.email), isNull);
    });

    test('clearSchedule wipes a custom start/end back to store hours', () {
      final elise = MockQueries.employeeById(EmployeeIds.elise)!;
      expect(elise.scheduledStartMinutes, isNotNull);

      final updated = EmployeeMutations.update(elise.id, clearSchedule: true);
      expect(updated!.scheduledStartMinutes, isNull);
      expect(updated.scheduledEndMinutes, isNull);
    });
  });

  group('archive and restore', () {
    test('archive sets archivedAt and refuses a second time', () {
      const id = EmployeeIds.karim;
      expect(EmployeeMutations.archive(id), isTrue);
      expect(MockQueries.employeeById(id)!.archivedAt, isNotNull);
      expect(EmployeeMutations.archive(id), isFalse);
    });

    test('restore clears archivedAt and refuses when not archived', () {
      expect(EmployeeMutations.restore(EmployeeIds.karim), isFalse);

      EmployeeMutations.archive(EmployeeIds.karim);
      expect(EmployeeMutations.restore(EmployeeIds.karim), isTrue);
      expect(MockQueries.employeeById(EmployeeIds.karim)!.archivedAt, isNull);
    });

    test('update can never change archivedAt', () {
      final camille = MockQueries.employeeById(EmployeeIds.camille)!;
      expect(camille.archivedAt, isNotNull);

      final updated = EmployeeMutations.update(camille.id, pay: 15);
      expect(updated!.archivedAt, camille.archivedAt);
    });

    test('an archived employee is off the active roster but still resolvable',
        () {
      final active = MockQueries.activeEmployeesForStore(StoreIds.sablon);
      expect(
        active.any((e) => e.id == EmployeeIds.camille),
        isFalse,
        reason: 'Camille is archived in the seed',
      );
      expect(MockQueries.employeeById(EmployeeIds.camille), isNotNull);
      expect(
        isEmployeeActive(MockQueries.employeeById(EmployeeIds.camille)!),
        isFalse,
      );
    });
  });

  test('reset restores mockEmployees to the seed', () {
    final before = mockEmployees.length;
    _create();
    expect(mockEmployees.length, before + 1);

    MockWrite.reset();
    expect(mockEmployees.length, before);
  });
}
