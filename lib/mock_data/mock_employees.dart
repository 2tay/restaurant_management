import '../models/employee.dart';
import 'mock_reference.dart';
import 'mock_stores.dart';

abstract final class EmployeeIds {
  static const String karim = 'employee-karim';
  static const String elise = 'employee-elise';
  static const String noah = 'employee-noah';
  static const String fatima = 'employee-fatima';
  static const String julien = 'employee-julien';
  static const String camille = 'employee-camille';
}

/// Names are plausible-but-invented, same reasoning as `mockSuppliers`.
///
/// Brasserie du Sablon carries the full roster: one of each [EmployeeType]
/// and each [PayType], and one archived record (Camille) so the "retiré"
/// state is demoable rather than described. Taverne Saint-Gilles stays
/// empty — it is the brand-new store the README uses to exercise every empty
/// state, and an employees list that quietly seeds it would break that.
///
/// Karim carries `teamMemberId` — linked to `mockTeam`'s `user-karim` (see
/// `mock_team.dart`) — so the "Accès à l'application" state on the employee
/// detail page has a real example to show rather than only the empty
/// "not linked" state.
final List<Employee> mockEmployees = [
  Employee(
    id: EmployeeIds.karim,
    storeId: StoreIds.sablon,
    fullName: 'Karim Haddouch',
    email: 'karim.haddouch@brasserie-sablon.be',
    phone: '+32 478 22 14 09',
    address: 'Rue Haute 51, 1000 Bruxelles',
    cin: '87.03.11-245.68',
    type: EmployeeType.fixedSalary,
    payType: PayType.monthlySalary,
    payRate: 2600,
    createdAt: monthsAgo(30),
    teamMemberId: 'user-karim',
  ),
  Employee(
    id: EmployeeIds.fatima,
    storeId: StoreIds.sablon,
    fullName: 'Fatima Ezzahra',
    email: 'fatima.ezzahra@brasserie-sablon.be',
    phone: '+32 471 68 30 52',
    address: 'Rue des Renards 14, 1000 Bruxelles',
    cin: '92.11.24-118.35',
    type: EmployeeType.fixedSalary,
    payType: PayType.monthlySalary,
    payRate: 2100,
    createdAt: monthsAgo(18),
  ),
  Employee(
    id: EmployeeIds.elise,
    storeId: StoreIds.sablon,
    fullName: 'Élise Dupont',
    email: 'elise.dupont@brasserie-sablon.be',
    phone: '+32 486 40 27 91',
    address: 'Avenue Louise 220, 1050 Bruxelles',
    cin: '03.06.09-334.02',
    type: EmployeeType.student,
    payType: PayType.hourlyRate,
    payRate: 12.5,
    createdAt: monthsAgo(6),
  ),
  Employee(
    id: EmployeeIds.julien,
    storeId: StoreIds.sablon,
    fullName: 'Julien Mertens',
    email: 'julien.mertens@brasserie-sablon.be',
    phone: '+32 493 15 77 40',
    address: 'Chaussée de Wavre 88, 1050 Bruxelles',
    cin: '02.09.17-201.44',
    type: EmployeeType.student,
    payType: PayType.hourlyRate,
    payRate: 11.8,
    createdAt: monthsAgo(4),
  ),
  Employee(
    id: EmployeeIds.noah,
    storeId: StoreIds.sablon,
    fullName: 'Noah Van Damme',
    email: 'noah.vandamme@brasserie-sablon.be',
    phone: '+32 495 60 18 23',
    address: 'Rue Blaes 77, 1000 Bruxelles',
    cin: '99.01.30-410.19',
    type: EmployeeType.extra,
    payType: PayType.hourlyRate,
    payRate: 14,
    createdAt: monthsAgo(2),
  ),

  // Retired. Still resolvable by id and still carries its clock history —
  // archiving never touches `mockTimeEntries`.
  Employee(
    id: EmployeeIds.camille,
    storeId: StoreIds.sablon,
    fullName: 'Camille Rousseau',
    email: 'camille.rousseau@brasserie-sablon.be',
    phone: '+32 479 33 56 12',
    address: 'Rue de la Régence 3, 1000 Bruxelles',
    cin: '95.05.19-276.71',
    type: EmployeeType.extra,
    payType: PayType.hourlyRate,
    payRate: 13.5,
    createdAt: monthsAgo(10),
    archivedAt: daysAgo(20),
  ),
];
