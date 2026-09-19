import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Petite liste des derniers fichiers `.mstk` ouverts, affichée sur
/// l'écran d'accueil. Stockée à côté du pointeur d'emplacement de
/// données (même dossier, même approche que `DataLocationService`).
abstract final class RecentFilesService {
  static const _fichierPointeur = 'fichiers_recents.json';
  static const _maxEntrees = 8;

  static Future<File> _fichier() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fichierPointeur));
  }

  /// Liste des chemins récents, filtrée des fichiers qui n'existent
  /// plus (clé USB débranchée, fichier déplacé/supprimé...).
  static Future<List<String>> lister() async {
    try {
      final fichier = await _fichier();
      if (!await fichier.exists()) return [];
      final contenu = jsonDecode(await fichier.readAsString());
      final chemins =
          (contenu is List) ? contenu.whereType<String>().toList() : <String>[];

      final valides = <String>[];
      for (final chemin in chemins) {
        if (await File(chemin).exists()) valides.add(chemin);
      }
      return valides;
    } catch (_) {
      return [];
    }
  }

  static Future<void> ajouter(String chemin) async {
    final actuels = await lister();
    actuels.remove(chemin);
    actuels.insert(0, chemin);
    final limites = actuels.take(_maxEntrees).toList();

    final fichier = await _fichier();
    await fichier.create(recursive: true);
    await fichier.writeAsString(jsonEncode(limites));
  }
}
