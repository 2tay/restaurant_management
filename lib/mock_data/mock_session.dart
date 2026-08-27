import '../models/models.dart';
import 'mock_employees.dart';

/// The signed-in user.
///
/// Phase 2 replaces the Phase 1 name stub with a real [Employee] — the owner
/// of Brasserie du Sablon. Read by the top-bar avatar, the dashboard greeting
/// and the account settings screen. Phase 6 makes this the result of an
/// actual login (CIN + PIN) rather than a fixed pick.
final Employee mockCurrentEmployee = mockEmployees.firstWhere(
  (e) => e.id == EmployeeIds.marc,
);
