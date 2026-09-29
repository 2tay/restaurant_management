// Password hashing (SYNC_PLAN.md, Phase 1, step 9).
//
// PBKDF2-HMAC-SHA256 with a random salt, stored as
// `pbkdf2-sha256$<iterations>$<salt>$<hash>`. The known-answer test pins the
// implementation to the standard: the expected value was computed with
// Python's `hashlib.pbkdf2_hmac`, not with this code.

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/core/utils/password_hash.dart';
import 'package:stock_inventory/data/seed/dataset/credentials.dart';

void main() {
  final fixedSalt = List<int>.generate(16, (i) => i * 7 + 3);

  test('matches a standard PBKDF2 implementation', () {
    expect(
      PasswordHash.hash('1234', salt: fixedSalt),
      r'pbkdf2-sha256$60000$AwoRGB8mLTQ7QklQV15lbA==$'
      r'wz4ctIKCF7VdVco5rgxzyJGhd9mYO7pEnkTOSD2Z+2U=',
    );
  });

  test('the right password verifies and a wrong one does not', () {
    final stored = PasswordHash.hash('4821', iterations: 1000);
    expect(PasswordHash.verify('4821', stored), isTrue);
    expect(PasswordHash.verify('4822', stored), isFalse);
    expect(PasswordHash.verify('', stored), isFalse);
  });

  test('the same password gets a different salt each time', () {
    final a = PasswordHash.hash('1234', iterations: 1000);
    final b = PasswordHash.hash('1234', iterations: 1000);
    expect(a, isNot(b));
    expect(PasswordHash.verify('1234', a), isTrue);
    expect(PasswordHash.verify('1234', b), isTrue);
  });

  test('the password is nowhere in what is stored', () {
    expect(PasswordHash.hash('1234', iterations: 1000), isNot(contains('1234')));
  });

  test('anything that is not one of its hashes fails closed', () {
    for (final stored in [
      'password:1234',
      '',
      r'pbkdf2-sha256$abc$AA==$AA==',
      r'pbkdf2-sha256$0$AA==$AA==',
      r'pbkdf2-sha256$1000$not base64$AA==',
      r'md5$1000$AA==$AA==',
    ]) {
      expect(PasswordHash.verify('1234', stored), isFalse, reason: stored);
    }
  });

  test('the demo hash is 1234', () {
    expect(PasswordHash.verify('1234', demoPasswordHash), isTrue);
  });
}
