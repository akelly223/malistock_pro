import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Hash sécurisé des mots de passe (PBKDF2-HMAC-SHA256, sel aléatoire
/// par utilisateur).
///
/// Format stocké : `pbkdf2$<itérations>$<sel base64>$<hash base64>`.
/// Un sel unique par utilisateur (au lieu d'un sel fixe applicatif)
/// empêche une attaque par table précalculée unique pour toute la
/// base, et le grand nombre d'itérations ralentit délibérément le
/// calcul pour rendre une attaque par force brute hors-ligne (base
/// SQLite volée/copiée) coûteuse — contrairement à SHA-256 seul, conçu
/// pour être rapide et donc mal adapté au hachage de mots de passe.
///
/// L'ancien format (SHA-256 + sel fixe, 64 caractères hexadécimaux
/// bruts) reste reconnu en lecture par [verify] pour ne pas invalider
/// les mots de passe existants : [needsRehash] indique quand
/// re-hasher avec l'algorithme courant après une connexion réussie
/// (upgrade transparent, voir [AuthRepositoryImpl.login]).
class PasswordHasher {
  PasswordHasher._();

  static const String _prefix = 'pbkdf2';
  static const int _iterations = 120000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  // Ancien format (conservé uniquement pour vérifier — jamais pour
  // générer de nouveaux hashs).
  static const String _legacySalt = 'gc_mali_2026_salt_v1';
  static final RegExp _legacyFormat = RegExp(r'^[0-9a-f]{64}$');

  static String hash(String motDePasseEnClair) {
    final salt = _genererSel();
    final derive = _pbkdf2(utf8.encode(motDePasseEnClair), salt, _iterations, _keyLength);
    return '$_prefix\$$_iterations\$${base64.encode(salt)}\$${base64.encode(derive)}';
  }

  static bool verify(String motDePasseEnClair, String hashStocke) {
    if (_legacyFormat.hasMatch(hashStocke)) {
      return _hashLegacy(motDePasseEnClair) == hashStocke;
    }

    final parts = hashStocke.split('\$');
    if (parts.length != 4 || parts[0] != _prefix) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null) return false;
    final salt = base64.decode(parts[2]);
    final attendu = base64.decode(parts[3]);
    final calcule =
        _pbkdf2(utf8.encode(motDePasseEnClair), salt, iterations, attendu.length);
    return _egaliteConstante(calcule, attendu);
  }

  /// Vrai si le hash stocké utilise l'ancien format faible (SHA-256 +
  /// sel fixe) et doit être remplacé par un hash PBKDF2 dès que
  /// possible (après vérification réussie du mot de passe en clair).
  static bool needsRehash(String hashStocke) => _legacyFormat.hasMatch(hashStocke);

  static String _hashLegacy(String motDePasseEnClair) {
    final bytes = utf8.encode('$_legacySalt$motDePasseEnClair$_legacySalt');
    return sha256.convert(bytes).toString();
  }

  static List<int> _genererSel() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  static List<int> _pbkdf2(
      List<int> motDePasse, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, motDePasse);
    final blocCount = (keyLength / sha256.convert([]).bytes.length).ceil();
    final derive = <int>[];
    for (var i = 1; i <= blocCount; i++) {
      var u = hmac.convert([...salt, ...(_intToBytes4(i))]).bytes;
      var bloc = List<int>.from(u);
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < bloc.length; k++) {
          bloc[k] ^= u[k];
        }
      }
      derive.addAll(bloc);
    }
    return derive.sublist(0, keyLength);
  }

  static List<int> _intToBytes4(int value) => [
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ];

  /// Comparaison à temps constant pour éviter les attaques par
  /// mesure du temps de réponse lors de la vérification du hash.
  static bool _egaliteConstante(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
