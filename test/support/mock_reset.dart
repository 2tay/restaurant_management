// Isolation for tests that write to the mock lists.
//
// The lists are global and mutable, so without this one test's writes leak into
// the next and failures depend on declaration order — the worst kind of flake to
// diagnose.
//
// It leans on the same snapshot the app's own "Réinitialiser la démonstration"
// action uses, which means the reset mechanism is exercised on every test run
// rather than only when somebody taps the button.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/mock_data/mock_data.dart';

/// Captures the pristine dataset and restores it after the test.
///
/// Call from `setUp`. Safe to call in a suite that never writes.
void restoreMockData() {
  // Idempotent, and the first call happens before any test has written, so the
  // seed is genuinely pristine.
  MockWrite.captureSeed();
  addTearDown(MockWrite.reset);
  // The session is not in the MockWrite snapshot (resetting the demo must not
  // log you out), so a test that signs in or out puts it back itself.
  addTearDown(MockSession.resetToDefault);
}
