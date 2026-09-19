import 'dart:typed_data';
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter_test/flutter_test.dart';
import 'package:malistock_pro/core/container/mstk_exceptions.dart';
import 'package:malistock_pro/core/container/mstk_header.dart';

MstkHeader _entete({bool motDePasseRequis = false}) {
  return MstkHeader(
    version: MstkHeader.currentVersion,
    motDePasseRequis: motDePasseRequis,
    kdfId: motDePasseRequis ? MstkHeader.kdfPbkdf2 : MstkHeader.kdfEmbarquee,
    kdfIterations: motDePasseRequis ? 210000 : 0,
    sel: Uint8List.fromList(List.generate(MstkHeader.selLength, (i) => i)),
    nonce: Uint8List.fromList(
        List.generate(MstkHeader.nonceLength, (i) => 100 + i)),
    taillePayload: 12345,
    tagAuthentification: Uint8List.fromList(
        List.generate(MstkHeader.macLength, (i) => 200 + i)),
  );
}

void main() {
  group('MstkHeader', () {
    test('encode produit exactement 80 octets', () {
      expect(_entete().encode().length, MstkHeader.headerLength);
    });

    test('decode(encode(x)) restitue les mêmes champs', () {
      final original = _entete(motDePasseRequis: true);
      final decode = MstkHeader.decode(original.encode());

      expect(decode.version, original.version);
      expect(decode.motDePasseRequis, isTrue);
      expect(decode.kdfId, original.kdfId);
      expect(decode.kdfIterations, original.kdfIterations);
      expect(decode.sel, original.sel);
      expect(decode.nonce, original.nonce);
      expect(decode.taillePayload, original.taillePayload);
      expect(decode.tagAuthentification, original.tagAuthentification);
    });

    test('un fichier trop court est rejeté comme corrompu', () {
      expect(
        () => MstkHeader.decode(Uint8List(10)),
        throwsA(isA<MstkCorrompuException>()),
      );
    });

    test('une signature invalide est rejetée comme corrompue', () {
      final bytes = _entete().encode();
      bytes[0] = 0x00; // altère la signature
      expect(
        () => MstkHeader.decode(bytes),
        throwsA(isA<MstkCorrompuException>()),
      );
    });

    test('un octet altéré après la signature (CRC invalide) est rejeté '
        'comme corrompu', () {
      final bytes = _entete().encode();
      bytes[20] ^= 0xFF; // altère un octet du sel, sans recalculer le CRC
      expect(
        () => MstkHeader.decode(bytes),
        throwsA(isA<MstkCorrompuException>()),
      );
    });

    test('une version future est rejetée distinctement d\'une corruption',
        () {
      final bytes = _entete().encode();
      final vue = ByteData.sublistView(bytes);
      vue.setUint16(8, MstkHeader.currentVersion + 1, Endian.little);
      // Recalcule le CRC comme le ferait encode(), pour isoler le test
      // sur la détection de version future plutôt que sur la
      // détection de corruption.
      vue.setUint32(52, getCrc32(bytes.sublist(0, 52)), Endian.little);

      expect(
        () => MstkHeader.decode(bytes),
        throwsA(isA<MstkVersionFutureException>()),
      );
    });
  });
}
