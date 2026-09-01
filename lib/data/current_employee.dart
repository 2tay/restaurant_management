import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import 'providers.dart';
import 'repositories/session_repository.dart';

/// The signed-in employee, resolved and held in memory.
///
/// A [Notifier], not a `FutureProvider`, on purpose: `router.dart`'s `_guard`
/// reads the session on **every** navigation inside a `redirect` callback that
/// cannot `await`. A future-shaped session would make the guard asynchronous and
/// race the redirect ordering. So the state is a plain `Employee?` that
/// [hydrate] resolves once, before the first frame, and [signIn] / [signOut]
/// keep in step with the `meta` row as they write it.
///
/// [build] returns null — the signed-out state. `main()` (and every widget
/// test's fixture) calls [hydrate] before `runApp`, so `_guard`'s first
/// `ref.read` already sees the resolved value rather than a loading one.
class CurrentEmployee extends Notifier<Employee?> {
  @override
  Employee? build() => null;

  SessionRepository get _session => ref.read(sessionRepositoryProvider);

  /// Resolves the session from the database into [state]. Idempotent — safe to
  /// call again after the database is re-seeded (the demo reset).
  Future<void> hydrate() async {
    state = await _session.currentEmployee();
  }

  /// Signs [employeeId] in: writes the `meta` row and moves [state] in one
  /// step. Returns the resolved employee, or null when the id does not exist
  /// (in which case nothing changes).
  Future<Employee?> signIn(String employeeId) async {
    final employee = await _session.signIn(employeeId);
    if (employee != null) state = employee;
    return employee;
  }

  /// Signs out: drops the `meta` row and clears [state].
  Future<void> signOut() async {
    await _session.signOut();
    state = null;
  }
}

final NotifierProvider<CurrentEmployee, Employee?> currentEmployeeProvider =
    NotifierProvider<CurrentEmployee, Employee?>(CurrentEmployee.new);
