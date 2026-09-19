import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:malistock_pro/core/container/active_container_context.dart';
import 'package:malistock_pro/core/container/mstk_container_service.dart';
import 'package:malistock_pro/core/services/mstk_migration_service.dart';
import 'package:malistock_pro/core/utils/password_hasher.dart';
import 'package:malistock_pro/data/local/database.dart';

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

/// Reproduit le signalement utilisateur : "après avoir converti mon
/// ancien dossier, l'app me redemande de créer un nouvel
/// utilisateur/mot de passe comme sur un fichier neuf" — c'est-à-dire
/// que l'admin créé dans l'ancienne base ne serait pas retrouvé après
/// la migration `.mstk`. Ce test utilise une VRAIE base Drift/SQLite
/// (pas des octets factices comme mstk_migration_service_test.dart),
/// exactement le chemin emprunté par l'app réelle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'un admin créé avant migration est retrouvé (hasAdmin=true) après '
      'ouverture du fichier .mstk converti', () async {
    final racine =
        await Directory.systemTemp.createTemp('mstk_migration_e2e_');
    addTearDown(() => racine.delete(recursive: true));
    addTearDown(() => ActiveContainerContext.definir(null));

    final docDir = Directory(p.join(racine.path, 'Documents'));
    PathProviderPlatform.instance = _FakePathProvider(
        docDir.path, p.join(racine.path, 'tmp_provider'));

    // 1. Simule l'ancienne app : aucun conteneur actif, AppDatabase
    // s'ouvre donc sur le dossier legacy par défaut. Crée un admin.
    ActiveContainerContext.definir(null);
    final legacyDb = AppDatabase();
    await legacyDb.usersDao.createUser(UsersCompanion.insert(
      nom: 'Admin Test',
      login: 'admin',
      motDePasseHash: PasswordHasher.hash('Secret123'),
      role: 'admin',
    ));
    expect(await legacyDb.usersDao.hasAdmin(), isTrue,
        reason: 'sanity check avant migration');
    await legacyDb.customStatement('PRAGMA wal_checkpoint(FULL)');
    await legacyDb.close();

    final dossierLegacy = await MstkMigrationService.detecterDossierExistant();
    expect(dossierLegacy, isNotNull,
        reason: 'le dossier legacy doit être détecté après création de l\'admin');

    // 2. Migration, exactement comme le bouton "Convertir vers le
    // nouveau format" de l'écran d'accueil.
    final destination = File(p.join(racine.path, 'converti.mstk'));
    await MstkMigrationService.migrer(
      dossierSource: dossierLegacy!,
      fichierDestination: destination,
    );

    // 3. Ouvre le fichier migré et pointe AppDatabase dessus, comme le
    // fait activeContainerProvider._activer().
    final ouvert = await MstkContainerService.ouvrir(destination);
    ActiveContainerContext.definir(ouvert.dossierTravail.path);

    final dbMigree = AppDatabase();
    final aUnAdmin = await dbMigree.usersDao.hasAdmin();
    final utilisateur = await dbMigree.usersDao.getUserByLogin('admin');

    expect(aUnAdmin, isTrue,
        reason: 'L\'admin créé avant migration doit être retrouvé après '
            'conversion .mstk — sinon l\'app redemande de créer un compte '
            'comme sur un fichier neuf');
    expect(utilisateur, isNotNull);
    expect(utilisateur!.nom, 'Admin Test');

    await dbMigree.close();
    await MstkContainerService.fermer(ouvert);
  });
}
