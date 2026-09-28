// employeeDisplayName: every word of a full name starts with a capital,
// whatever was typed — and nothing else about the casing changes.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/employee_status.dart';
import 'package:stock_inventory/models/models.dart';

Employee _named(String first, String last) => Employee(
  id: 'e',
  storeId: 's',
  firstName: first,
  lastName: last,
  pin: 'p',
  phone: '',
  email: 'e@x.test',
  hireDate: DateTime(2026),
  role: EmployeeRole.staff,
  pay: 10,
  createdAt: DateTime(2026),
);

void main() {
  test('capitalises the first letter of every word', () {
    expect(
      employeeDisplayName(_named('amélie', 'vandenberghe')),
      'Amélie Vandenberghe',
    );
    expect(employeeDisplayName(_named('ahmed', 'moha')), 'Ahmed Moha');
    expect(
      employeeDisplayName(_named('jean marc', 'de  la  tour')),
      'Jean Marc De La Tour',
    );
  });

  test('leaves the rest of each word as it was', () {
    expect(employeeDisplayName(_named('Jean-Baptiste', 'McKenna')),
        'Jean-Baptiste McKenna');
    expect(employeeDisplayName(_named('ÉLISE', 'Dupont')), 'ÉLISE Dupont');
  });

  test('copes with a missing part', () {
    expect(employeeDisplayName(_named('nora', '')), 'Nora');
    expect(employeeDisplayName(_named('  ', '')), '');
  });
}
