import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'mstk_exceptions.dart';
import 'mstk_header.dart';

/// Résultat d'un chiffrement : les champs à reporter dans [MstkHeader]
/// plus le ciphertext à écrire après l'en-tête.
class MstkChiffre {
  final Uint8List sel;
  final Uint8List nonce;
  final Uint8List tagAuthentification;
  final Uint8List ciphertext;
  final int kdfId;
  final int kdfIterations;

  const MstkChiffre({
    required this.sel,
    required this.nonce,
    required this.tagAuthentification,
    required this.ciphertext,
    required this.kdfId,
    required this.kdfIterations,
  });
}

/// Chiffrement/déchiffrement AES-256-GCM du payload d'un fichier
/// `.mstk`, et dérivation de la clé à partir d'un mot de passe
/// optionnel.
///
/// Sans mot de passe, la clé est dérivée (via HKDF) d'un secret
/// embarqué dans l'application. Cela protège contre les outils
/// génériques (DB Browser for SQLite, renommage en `.zip`...) mais PAS
/// contre une personne disposant du binaire de l'application — ce
/// n'est pas une confidentialité réelle, seulement une barrière contre
/// l'inspection occasionnelle. Seul un mot de passe apporte une vraie
/// protection ; à communiquer honnêtement côté UI.
abstract final class MstkCrypto {
  static const int iterationsPbkdf2 = 210000;
  static const int _longueurCle = 32; // 256 bits

  /// Secret embarqué utilisé (via HKDF) quand aucun mot de passe n'est
  /// défini. Ne PAS considérer comme un secret réel — voir la doc de
  /// la classe.
  static const List<int> _secretEmbarque = <int>[
    0x4D, 0x61, 0x6C, 0x69, 0x53, 0x74, 0x6F, 0x63, 0x6B, 0x2D, 0x6D,
    0x73, 0x74, 0x6B, 0x2D, 0x76, 0x31, 0x2D, 0x63, 0x6C, 0x65, 0x2D,
    0x65, 0x6D, 0x62, 0x61, 0x72, 0x71, 0x75, 0x65, 0x65, 0x2E,
  ];

  static AesGcm get _algorithme =>
      AesGcm.with256bits(nonceLength: MstkHeader.nonceLength);

  static bool _aUnMotDePasse(String? motDePasse) =>
      motDePasse != null && motDePasse.isNotEmpty;

  /// [iterations] : nombre d'itérations PBKDF2 à utiliser — toujours
  /// [iterationsPbkdf2] (valeur actuelle) pour un nouveau chiffrement,
  /// mais DOIT être la valeur lue dans l'en-tête du fichier pour un
  /// déchiffrement, afin qu'un futur changement de cette constante ne
  /// rende jamais illisibles les fichiers `.mstk` déjà créés.
  static Future<SecretKey> _deriverCle({
    required String? motDePasse,
    required Uint8List sel,
    int iterations = iterationsPbkdf2,
  }) {
    if (_aUnMotDePasse(motDePasse)) {
      return Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: _longueurCle * 8,
      ).deriveKeyFromPassword(password: motDePasse!, nonce: sel);
    }
    return Hkdf(hmac: Hmac.sha256(), outputLength: _longueurCle)
        .deriveKey(secretKey: SecretKey(_secretEmbarque), nonce: sel);
  }

  static Uint8List _selAleatoire() {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(MstkHeader.selLength, (_) => random.nextInt(256)));
  }

  /// Chiffre [clair] avec un sel/nonce générés aléatoirement.
  static Future<MstkChiffre> chiffrer(
    Uint8List clair, {
    String? motDePasse,
  }) async {
    final sel = _selAleatoire();
    final cle = await _deriverCle(motDePasse: motDePasse, sel: sel);

    // Nonce omis volontairement : l'algorithme en génère un aléatoire
    // de la bonne longueur, récupéré ensuite via `boite.nonce`.
    final boite = await _algorithme.encrypt(clair, secretKey: cle);

    return MstkChiffre(
      sel: sel,
      nonce: Uint8List.fromList(boite.nonce),
      tagAuthentification: Uint8List.fromList(boite.mac.bytes),
      ciphertext: Uint8List.fromList(boite.cipherText),
      kdfId: _aUnMotDePasse(motDePasse)
          ? MstkHeader.kdfPbkdf2
          : MstkHeader.kdfEmbarquee,
      kdfIterations: _aUnMotDePasse(motDePasse) ? iterationsPbkdf2 : 0,
    );
  }

  /// Déchiffre le [ciphertext] décrit par [header].
  ///
  /// Lève [MstkAuthentificationException] si le mot de passe est
  /// incorrect ou si le contenu a été altéré — les deux cas sont
  /// indissociables avec un chiffrement authentifié (AES-GCM).
  static Future<Uint8List> dechiffrer({
    required MstkHeader header,
    required Uint8List ciphertext,
    String? motDePasse,
  }) async {
    if (header.motDePasseRequis && !_aUnMotDePasse(motDePasse)) {
      throw const MstkAuthentificationException(
          'Ce fichier est protégé par un mot de passe.');
    }

    final cle = await _deriverCle(
      motDePasse: motDePasse,
      sel: header.sel,
      iterations:
          header.kdfIterations > 0 ? header.kdfIterations : iterationsPbkdf2,
    );
    final boite = SecretBox(
      ciphertext,
      nonce: header.nonce,
      mac: Mac(header.tagAuthentification),
    );

    try {
      final clair = await _algorithme.decrypt(boite, secretKey: cle);
      return Uint8List.fromList(clair);
    } on SecretBoxAuthenticationError {
      throw const MstkAuthentificationException();
    }
  }
}
