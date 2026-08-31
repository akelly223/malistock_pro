import 'dart:io';
import 'package:path/path.dart' as p;
import '../../data/local/database.dart';

class LogoService {
  LogoService._();

  static Future<String> importerLogo(String cheminFichierSource) =>
      _importerAsset(cheminFichierSource, 'logo');

  static Future<String> importerSignature(String cheminFichierSource) =>
      _importerAsset(cheminFichierSource, 'signature');

  static Future<String> importerCachet(String cheminFichierSource) =>
      _importerAsset(cheminFichierSource, 'cachet');

  static Future<void> supprimerLogo(String? cheminActuel) =>
      _supprimerAsset(cheminActuel);

  static Future<void> supprimerSignature(String? cheminActuel) =>
      _supprimerAsset(cheminActuel);

  static Future<void> supprimerCachet(String? cheminActuel) =>
      _supprimerAsset(cheminActuel);

  // ── Helpers ──────────────────────────────────────────────────────

  static Future<String> _importerAsset(
      String cheminSource, String sousType) async {
    final dataDir = Directory(await AppDatabase.getDatabaseDirectory());
    final dir = Directory(p.join(dataDir.path, sousType));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Supprime tout fichier précédent du même type
    for (final entry in dir.listSync()) {
      if (entry is File) await entry.delete();
    }

    final extension = p.extension(cheminSource);
    final dest = p.join(dir.path, '$sousType$extension');
    await File(cheminSource).copy(dest);
    return dest;
  }

  static Future<void> _supprimerAsset(String? chemin) async {
    if (chemin == null) return;
    final fichier = File(chemin);
    if (await fichier.exists()) await fichier.delete();
  }
}
