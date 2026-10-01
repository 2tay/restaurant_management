/// The keys used in the `meta` table.
///
/// Constants rather than string literals at the call sites: there are two of
/// them, they are read and written from different layers, and a typo in one
/// place produces a silent miss rather than an error.
abstract final class MetaKeys {
  /// When the demo dataset was written, ISO-8601.
  ///
  /// The dataset's dates are all offsets from a single "now", so recording that
  /// instant is what lets anything later reason about the demo's own timeline —
  /// and what makes a seed reproducible when a caller supplies the instant
  /// instead of taking the clock.
  static const String seededAt = 'seededAt';

  /// The display name every stock movement and price change is stamped with —
  /// a plain string, refreshed from the signed-in employee on every sign-in
  /// (`SessionRepository.signIn`), so a record keeps the name even after the
  /// person leaves.
  static const String currentUserName = 'currentUserName';

  /// The signed-in employee's id, or absent when nobody is signed in — the
  /// database-backed session. `db_fixture.dart` seeds it so a widget test
  /// opens as the account owner.
  static const String currentEmployeeId = 'currentEmployeeId';
}
