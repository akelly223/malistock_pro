import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:malistock_pro/core/constants/db_constants.dart';
import 'package:malistock_pro/core/container/mstk_container_service.dart';
import 'package:malistock_pro/core/services/mstk_migration_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String docPath;
  final String tempPath;
  _FakePathProvider(this.docPath, this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Vérifie que la conversion d'un ancien dossier legacy (SQLite
/// classique) vers `.mstk` préserve le contenu et ne touche jamais au
/// dossier source.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrer() copie le contenu du dossier legacy sans le modifier',
      () async {
    final racine =
        await Directory.systemTemp.createTemp('mstk_migration_test_');
    addTearDown(() => racine.delete(recursive: true));

    final docDir = Directory(p.join(racine.path, 'Documents'));
    PathProviderPlatform.instance = _FakePathProvider(
        docDir.path, p.join(racine.path, 'tmp_provider'));

    // Fabrique un dossier legacy "MaliStockPro" avec une fausse
    // base et un fichier logo, comme le ferait l'ancien flux.
    final dossierLegacy =
        Directory(p.join(docDir.path, 'MaliStockPro'));
    await dossierLegacy.create(recursive: true);
    final fichierDb =
        File(p.join(dossierLegacy.path, DbConstants.dbFileName));
    await fichierDb.writeAsBytes([1, 2, 3, 42]);
    final dossierLogo = Directory(p.join(dossierLegacy.path, 'logo'));
    await dossierLogo.create();
    await File(p.join(dossierLogo.path, 'logo.png')).writeAsBytes([7, 7]);

    final detecte = await MstkMigrationService.detecterDossierExistant();
    expect(detecte, dossierLegacy.path);

    final destination = File(p.join(racine.path, 'converti.mstk'));
    await MstkMigrationService.migrer(
      dossierSource: dossierLegacy.path,
      fichierDestination: destination,
      motDePasse: 'MotDePasseMigration',
    );

    // Le dossier source n'a pas bougé.
    expect(await fichierDb.readAsBytes(), [1, 2, 3, 42]);
    expect(await dossierLegacy.exists(), isTrue);

    // Le nouveau fichier s'ouvre et contient bien les mêmes données.
    final ouvert = await MstkContainerService.ouvrir(destination,
        motDePasse: 'MotDePasseMigration');
    final relu = await File(
            p.join(ouvert.dossierTravail.path, DbConstants.dbFileName))
        .readAsBytes();
    final reluLogo = await File(
            p.join(ouvert.dossierTravail.path, 'logo', 'logo.png'))
        .readAsBytes();
    expect(relu, [1, 2, 3, 42]);
    expect(reluLogo, [7, 7]);

    await MstkContainerService.fermer(ouvert);
  });

  test(
      'migrer() ignore un dossier .Trash présent dans le dossier legacy '
      '(ex : dossier de données pointé sur une racine iCloud Drive/'
      'OneDrive) au lieu d\'échouer', () async {
    final racine =
        await Directory.systemTemp.createTemp('mstk_migration_test3_');
    addTearDown(() => racine.delete(recursive: true));

    final docDir = Directory(p.join(racine.path, 'Documents'));
    PathProviderPlatform.instance = _FakePathProvider(
        docDir.path, p.join(racine.path, 'tmp_provider'));

    final dossierLegacy =
        Directory(p.join(docDir.path, 'MaliStockPro'));
    await dossierLegacy.create(recursive: true);
    await File(p.join(dossierLegacy.path, DbConstants.dbFileName))
        .writeAsBytes([9, 9, 9]);

    final dossierTrash = Directory(p.join(dossierLegacy.path, '.Trash'));
    await dossierTrash.create();
    await File(p.join(dossierTrash.path, 'export_client.egc'))
        .writeAsBytes([0]);

    final destination = File(p.join(racine.path, 'converti_trash.mstk'));
    final ignores = await MstkMigrationService.migrer(
      dossierSource: dossierLegacy.path,
      fichierDestination: destination,
      motDePasse: 'MotDePasseMigration',
    );
    expect(ignores, isEmpty);

    final ouvert = await MstkContainerService.ouvrir(destination,
        motDePasse: 'MotDePasseMigration');
    expect(
        await File(p.join(ouvert.dossierTravail.path, DbConstants.dbFileName))
            .readAsBytes(),
        [9, 9, 9]);
    expect(
        await Directory(p.join(ouvert.dossierTravail.path, '.Trash'))
            .exists(),
        isFalse);
    await MstkContainerService.fermer(ouvert);
  });

  test('detecterDossierExistant() renvoie null si aucune base legacy',
      () async {
    final racine =
        await Directory.systemTemp.createTemp('mstk_migration_test2_');
    addTearDown(() => racine.delete(recursive: true));

    PathProviderPlatform.instance = _FakePathProvider(
        p.join(racine.path, 'Documents'), p.join(racine.path, 'tmp'));

    expect(await MstkMigrationService.detecterDossierExistant(), isNull);
  });
}
