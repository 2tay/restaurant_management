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

  /// The team member every write is attributed to until Phase 3 brings real
  /// authentication. Introduced in stage 7; named here so both keys are visible
  /// in one place.
  static const String currentUserId = 'currentUserId';
}
