import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:archive/archive_io.dart';
import 'package:malistock_pro/core/services/backup_service.dart';
import 'package:malistock_pro/data/local/database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

/// Vérifie que la restauration d'une sauvegarde rejette toute entrée
/// d'archive dont le chemin sort du dossier de données (protection
/// "zip slip") plutôt que de l'écrire n'importe où sur le disque.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restaurerSauvegarde ignore les entrées hors du dossier de données',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('backup_zip_slip_test');
    addTearDown(() => tempDir.delete(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

    final dataDir = Directory(await AppDatabase.getDatabaseDirectory());
    await dataDir.create(recursive: true);

    final archive = Archive()
      ..addFile(ArchiveFile(
        'malistock_pro.sqlite',
        'contenu factice'.length,
        'contenu factice'.codeUnits,
      ))
      ..addFile(ArchiveFile(
        '../evil_outside.txt',
        'PWNED'.length,
        'PWNED'.codeUnits,
      ));

    final zipBytes = ZipEncoder().encode(archive)!;
    final cheminZip = p.join(tempDir.path, 'malicious.zip');
    await File(cheminZip).writeAsBytes(zipBytes);

    final db = AppDatabase.withExecutor(NativeDatabase.memory());

    final resultat = await BackupService.restaurerSauvegarde(cheminZip, db);

    expect(resultat.succes, isTrue, reason: resultat.message);
    expect(
      File(p.join(dataDir.path, 'malistock_pro.sqlite')).existsSync(),
      isTrue,
      reason: 'le fichier légitime de l\'archive doit être restauré',
    );
    expect(
      File(p.join(tempDir.path, 'evil_outside.txt')).existsSync(),
      isFalse,
      reason:
          'une entrée "../evil_outside.txt" ne doit jamais être écrite hors du dossier de données',
    );
  });
}
