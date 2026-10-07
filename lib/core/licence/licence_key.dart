import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// Format des clés de licence (à vie, 1 PC par clé), vérifiables
/// HORS LIGNE.
///
/// Une clé = [contenu signé] + [signature Ed25519], le tout encodé en
/// base32 (lettres A-Z et chiffres 2-7 seulement : rien ne se confond
/// ni ne se casse en passant par WhatsApp/SMS).
///
/// Contenu signé (16 octets) :
///   - 4 octets : identifiant produit (ex. "MSP1") — une clé MaliStock
///     Pro ne débloque donc pas une application sœur ;
///   - 10 octets : empreinte du PC (voir [empreinteMachine]) ;
///   - 2 octets : jour d'émission (jours depuis le 01/01/2026), pour
///     information seulement — la licence n'expire jamais.
///
/// Seul l'éditeur possède la clé privée (outil `tool/generer_licence.dart`,
/// clé stockée hors du dépôt). L'application n'embarque que la clé
/// PUBLIQUE, qui permet de vérifier une clé mais pas d'en fabriquer.
///
/// IMPORTANT : ce fichier ne doit importer AUCUN paquet Flutter, il est
/// partagé avec l'outil en ligne de commande de génération des clés.
abstract final class LicenceKey {
  static const int _longueurEmpreinte = 10;
  static const int _longueurContenu = 4 + _longueurEmpreinte + 2;
  static const int _longueurSignature = 64;
  static final DateTime _origineJours = DateTime.utc(2026, 1, 1);

  /// Empreinte de 10 octets du PC, calculée à partir de l'identifiant
  /// Windows unique de la machine. Le préfixe produit garantit que les
  /// trois applications sœurs affichent des codes PC différents.
  static Uint8List empreinteMachine(String identifiantWindows, String produit) {
    final hash = crypto.sha256.convert(
      utf8.encode('$produit|machine|${identifiantWindows.trim().toLowerCase()}'),
    );
    return Uint8List.fromList(hash.bytes.sublist(0, _longueurEmpreinte));
  }

  /// Code PC lisible que le client envoie à l'éditeur,
  /// ex. `ABCD-EFGH-IJKL-MNOP`.
  static String codePc(Uint8List empreinte) => _grouper(Base32.encoder(empreinte), 4);

  /// Relit un code PC saisi (espaces, tirets, minuscules tolérés).
  /// Retourne null si le code est invalide.
  static Uint8List? lireCodePc(String code) {
    final octets = Base32.decoder(code);
    if (octets == null || octets.length != _longueurEmpreinte) return null;
    return octets;
  }

  /// Fabrique une clé signée. Utilisé UNIQUEMENT par l'outil éditeur.
  static Future<String> generer({
    required String produit,
    required Uint8List empreinte,
    required SimpleKeyPair clePrivee,
    DateTime? emission,
  }) async {
    final contenu = _contenu(produit, empreinte, emission ?? DateTime.now());
    final signature = await Ed25519().sign(contenu, keyPair: clePrivee);
    return _grouper(
      Base32.encoder(Uint8List.fromList([...contenu, ...signature.bytes])),
      8,
    );
  }

  /// Vérifie qu'une clé saisie est authentique ET destinée à ce
  /// produit ET à ce PC.
  static Future<bool> verifier({
    required String cle,
    required String produit,
    required Uint8List empreinte,
    required List<int> clePublique,
  }) async {
    final octets = Base32.decoder(cle);
    if (octets == null ||
        octets.length != _longueurContenu + _longueurSignature) {
      return false;
    }
    final contenu = octets.sublist(0, _longueurContenu);
    final signature = octets.sublist(_longueurContenu);

    if (!_egaux(contenu.sublist(0, 4), _produitOctets(produit))) return false;
    if (!_egaux(contenu.sublist(4, 4 + _longueurEmpreinte), empreinte)) {
      return false;
    }

    try {
      return await Ed25519().verify(
        contenu,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(clePublique, type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Uint8List _contenu(String produit, Uint8List empreinte, DateTime emission) {
    final jours = emission.toUtc().difference(_origineJours).inDays.clamp(0, 0xFFFF);
    return Uint8List.fromList([
      ..._produitOctets(produit),
      ...empreinte,
      (jours >> 8) & 0xFF,
      jours & 0xFF,
    ]);
  }

  static List<int> _produitOctets(String produit) {
    final octets = ascii.encode(produit);
    if (octets.length != 4) {
      throw ArgumentError('Identifiant produit sur 4 caractères attendu : $produit');
    }
    return octets;
  }

  static bool _egaux(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _grouper(String texte, int taille) {
    final groupes = <String>[];
    for (var i = 0; i < texte.length; i += taille) {
      groupes.add(texte.substring(i, (i + taille).clamp(0, texte.length)));
    }
    return groupes.join('-');
  }
}

/// Base32 RFC 4648 sans padding (A-Z, 2-7).
abstract final class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String encoder(List<int> octets) {
    final sortie = StringBuffer();
    var tampon = 0;
    var bits = 0;
    for (final octet in octets) {
      tampon = ((tampon << 8) | octet) & 0xFFFF;
      bits += 8;
      while (bits >= 5) {
        sortie.write(_alphabet[(tampon >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) sortie.write(_alphabet[(tampon << (5 - bits)) & 31]);
    return sortie.toString();
  }

  /// Ignore espaces, tirets et retours à la ligne ; tolère les
  /// minuscules. Retourne null si un caractère est invalide.
  static Uint8List? decoder(String texte) {
    final propre = texte.toUpperCase().replaceAll(RegExp(r'[\s\-_.]'), '');
    if (propre.isEmpty) return null;
    final sortie = <int>[];
    var tampon = 0;
    var bits = 0;
    for (final caractere in propre.split('')) {
      final valeur = _alphabet.indexOf(caractere);
      if (valeur < 0) return null;
      tampon = ((tampon << 5) | valeur) & 0xFFFF;
      bits += 5;
      if (bits >= 8) {
        sortie.add((tampon >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }
    return Uint8List.fromList(sortie);
  }
}
