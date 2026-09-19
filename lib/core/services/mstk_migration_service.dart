import 'dart:io';
import 'package:path/path.dart' as p;

import '../constants/db_constants.dart';
import '../container/mstk_container_service.dart';
import '../utils/folder_copy_utils.dart';
import 'data_location_service.dart';

/// Convertit l'ancien dossier de données (base SQLite classique et
/// visible + logo/signature/cachet) vers le nouveau format de fichier
/// `.mstk`. Le dossier source n'est JAMAIS modifié ni supprimé —
/// aucune étape de suppression n'existe dans cette classe, c'est une
/// garantie structurelle plutôt qu'un simple engagement documenté.
abstract final class MstkMigrationService {
  /// Chemin du dossier legacy actuel, ou `null` s'il n'existe pas ou
  /// ne contient pas de base de données (rien à convertir).
  static Future<String?> detecterDossierExistant() async {
    final chemin = await DataLocationService.getCheminEffectif();
    final fichierDb = File(p.join(chemin, DbConstants.dbFileName));
    if (!await fichierDb.exists()) return null;
    return chemin;
  }

  /// Convertit [dossierSource] vers un nouveau fichier `.mstk` à
  /// [fichierDestination]. Retourne les chemins des fichiers qui n'ont
  /// pas pu être copiés (ex : placeholders cloud non téléchargés dans
  /// un dossier iCloud Drive/OneDrive) — la conversion continue sans
  /// eux plutôt que d'échouer entièrement.
  static Future<List<String>> migrer({
    required String dossierSource,
    required File fichierDestination,
    String? motDePasse,
  }) async {
    final container = await MstkContainerService.creerNouveau(
      fichierDestination,
      motDePasse: motDePasse,
    );
    try {
      final ignores = await copierDossierDonneesApp(
          Directory(dossierSource), container.dossierTravail);
      await MstkContainerService.sauvegarder(container);
      return ignores;
    } finally {
      await MstkContainerService.fermer(container);
    }
  }
}
