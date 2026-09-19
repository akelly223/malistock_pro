import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:malistock_pro/core/container/mstk_container_service.dart';
import 'package:malistock_pro/core/container/mstk_exceptions.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Vérifie le cycle de vie complet d'un fichier `.mstk` : création,
/// écriture de contenu dans le dossier de travail, sauvegarde
/// (rechiffrement), fermeture, réouverture avec vérification
/// byte-à-byte, et détection d'une double ouverture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot =
        await Directory.systemTemp.createTemp('mstk_container_test_');
    PathProviderPlatform.instance =
        _FakePathProvider(p.join(tempRoot.path, 'tmp_provider'));
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('créer → écrire du contenu → sauvegarder → fermer → rouvrir : '
      'contenu identique byte-à-byte', () async {
    final fichier = File(p.join(tempRoot.path, 'test.mstk'));

    final ouvert1 =
        await MstkContainerService.creerNouveau(fichier, motDePasse: 'Passe123');
    final donneesSqlite =
        File(p.join(ouvert1.dossierTravail.path, 'malistock_pro.sqlite'));
    await donneesSqlite.writeAsBytes([1, 2, 3, 4, 5]);
    final sousDossier = Directory(p.join(ouvert1.dossierTravail.path, 'logo'));
    await sousDossier.create();
    await File(p.join(sousDossier.path, 'logo.png')).writeAsBytes([9, 9, 9]);

    await MstkContainerService.sauvegarder(ouvert1);
    await MstkContainerService.fermer(ouvert1);

    expect(await fichier.exists(), isTrue);
    expect(File('${fichier.path}.tmp').existsSync(), isFalse,
        reason: 'le fichier temporaire d\'écriture atomique doit disparaître');

    final ouvert2 =
        await MstkContainerService.ouvrir(fichier, motDePasse: 'Passe123');
    final relu = await File(
            p.join(ouvert2.dossierTravail.path, 'malistock_pro.sqlite'))
        .readAsBytes();
    final reluLogo = await File(p.join(ouvert2.dossierTravail.path, 'logo', 'logo.png'))
        .readAsBytes();

    expect(relu, [1, 2, 3, 4, 5]);
    expect(reluLogo, [9, 9, 9]);

    await MstkContainerService.fermer(ouvert2);
    expect(await ouvert2.dossierTravail.exists(), isFalse,
        reason: 'le dossier de travail temporaire doit être nettoyé à la fermeture');
  });

  test('une seconde ouverture pendant que le fichier est déjà ouvert '
      'échoue avec MstkVerrouilleException', () async {
    final fichier = File(p.join(tempRoot.path, 'verrou.mstk'));
    final ouvert = await MstkContainerService.creerNouveau(fichier);

    await expectLater(
      MstkContainerService.ouvrir(fichier),
      throwsA(isA<MstkVerrouilleException>()),
    );

    await MstkContainerService.fermer(ouvert);

    // Une fois fermé, une nouvelle ouverture doit réussir normalement.
    final reouvert = await MstkContainerService.ouvrir(fichier);
    await MstkContainerService.fermer(reouvert);
  });

  test('mauvais mot de passe à l\'ouverture lève '
      'MstkAuthentificationException', () async {
    final fichier = File(p.join(tempRoot.path, 'protege.mstk'));
    final ouvert = await MstkContainerService.creerNouveau(fichier,
        motDePasse: 'BonMotDePasse');
    await MstkContainerService.sauvegarder(ouvert);
    await MstkContainerService.fermer(ouvert);

    await expectLater(
      MstkContainerService.ouvrir(fichier, motDePasse: 'Mauvais'),
      throwsA(isA<MstkAuthentificationException>()),
    );
  });

  test('un fichier corrompu (octets aléatoires) lève '
      'MstkCorrompuException à l\'ouverture', () async {
    final fichier = File(p.join(tempRoot.path, 'corrompu.mstk'));
    await fichier.writeAsBytes(List.generate(200, (i) => i % 256));

    await expectLater(
      MstkContainerService.ouvrir(fichier),
      throwsA(isA<MstkCorrompuException>()),
    );
  });
}
