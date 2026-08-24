// Personnel — the roster, and the one rule that matters for it: archiving is
// a soft removal that never touches attendance.
//
// Two rules run through all of it: email is unique per store (employees are
// per-store, unlike team members), and `archivedAt` is the single source of
// truth for whether someone is active — reachable only through `archive`,
// never through `update`.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/employee_status.dart';
import 'package:stock_inventory/core/utils/timeclock_status.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';
import 'package:stock_inventory/models/models.dart';

import 'support/mock_reset.dart';

void main() {
  setUp(restoreMockData);

  group('creating an employee', () {
    test('adds it to the store and returns it', () {
      final before = MockQueries.employeesForStore(StoreIds.sablon).length;

      final created = EmployeeMutations.create(
        storeId: StoreIds.sablon,
        fullName: 'Aïcha Benali',
        email: 'aicha.benali@brasserie-sablon.be',
        phone: '+32 470 11 22 33',
        address: 'Rue de la Paix 1, 1000 Bruxelles',
        cin: '00.01.02-345.67',
        type: EmployeeType.extra,
        payType: PayType.hourlyRate,
        payRate: 13,
      );

      expect(created, isNotNull);
      expect(created!.fullName, 'Aïcha Benali');
      expect(created.storeId, StoreIds.sablon);
      expect(created.archivedAt, isNull);
      expect(MockQueries.employeesForStore(StoreIds.sablon).length, before + 1);
      expect(MockQueries.employeeById(created.id), isNotNull);
    });

    test('refuses an empty required field', () {
      expect(
        EmployeeMutations.create(
          storeId: StoreIds.sablon,
          fullName: '   ',
          email: 'x@brasserie-sablon.be',
          phone: '+32 470 11 22 33',
          address: 'Rue de la Paix 1',
          cin: '00.01.02-345.67',
          type: EmployeeType.extra,
          payType: PayType.hourlyRate,
          payRate: 13,
        ),
        isNull,
      );
    });

    test('refuses a duplicate email within the same store', () {
      final existing = MockQueries.employeesForStore(StoreIds.sablon).first;

      expect(
        EmployeeMutations.create(
          storeId: StoreIds.sablon,
          fullName: 'Someone Else',
          email: existing.email,
          phone: '+32 470 11 22 33',
          address: 'Rue de la Paix 1',
          cin: '00.01.02-345.67',
          type: EmployeeType.extra,
          payType: PayType.hourlyRate,
          payRate: 13,
        ),
        isNull,
      );
    });

    test('allows the same email in a different store', () {
      final existing = MockQueries.employeesForStore(StoreIds.sablon).first;

      expect(
        EmployeeMutations.create(
          storeId: StoreIds.liege,
          fullName: 'Someone Else',
          email: existing.email,
          phone: '+32 470 11 22 33',
          address: 'Rue de la Paix 1',
          cin: '00.01.02-345.67',
          type: EmployeeType.extra,
          payType: PayType.hourlyRate,
          payRate: 13,
        ),
        isNotNull,
        reason: 'employees are per-store; the same email can work two jobs',
      );
    });
  });

  group('editing an employee', () {
    test('a rename to its own email does not collide with itself', () {
      final employee = MockQueries.employeesForStore(StoreIds.sablon).first;

      expect(
        EmployeeMutations.update(employee.id, email: employee.email),
        isNotNull,
      );
    });

    test('cannot change archivedAt no matter what is passed', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere(isEmployeeActive);

      final updated = EmployeeMutations.update(
        employee.id,
        fullName: 'Renamed',
      );

      expect(updated, isNotNull);
      expect(
        updated!.archivedAt,
        isNull,
        reason: 'archiving is EmployeeMutations.archive alone',
      );
      // EmployeeMutations.update has no archivedAt parameter at all — there is
      // no argument that could smuggle one in. This pins that the resulting
      // record still reads as active either way.
      expect(isEmployeeActive(MockQueries.employeeById(employee.id)!), isTrue);
    });

    test('refuses an email already used by another employee in the store', () {
      final employees = MockQueries.employeesForStore(StoreIds.sablon);
      final a = employees[0];
      final b = employees[1];

      expect(EmployeeMutations.update(a.id, email: b.email), isNull);
    });
  });

  group('archiving an employee', () {
    test('sets archivedAt', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere(isEmployeeActive);

      final ok = EmployeeMutations.archive(employee.id);

      expect(ok, isTrue);
      expect(MockQueries.employeeById(employee.id)!.archivedAt, isNotNull);
    });

    test('does not touch mockTimeEntries', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere(isEmployeeActive);
      final before = MockQueries.timeEntriesForEmployee(employee.id);

      EmployeeMutations.archive(employee.id);

      expect(
        MockQueries.timeEntriesForEmployee(employee.id).length,
        before.length,
        reason: 'archiving a person must not touch their attendance history',
      );
    });

    test('is refused on an already-archived id', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere((e) => !isEmployeeActive(e));

      expect(EmployeeMutations.archive(employee.id), isFalse);
    });

    test('excludes the employee from activeEmployeesForStore', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere(isEmployeeActive);

      EmployeeMutations.archive(employee.id);

      expect(
        MockQueries.activeEmployeesForStore(
          StoreIds.sablon,
        ).any((e) => e.id == employee.id),
        isFalse,
      );
    });

    test(
      'still resolves by id after archiving — the detail page must still open',
      () {
        final employee = MockQueries.employeesForStore(
          StoreIds.sablon,
        ).firstWhere(isEmployeeActive);

        EmployeeMutations.archive(employee.id);

        expect(MockQueries.employeeById(employee.id), isNotNull);
      },
    );
  });

  group('linking an application account', () {
    test('linkTeamMember sets teamMemberId and returns the employee', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere((e) => e.teamMemberId == null);

      final updated = EmployeeMutations.linkTeamMember(
        employee.id,
        'user-amelie',
      );

      expect(updated, isNotNull);
      expect(updated!.teamMemberId, 'user-amelie');
      expect(
        MockQueries.employeeById(employee.id)!.teamMemberId,
        'user-amelie',
      );
    });

    test('update() does not disturb an existing link', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere((e) => e.teamMemberId != null);

      final updated = EmployeeMutations.update(
        employee.id,
        fullName: 'Renamed',
      );

      expect(updated!.teamMemberId, employee.teamMemberId);
    });

    test('archive() does not clear an existing link', () {
      final employee = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).firstWhere((e) => e.teamMemberId != null && isEmployeeActive(e));

      EmployeeMutations.archive(employee.id);

      expect(
        MockQueries.employeeById(employee.id)!.teamMemberId,
        employee.teamMemberId,
        reason: 'losing personnel status is not the same as losing app access',
      );
    });

    test(
      'clearTeamMemberLink only touches employees linked to that account',
      () {
        final linked = MockQueries.employeesForStore(
          StoreIds.sablon,
        ).firstWhere((e) => e.teamMemberId != null);
        final untouchedId = MockQueries.employeesForStore(
          StoreIds.sablon,
        ).firstWhere((e) => e.id != linked.id).id;
        final untouchedBefore = MockQueries.employeeById(
          untouchedId,
        )!.teamMemberId;

        EmployeeMutations.clearTeamMemberLink(linked.teamMemberId!);

        expect(MockQueries.employeeById(linked.id)!.teamMemberId, isNull);
        expect(
          MockQueries.employeeById(untouchedId)!.teamMemberId,
          untouchedBefore,
        );
      },
    );

    test('clearTeamMemberLink is a no-op for an id nobody links to', () {
      final before = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).map((e) => e.teamMemberId).toList();

      EmployeeMutations.clearTeamMemberLink('user-does-not-exist');

      final after = MockQueries.employeesForStore(
        StoreIds.sablon,
      ).map((e) => e.teamMemberId).toList();
      expect(after, before);
    });
  });

  group('the seeded dataset', () {
    test('Karim Haddouch is linked to a team account, as a worked example', () {
      final karim = MockQueries.employeeById(EmployeeIds.karim);
      expect(karim!.teamMemberId, isNotNull);
      expect(MockQueries.teamMemberById(karim.teamMemberId!), isNotNull);
    });

    test('covers every EmployeeType and PayType', () {
      final employees = MockQueries.employeesForStore(StoreIds.sablon);

      for (final type in EmployeeType.values) {
        expect(
          employees.any((e) => e.type == type),
          isTrue,
          reason: '$type has no example in the seed',
        );
      }
      for (final payType in PayType.values) {
        expect(
          employees.any((e) => e.payType == payType),
          isTrue,
          reason: '$payType has no example in the seed',
        );
      }
    });

    test('includes at least one archived employee', () {
      expect(
        MockQueries.employeesForStore(
          StoreIds.sablon,
        ).any((e) => !isEmployeeActive(e)),
        isTrue,
      );
    });

    test('Taverne Saint-Gilles stays empty', () {
      expect(MockQueries.employeesForStore(StoreIds.saintGilles), isEmpty);
    });

    test('time entries span several distinct days', () {
      final dates = mockTimeEntries.map((e) => e.date).toSet();
      expect(
        dates.length,
        greaterThan(1),
        reason: "Stage 3's date-range filter needs more than one day",
      );
    });

    test('includes at least one late break and one shift with overtime', () {
      expect(mockTimeEntries.any((e) => e.isLate), isTrue);

      final hasOvertime = mockTimeEntries.any((e) {
        final over = overtime(e);
        return over != null && over > Duration.zero;
      });
      expect(hasOvertime, isTrue);
    });
  });
}
