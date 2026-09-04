/// How catalogue and team names are compared for "already taken".
///
/// Trimmed and case-folded, deliberately **not** accent-folded: "Épicerie" and
/// "Epicerie" are different spellings a user might legitimately want to
/// correct, and silently treating them as one name would block the correction.
///
/// This stayed in Dart when the app moved to SQLite, and that is a decision
/// rather than an oversight. SQLite's `LOWER()` and its `NOCASE` collation fold
/// ASCII only, so "Épicerie" and "épicerie" would compare as *different* in SQL
/// and as the same here. Since the rule is about case, the Unicode-correct one
/// is the one that has to win, and the lists being compared are a single
/// establishment's categories or units — tens of rows, not thousands.
String normaliseName(String value) => value.trim().toLowerCase();
