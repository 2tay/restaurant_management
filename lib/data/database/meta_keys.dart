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

  /// The display name every database write is attributed to. The team /
  /// employees module lives in `lib/mock_data/`, not here, so this is a plain
  /// string seeded from the current employee rather than a foreign key into an
  /// `employees` table.
  static const String currentUserName = 'currentUserName';
}
