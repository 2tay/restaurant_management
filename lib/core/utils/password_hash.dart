import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Password hashing: PBKDF2 with HMAC-SHA256, a random salt per password.
///
/// Credentials will be synced so an employee can sign in on any tablet of the
/// store (SYNC_PLAN.md, Phase 1, step 9), which means the stored value leaves
/// the device. It has to be a real, salted, slow hash before that happens.
///
/// PBKDF2 rather than Argon2 because it needs nothing beyond the `crypto`
/// package (maintained by the Dart team) and runs the same on every platform
/// the app builds for. The stored string names the algorithm and carries its
/// own iteration count and salt, so a later change of either leaves existing
/// passwords verifiable:
///
/// ```
/// pbkdf2-sha256$<iterations>$<salt, base64>$<hash, base64>
/// ```
///
/// **What this does not do.** The password is four digits. No hash makes ten
/// thousand guesses slow enough on its own; what it prevents is the password
/// being readable in a database file, a backup or a sync payload. Stopping
/// guessing is the lockout's job (`AuthRules.maxFailedAttempts`), and on the
/// server it will be the server's.
abstract final class PasswordHash {
  static const String _scheme = 'pbkdf2-sha256';

  /// The work factor for new hashes.
  ///
  /// Chosen so one hash takes roughly a tenth of a second on a desktop and a
  /// few tenths on a modest tablet: slow for an attacker, unnoticed at a login.
  /// Stored in each hash, so raising it later only affects new passwords.
  static const int defaultIterations = 60000;

  static const int _saltLength = 16;
  static const int _keyLength = 32;

  /// Hashes [password] with a fresh random salt.
  ///
  /// [salt] and [iterations] exist for the demo seed, which ships a
  /// precomputed hash so a test database does not pay for hashing on every
  /// setup. Anything else should leave them alone.
  static String hash(
    String password, {
    List<int>? salt,
    int iterations = defaultIterations,
  }) {
    final saltBytes = salt ?? _randomSalt();
    final key = _pbkdf2(utf8.encode(password), saltBytes, iterations);
    return '$_scheme\$$iterations\$${base64.encode(saltBytes)}'
        '\$${base64.encode(key)}';
  }

  /// Whether [password] is the one behind [stored]. False for anything that
  /// is not a hash this class wrote.
  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;

    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;

    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }

    final actual = _pbkdf2(utf8.encode(password), salt, iterations);
    return _constantTimeEquals(actual, expected);
  }

  /// PBKDF2 (RFC 8018) for a single output block, which is all a 32-byte key
  /// from SHA-256 needs.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);

    final first = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..setAll(salt.length, const [0, 0, 0, 1]);

    var block = hmac.convert(first).bytes;
    final result = Uint8List.fromList(block);
    for (var round = 1; round < rounds; round++) {
      block = hmac.convert(block).bytes;
      for (var i = 0; i < _keyLength; i++) {
        result[i] ^= block[i];
      }
    }
    return result;
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  /// Compares every byte whatever the first difference, so the time taken says
  /// nothing about how much of a guess was right.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
