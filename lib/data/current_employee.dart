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
/// A synchronous snapshot of [currentEmployeeProvider]'s state.
///
/// For the one caller that cannot hold a `Ref` and cannot await:
/// `router.dart`'s `_guard`, which runs inside a go_router `redirect` on every
/// navigation. [CurrentEmployee] is the only writer — it updates this on every
/// state change so the guard and the provider never disagree.
///
/// A widget test that pumps the app without going through `main()` sets it via
/// [seedCurrentEmployeeSnapshot] in its fixture, the same way the old
/// `MockSession` default worked.
Employee? currentEmployeeSnapshot;

/// Test-only: seed [currentEmployeeSnapshot] directly. Used by `db_fixture` /
/// `app_harness` so a pumped app starts from a known session without a login.
void seedCurrentEmployeeSnapshot(Employee? employee) {
  currentEmployeeSnapshot = employee;
}

class CurrentEmployee extends Notifier<Employee?> {
  @override
  Employee? build() => currentEmployeeSnapshot;

  SessionRepository get _session => ref.read(sessionRepositoryProvider);

  void _set(Employee? employee) {
    state = employee;
    currentEmployeeSnapshot = employee;
  }

  /// Resolves the session from the database into [state]. Idempotent — safe to
  /// call again after the database is re-seeded (the demo reset).
  Future<void> hydrate() async {
    _set(await _session.currentEmployee());
  }

  /// Signs [employeeId] in: writes the `meta` row and moves [state] in one
  /// step. Returns the resolved employee, or null when the id does not exist
  /// (in which case nothing changes).
  Future<Employee?> signIn(String employeeId) async {
    final employee = await _session.signIn(employeeId);
    if (employee != null) _set(employee);
    return employee;
  }

  /// Signs out: drops the `meta` row and clears [state].
  Future<void> signOut() async {
    await _session.signOut();
    _set(null);
  }
}

final NotifierProvider<CurrentEmployee, Employee?> currentEmployeeProvider =
    NotifierProvider<CurrentEmployee, Employee?>(CurrentEmployee.new);
