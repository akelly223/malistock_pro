import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as pkg_crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/container/mstk_crypto_windows_native.dart';

void main() {
  group('MstkCryptoWindowsNative', () {
    final cle = Uint8List.fromList(List.generate(32, (i) => i));
    final nonce = Uint8List.fromList(List.generate(12, (i) => i + 100));
    final clair =
        Uint8List.fromList('Contenu secret à protéger — éàç'.codeUnits);

    test('round-trip chiffrement/déchiffrement', () {
      final (ciphertext, tag) = MstkCryptoWindowsNative.chiffrer(
          cle: cle, nonce: nonce, clair: clair);
      final dechiffre = MstkCryptoWindowsNative.dechiffrer(
          cle: cle, nonce: nonce, ciphertext: ciphertext, tag: tag);
      expect(dechiffre, clair);
    });

    test('payload vide', () {
      final vide = Uint8List(0);
      final (ciphertext, tag) =
          MstkCryptoWindowsNative.chiffrer(cle: cle, nonce: nonce, clair: vide);
      final dechiffre = MstkCryptoWindowsNative.dechiffrer(
          cle: cle, nonce: nonce, ciphertext: ciphertext, tag: tag);
      expect(dechiffre, isEmpty);
    });

    test('tag altéré lève MstkAuthTagInvalideException', () {
      final (ciphertext, tag) = MstkCryptoWindowsNative.chiffrer(
          cle: cle, nonce: nonce, clair: clair);
      final tagAltere = Uint8List.fromList(tag)..[0] ^= 0xFF;
      expect(
        () => MstkCryptoWindowsNative.dechiffrer(
            cle: cle, nonce: nonce, ciphertext: ciphertext, tag: tagAltere),
        throwsA(isA<MstkAuthTagInvalideException>()),
      );
    });

    test('ciphertext altéré lève MstkAuthTagInvalideException', () {
      final (ciphertext, tag) = MstkCryptoWindowsNative.chiffrer(
          cle: cle, nonce: nonce, clair: clair);
      final ciphertextAltere = Uint8List.fromList(ciphertext)..[0] ^= 0xFF;
      expect(
        () => MstkCryptoWindowsNative.dechiffrer(
            cle: cle, nonce: nonce, ciphertext: ciphertextAltere, tag: tag),
        throwsA(isA<MstkAuthTagInvalideException>()),
      );
    });

    test(
        'INTEROPÉRABILITÉ : chiffré avec package:cryptography, déchiffré '
        'avec BCrypt natif', () async {
      final algo = pkg_crypto.AesGcm.with256bits(nonceLength: 12);
      final boite = await algo.encrypt(clair,
          secretKey: pkg_crypto.SecretKey(cle), nonce: nonce);

      final dechiffre = MstkCryptoWindowsNative.dechiffrer(
        cle: cle,
        nonce: nonce,
        ciphertext: Uint8List.fromList(boite.cipherText),
        tag: Uint8List.fromList(boite.mac.bytes),
      );
      expect(dechiffre, clair);
    });

    test(
        'INTEROPÉRABILITÉ : chiffré avec BCrypt natif, déchiffré avec '
        'package:cryptography (garantit que les .mstk restent lisibles '
        'si on repasse en pur Dart, ex. sur une autre plateforme)',
        () async {
      final (ciphertext, tag) = MstkCryptoWindowsNative.chiffrer(
          cle: cle, nonce: nonce, clair: clair);

      final algo = pkg_crypto.AesGcm.with256bits(nonceLength: 12);
      final dechiffre = await algo.decrypt(
        pkg_crypto.SecretBox(ciphertext,
            nonce: nonce, mac: pkg_crypto.Mac(tag)),
        secretKey: pkg_crypto.SecretKey(cle),
      );
      expect(Uint8List.fromList(dechiffre), clair);
    });
  });
}
