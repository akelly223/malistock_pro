import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/utils/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('hash puis verify réussit avec le bon mot de passe', () {
      final hash = PasswordHasher.hash('MonMotDePasse123');
      expect(PasswordHasher.verify('MonMotDePasse123', hash), isTrue);
    });

    test('verify échoue avec un mauvais mot de passe', () {
      final hash = PasswordHasher.hash('MonMotDePasse123');
      expect(PasswordHasher.verify('AutreMotDePasse', hash), isFalse);
    });

    test('deux hash du même mot de passe diffèrent (sel aléatoire)', () {
      final h1 = PasswordHasher.hash('MonMotDePasse123');
      final h2 = PasswordHasher.hash('MonMotDePasse123');
      expect(h1, isNot(equals(h2)));
      expect(PasswordHasher.verify('MonMotDePasse123', h1), isTrue);
      expect(PasswordHasher.verify('MonMotDePasse123', h2), isTrue);
    });

    test('un hash au nouveau format ne nécessite pas de re-hash', () {
      final hash = PasswordHasher.hash('MonMotDePasse123');
      expect(PasswordHasher.needsRehash(hash), isFalse);
    });

    test('un hash à l\'ancien format (SHA-256 + sel fixe) reste vérifiable '
        'et est signalé pour re-hash', () {
      // Hash pré-calculé avec l'ancien algorithme (SHA-256 du mot de
      // passe entouré du sel fixe 'gc_mali_2026_salt_v1'), pour
      // simuler un compte créé avant le correctif.
      const motDePasse = 'AncienCompte1';
      const hashLegacy =
          '89e9122a955312a343f76029d1f0a11fc77cea1ee2f8205c29b6fcd3c50bdebf';

      expect(PasswordHasher.verify(motDePasse, hashLegacy), isTrue);
      expect(PasswordHasher.verify('MauvaisMotDePasse', hashLegacy), isFalse);
      expect(PasswordHasher.needsRehash(hashLegacy), isTrue);
    });
  });
}
