/// Where the sync server is (SYNC_PLAN.md, Phase 4).
///
/// Given at build time, never written in the code:
///
/// ```
/// flutter run --dart-define-from-file=config/local.json
/// ```
///
/// `config/local.json` is made from `config/example.json` and the values
/// `supabase status` prints; it is not committed. A build without them still
/// runs: the account screens say no server is configured, and the demo works
/// as before.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The public ("publishable") key. Never the secret or service key: this
  /// one ships inside the app.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Whether this build knows a server to talk to.
  static bool get hasServer =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
