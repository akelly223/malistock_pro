// Outil ÉDITEUR (MALI_CODE CENTER) de génération des clés de licence.
// N'est PAS inclus dans l'application livrée aux clients.
//
// Utilisation (depuis le dossier du projet, dans un terminal) :
//
//   1) Une seule fois, pour créer la paire de clés :
//        dart run tool/generer_licence.dart init
//      → crée la clé SECRÈTE dans %USERPROFILE%\.malicode\cle_privee_licence.txt
//      → affiche la clé PUBLIQUE à copier dans lib/core/licence/licence_config.dart
//
//   2) Pour chaque client qui a payé :
//        dart run tool/generer_licence.dart ABCD-EFGH-IJKL-MNOP
//      (le "Code PC" affiché dans Paramètres > Licence chez le client)
//      → affiche la clé de licence à lui envoyer par WhatsApp.
//
//      Pour une application sœur, préciser le produit :
//        dart run tool/generer_licence.dart --produit GCO1 ABCD-EFGH-IJKL-MNOP
//
// ⚠️ La clé secrète ne doit JAMAIS être partagée ni mise dans le dépôt
// git. Faites-en une copie de sauvegarde (clé USB, coffre) : si elle est
// perdue, il devient impossible de générer des clés pour les versions
// déjà installées chez les clients.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:malistock_pro/core/licence/licence_key.dart';

const _produitParDefaut = 'MSP1';

Future<void> main(List<String> args) async {
  final fichierCle = File(
    '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}'
    '${Platform.pathSeparator}.malicode'
    '${Platform.pathSeparator}cle_privee_licence.txt',
  );

  if (args.isEmpty) {
    _aide();
    exit(1);
  }

  if (args.first == 'init') {
    await _init(fichierCle);
    return;
  }

  var produit = _produitParDefaut;
  final restants = [...args];
  final iProduit = restants.indexOf('--produit');
  if (iProduit >= 0 && iProduit + 1 < restants.length) {
    produit = restants[iProduit + 1].toUpperCase();
    restants.removeRange(iProduit, iProduit + 2);
  }
  if (restants.isEmpty) {
    _aide();
    exit(1);
  }

  final empreinte = LicenceKey.lireCodePc(restants.join(''));
  if (empreinte == null) {
    stderr.writeln('Code PC invalide : "${restants.join(' ')}"');
    exit(1);
  }

  if (!await fichierCle.exists()) {
    stderr.writeln('Clé secrète introuvable (${fichierCle.path}).');
    stderr.writeln('Lancez d\'abord : dart run tool/generer_licence.dart init');
    exit(1);
  }

  final graine = base64Decode((await fichierCle.readAsString()).trim());
  final paire = await Ed25519().newKeyPairFromSeed(graine);
  final cle = await LicenceKey.generer(
    produit: produit,
    empreinte: empreinte,
    clePrivee: paire,
  );

  stdout.writeln('');
  stdout.writeln('Produit : $produit');
  stdout.writeln('Code PC : ${LicenceKey.codePc(empreinte)}');
  stdout.writeln('');
  stdout.writeln('Clé de licence à envoyer au client :');
  stdout.writeln('');
  stdout.writeln(cle);
  stdout.writeln('');
}

Future<void> _init(File fichierCle) async {
  if (await fichierCle.exists()) {
    stderr.writeln('Une clé secrète existe déjà : ${fichierCle.path}');
    stderr.writeln('Refus de l\'écraser (les licences déjà vendues deviendraient invalides).');
    exit(1);
  }
  final paire = await Ed25519().newKeyPair();
  final graine = await paire.extractPrivateKeyBytes();
  final publique = (await paire.extractPublicKey()).bytes;

  await fichierCle.parent.create(recursive: true);
  await fichierCle.writeAsString(base64Encode(graine));

  stdout.writeln('Clé SECRÈTE créée : ${fichierCle.path}');
  stdout.writeln('→ Faites-en une copie de sauvegarde, ne la partagez jamais.');
  stdout.writeln('');
  stdout.writeln('Clé PUBLIQUE à coller dans lib/core/licence/licence_config.dart :');
  stdout.writeln('');
  stdout.writeln('  static const List<int> clePublique = [');
  stdout.writeln('    ${publique.join(', ')},');
  stdout.writeln('  ];');
}

void _aide() {
  stdout.writeln('Utilisation :');
  stdout.writeln('  dart run tool/generer_licence.dart init');
  stdout.writeln('  dart run tool/generer_licence.dart <CODE-PC>');
  stdout.writeln('  dart run tool/generer_licence.dart --produit GCO1 <CODE-PC>');
}
