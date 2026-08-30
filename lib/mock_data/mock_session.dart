import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'mock_employees.dart';

/// The signed-in user.
///
/// Phase 6 makes this the result of an actual login (CIN + PIN checked against
/// `mockCredentials`) rather than a fixed pick. [current] is null between
/// `signOut` and the next `signIn`; `main()` calls `signOut` at startup so the
/// app opens on `/login`.
///
/// The default value is the owner of Brasserie du Sablon — not for the running
/// app (which is signed out until login) but for widget tests that pump the
/// tree directly: they get an authenticated owner session unless they say
/// otherwise, so the existing route/navigation suites need no login step.
abstract final class MockSession {
  static Employee? _current = _defaultOwner;

  /// The signed-in employee, or null when nobody is.
  static Employee? get current => _current;

  static bool get isSignedIn => _current != null;

  static void signIn(Employee employee) => _current = employee;

  static void signOut() => _current = null;

  /// Test-only: back to the default owner session between tests.
  @visibleForTesting
  static void resetToDefault() => _current = _defaultOwner;
}

Employee get _defaultOwner =>
    mockEmployees.firstWhere((e) => e.id == EmployeeIds.marc);

/// The actor for screens and mutations that assume a session — the signed-in
/// user, falling back to the account owner when nobody is signed in (the router
/// guard keeps a signed-out user out of every screen that reads this, so the
/// fallback only ever matters to a mutation called from a test).
Employee get mockCurrentEmployee => MockSession.current ?? _defaultOwner;
