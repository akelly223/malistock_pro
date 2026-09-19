import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/container/mstk_crypto.dart';
import 'package:malistock_pro/core/container/mstk_exceptions.dart';
import 'package:malistock_pro/core/container/mstk_header.dart';

MstkHeader _enteteDepuis(MstkChiffre chiffre, {required bool motDePasseRequis}) {
  return MstkHeader(
    version: MstkHeader.currentVersion,
    motDePasseRequis: motDePasseRequis,
    kdfId: chiffre.kdfId,
    kdfIterations: chiffre.kdfIterations,
    sel: chiffre.sel,
    nonce: chiffre.nonce,
    taillePayload: 0,
    tagAuthentification: chiffre.tagAuthentification,
  );
}

void main() {
  group('MstkCrypto', () {
    final clair = Uint8List.fromList('Contenu secret à protéger'.codeUnits);

    test('round-trip sans mot de passe', () async {
      final chiffre = await MstkCrypto.chiffrer(clair);
      final header = _enteteDepuis(chiffre, motDePasseRequis: false);

      final dechiffre = await MstkCrypto.dechiffrer(
        header: header,
        ciphertext: chiffre.ciphertext,
      );

      expect(dechiffre, clair);
    });

    test('round-trip avec mot de passe', () async {
      final chiffre =
          await MstkCrypto.chiffrer(clair, motDePasse: 'Secret123!');
      final header = _enteteDepuis(chiffre, motDePasseRequis: true);

      final dechiffre = await MstkCrypto.dechiffrer(
        header: header,
        ciphertext: chiffre.ciphertext,
        motDePasse: 'Secret123!',
      );

      expect(dechiffre, clair);
    });

    test('deux chiffrements du même contenu produisent un sel/nonce/'
        'ciphertext différents (aléatoires)', () async {
      final c1 = await MstkCrypto.chiffrer(clair, motDePasse: 'x');
      final c2 = await MstkCrypto.chiffrer(clair, motDePasse: 'x');
      expect(c1.sel, isNot(equals(c2.sel)));
      expect(c1.nonce, isNot(equals(c2.nonce)));
      expect(c1.ciphertext, isNot(equals(c2.ciphertext)));
    });

    test('mauvais mot de passe lève MstkAuthentificationException',
        () async {
      final chiffre =
          await MstkCrypto.chiffrer(clair, motDePasse: 'BonMotDePasse');
      final header = _enteteDepuis(chiffre, motDePasseRequis: true);

      expect(
        () => MstkCrypto.dechiffrer(
          header: header,
          ciphertext: chiffre.ciphertext,
          motDePasse: 'MauvaisMotDePasse',
        ),
        throwsA(isA<MstkAuthentificationException>()),
      );
    });

    test('aucun mot de passe fourni alors que le fichier en exige un',
        () async {
      final chiffre =
          await MstkCrypto.chiffrer(clair, motDePasse: 'BonMotDePasse');
      final header = _enteteDepuis(chiffre, motDePasseRequis: true);

      expect(
        () => MstkCrypto.dechiffrer(
          header: header,
          ciphertext: chiffre.ciphertext,
        ),
        throwsA(isA<MstkAuthentificationException>()),
      );
    });

    test('ciphertext altéré (fichier corrompu) lève '
        'MstkAuthentificationException plutôt que de renvoyer des '
        'données invalides', () async {
      final chiffre = await MstkCrypto.chiffrer(clair);
      final header = _enteteDepuis(chiffre, motDePasseRequis: false);
      final ciphertextAltere = Uint8List.fromList(chiffre.ciphertext);
      ciphertextAltere[0] ^= 0xFF;

      expect(
        () => MstkCrypto.dechiffrer(
          header: header,
          ciphertext: ciphertextAltere,
        ),
        throwsA(isA<MstkAuthentificationException>()),
      );
    });
  });
}
