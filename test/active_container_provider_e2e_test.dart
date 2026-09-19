import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:malistock_pro/app/providers/active_container_provider.dart';
import 'package:malistock_pro/core/container/active_container_context.dart';
import 'package:malistock_pro/core/services/mstk_migration_service.dart';
import 'package:malistock_pro/core/utils/password_hasher.dart';
import 'package:malistock_pro/data/local/database.dart';
import 'package:malistock_pro/presentation/auth/providers/auth_provider.dart';

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

/// Même scénario que mstk_migration_e2e_test.dart, mais en passant
/// par les VRAIS providers Riverpod utilisés par l'app
/// (activeContainerProvider, databaseProvider, hasAdminProvider) au
/// lieu de manipuler AppDatabase/ActiveContainerContext directement —
/// pour isoler un éventuel bug de câblage Riverpod que l'autre test
/// ne peut pas voir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'après ouverture via activeContainerProvider.ouvrir(), '
      'hasAdminProvider retrouve l\'admin migré', () async {
    final racine = await Directory.systemTemp
        .createTemp('active_container_provider_e2e_');
    addTearDown(() => racine.delete(recursive: true));
    addTearDown(() => ActiveContainerContext.definir(null));

    final docDir = Directory(p.join(racine.path, 'Documents'));
    PathProviderPlatform.instance = _FakePathProvider(
        docDir.path, p.join(racine.path, 'tmp_provider'));

    // 1. Ancienne base avec un admin.
    ActiveContainerContext.definir(null);
    final legacyDb = AppDatabase();
    await legacyDb.usersDao.createUser(UsersCompanion.insert(
      nom: 'Admin Test',
      login: 'admin',
      motDePasseHash: PasswordHasher.hash('Secret123'),
      role: 'admin',
    ));
    await legacyDb.customStatement('PRAGMA wal_checkpoint(FULL)');
    await legacyDb.close();

    final dossierLegacy = await MstkMigrationService.detecterDossierExistant();
    expect(dossierLegacy, isNotNull);

    // 2. Migration.
    final destination = File(p.join(racine.path, 'converti.mstk'));
    await MstkMigrationService.migrer(
      dossierSource: dossierLegacy!,
      fichierDestination: destination,
    );

    // 3. Ouverture via le VRAI provider, comme le fait
    // ContainerActions.ouvrir() dans l'app.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(activeContainerProvider.notifier)
        .ouvrir(destination);

    final hasAdmin = await container.read(hasAdminProvider.future);

    expect(hasAdmin, isTrue,
        reason: 'reproduit le signalement : hasAdminProvider doit voir '
            'l\'admin migré, pas se comporter comme sur un fichier neuf');

    await container.read(activeContainerProvider.notifier).fermer();
  });
}
