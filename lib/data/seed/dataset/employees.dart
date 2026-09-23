import '../../../models/employee.dart';
import 'reference.dart';
import 'stores.dart';

abstract final class EmployeeIds {
  static const String marc = 'employee-marc';
  static const String amelie = 'employee-amelie';
  static const String karim = 'employee-karim';
  static const String fatima = 'employee-fatima';
  static const String elise = 'employee-elise';
  static const String noah = 'employee-noah';
  static const String julien = 'employee-julien';
  static const String camille = 'employee-camille';

  // TestCalcul — the payroll walkthrough store.
  static const String ayoub = 'employee-ayoub';
  static const String hakim = 'employee-hakim';
}

/// Names are plausible-but-invented, same reasoning as `mockSuppliers`.
///
/// Brasserie du Sablon carries the full roster:
/// - one **owner** (Marc — also `mockCurrentEmployee`), one **manager**
///   (Amélie), the rest **staff**
/// - every employee is paid an hourly rate
/// - one **archived** record (Camille) so the "retiré" state is demoable
///
/// Taverne Saint-Gilles stays **empty** — it is the README's every-empty-state
/// store, and a roster that quietly seeds it would break that.
///
/// Times are minutes since midnight: 8h00 = 480, 17h00 = 1020.
final List<Employee> mockEmployees = [
  Employee(
    id: EmployeeIds.marc,
    storeId: StoreIds.sablon,
    firstName: 'Marc',
    lastName: 'Delvaux',
    cin: '78.02.14-153.24',
    phone: '+32 475 12 88 03',
    email: 'marc.delvaux@brasserie-sablon.be',
    hireDate: monthsAgo(38),
    role: EmployeeRole.owner,
    pay: 20,
    createdAt: monthsAgo(38),
  ),
  Employee(
    id: EmployeeIds.amelie,
    storeId: StoreIds.sablon,
    firstName: 'Amélie',
    lastName: 'Vandenberghe',
    cin: '89.07.30-201.44',
    phone: '+32 471 45 22 90',
    email: 'amelie.v@brasserie-sablon.be',
    hireDate: monthsAgo(22),
    role: EmployeeRole.manager,
    pay: 16,
    createdAt: monthsAgo(22),
  ),
  Employee(
    id: EmployeeIds.karim,
    storeId: StoreIds.sablon,
    firstName: 'Karim',
    lastName: 'Haddouch',
    cin: '87.03.11-245.68',
    phone: '+32 478 22 14 09',
    email: 'karim.haddouch@brasserie-sablon.be',
    hireDate: monthsAgo(30),
    role: EmployeeRole.staff,
    pay: 13,
    createdAt: monthsAgo(30),
  ),
  Employee(
    id: EmployeeIds.fatima,
    storeId: StoreIds.sablon,
    firstName: 'Fatima',
    lastName: 'Ezzahra',
    cin: '92.11.24-118.35',
    phone: '+32 471 68 30 52',
    email: 'fatima.ezzahra@brasserie-sablon.be',
    hireDate: monthsAgo(18),
    role: EmployeeRole.staff,
    pay: 12.5,
    createdAt: monthsAgo(18),
  ),
  Employee(
    id: EmployeeIds.elise,
    storeId: StoreIds.sablon,
    firstName: 'Élise',
    lastName: 'Dupont',
    cin: '03.06.09-334.02',
    phone: '+32 486 40 27 91',
    email: 'elise.dupont@brasserie-sablon.be',
    hireDate: monthsAgo(6),
    role: EmployeeRole.staff,
    pay: 14.5,
    createdAt: monthsAgo(6),
  ),
  Employee(
    id: EmployeeIds.noah,
    storeId: StoreIds.sablon,
    firstName: 'Noah',
    lastName: 'Van Damme',
    cin: '99.01.30-410.19',
    phone: '+32 495 60 18 23',
    email: 'noah.vandamme@brasserie-sablon.be',
    hireDate: monthsAgo(2),
    role: EmployeeRole.staff,
    pay: 13.5,
    createdAt: monthsAgo(2),
  ),
  Employee(
    id: EmployeeIds.julien,
    storeId: StoreIds.sablon,
    firstName: 'Julien',
    lastName: 'Mertens',
    cin: '02.09.17-201.77',
    phone: '+32 493 15 77 40',
    email: 'julien.mertens@brasserie-sablon.be',
    hireDate: monthsAgo(4),
    role: EmployeeRole.staff,
    pay: 13,
    createdAt: monthsAgo(4),
  ),

  // Retired. Still resolvable by id, still carries its attendance history —
  // archiving never touches the attendance rows.
  Employee(
    id: EmployeeIds.camille,
    storeId: StoreIds.sablon,
    firstName: 'Camille',
    lastName: 'Rousseau',
    cin: '95.05.19-276.71',
    phone: '+32 479 33 56 12',
    email: 'camille.rousseau@brasserie-sablon.be',
    hireDate: monthsAgo(10),
    role: EmployeeRole.staff,
    pay: 13.5,
    createdAt: monthsAgo(10),
    archivedAt: daysAgo(20),
  ),

  // ---------------------------------------------------------------------------
  // TestCalcul — two people set up for hand-checking the salaire maths.
  // Hired 1 June 2026, before the 1 Jul – 1 Aug attendance range, so no day is
  // clipped by the hire-date floor.
  // ---------------------------------------------------------------------------
  Employee(
    id: EmployeeIds.ayoub,
    storeId: StoreIds.testCalcul,
    firstName: 'Ayoub',
    lastName: 'Ait Taleb',
    cin: 'AB.12.34-567.01',
    phone: '+32 470 00 00 01',
    email: 'ayoub.aittaleb@testcalcul.be',
    hireDate: DateTime(2026, 6, 1),
    role: EmployeeRole.staff,
    pay: 12.5,
    // No personal schedule — inherits the store's 08:00–22:00 day.
    createdAt: DateTime(2026, 6, 1),
  ),
  Employee(
    id: EmployeeIds.hakim,
    storeId: StoreIds.testCalcul,
    firstName: 'Hakim',
    lastName: 'Toutay',
    cin: 'CD.56.78-901.02',
    phone: '+32 470 00 00 02',
    email: 'hakim.toutay@testcalcul.be',
    hireDate: DateTime(2026, 6, 1),
    role: EmployeeRole.staff,
    pay: 15,
    createdAt: DateTime(2026, 6, 1),
  ),
];
