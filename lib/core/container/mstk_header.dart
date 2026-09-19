import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32;

import 'mstk_exceptions.dart';

/// En-tête fixe de 80 octets préfixant tout fichier `.mstk`. Décrit
/// comment le contenu chiffré qui suit doit être déchiffré — jamais le
/// contenu lui-même.
///
/// Layout (offsets en octets) :
/// ```
/// 0   8   Signature "MSTKFMT\0"
/// 8   2   Version du format (uint16 LE)
/// 10  1   Flags (bit0 = protégé par mot de passe)
/// 11  1   Identifiant KDF (0 = clé embarquée+HKDF, 1 = PBKDF2-HMAC-SHA256)
/// 12  4   Itérations KDF (uint32 LE, 0 si KDF=0)
/// 16  16  Sel
/// 32  12  Nonce AES-GCM (96 bits)
/// 44  8   Taille du payload en clair (uint64 LE)
/// 52  4   CRC32 des octets 0-51 (uint32 LE)
/// 56  8   Réservé (zéro)
/// 64  16  Tag d'authentification AES-GCM
/// 80  …   Ciphertext
/// ```
class MstkHeader {
  static const int headerLength = 80;
  static const int macLength = 16;
  static const int selLength = 16;
  static const int nonceLength = 12;
  static const int currentVersion = 1;

  /// Identifiants de dérivation de clé (champ `kdfId` de l'en-tête).
  static const int kdfEmbarquee = 0;
  static const int kdfPbkdf2 = 1;

  static final Uint8List _magic =
      Uint8List.fromList('MSTKFMT'.codeUnits + [0]);

  final int version;
  final bool motDePasseRequis;
  final int kdfId;
  final int kdfIterations;
  final Uint8List sel;
  final Uint8List nonce;
  final int taillePayload;
  final Uint8List tagAuthentification;

  const MstkHeader({
    required this.version,
    required this.motDePasseRequis,
    required this.kdfId,
    required this.kdfIterations,
    required this.sel,
    required this.nonce,
    required this.taillePayload,
    required this.tagAuthentification,
  });

  /// Sérialise l'en-tête en 80 octets (CRC recalculé automatiquement).
  Uint8List encode() {
    final bytes = Uint8List(headerLength);
    final vue = ByteData.sublistView(bytes);

    bytes.setRange(0, _magic.length, _magic);
    vue.setUint16(8, version, Endian.little);
    vue.setUint8(10, motDePasseRequis ? 1 : 0);
    vue.setUint8(11, kdfId);
    vue.setUint32(12, kdfIterations, Endian.little);
    bytes.setRange(16, 16 + selLength, sel);
    bytes.setRange(32, 32 + nonceLength, nonce);
    vue.setUint64(44, taillePayload, Endian.little);

    final crc = getCrc32(bytes.sublist(0, 52));
    vue.setUint32(52, crc, Endian.little);
    // Octets 56-63 : réservés, laissés à zéro.

    bytes.setRange(64, 64 + macLength, tagAuthentification);
    return bytes;
  }

  /// Lit et valide les 80 premiers octets de [fileBytes].
  ///
  /// Ordre de validation volontaire : signature puis CRC (intégrité
  /// structurelle) AVANT le numéro de version, pour ne jamais agir sur
  /// un champ potentiellement corrompu.
  static MstkHeader decode(Uint8List fileBytes) {
    if (fileBytes.length < headerLength) {
      throw const MstkCorrompuException();
    }
    final bytes = fileBytes.sublist(0, headerLength);

    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) throw const MstkCorrompuException();
    }

    final vue = ByteData.sublistView(bytes);
    final crcAttendu = vue.getUint32(52, Endian.little);
    final crcCalcule = getCrc32(bytes.sublist(0, 52));
    if (crcAttendu != crcCalcule) {
      throw const MstkCorrompuException();
    }

    final version = vue.getUint16(8, Endian.little);
    if (version > currentVersion) {
      throw MstkVersionFutureException(version, currentVersion);
    }

    final flags = vue.getUint8(10);
    return MstkHeader(
      version: version,
      motDePasseRequis: (flags & 0x1) != 0,
      kdfId: vue.getUint8(11),
      kdfIterations: vue.getUint32(12, Endian.little),
      sel: Uint8List.fromList(bytes.sublist(16, 16 + selLength)),
      nonce: Uint8List.fromList(bytes.sublist(32, 32 + nonceLength)),
      taillePayload: vue.getUint64(44, Endian.little),
      tagAuthentification:
          Uint8List.fromList(bytes.sublist(64, 64 + macLength)),
    );
  }
}
