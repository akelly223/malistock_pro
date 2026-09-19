import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Gère le cycle de vie des dossiers de travail temporaires utilisés
/// pendant qu'un fichier `.mstk` est ouvert : le contenu déchiffré y
/// vit le temps de la session (base SQLite classique + logo/signature/
/// cachet), et le dossier est supprimé à la fermeture — jamais de
/// `.sqlite`/`-wal`/`-shm` visible ailleurs qu'ici, temporairement.
abstract final class TempWorkspaceService {
  static const _prefixe = 'mstk_session_';

  /// Crée un nouveau dossier de travail vide, au nom unique.
  static Future<Directory> creerDossier() async {
    final base = await getTemporaryDirectory();
    final dossier =
        Directory(p.join(base.path, '$_prefixe${const Uuid().v4()}'));
    await dossier.create(recursive: true);
    return dossier;
  }

  /// Supprime [dossier] et son contenu, avec plusieurs tentatives
  /// espacées (mêmes verrous Windows résiduels possibles qu'à la
  /// restauration d'une sauvegarde — voir `BackupService`).
  static Future<void> supprimerDossier(Directory dossier) async {
    if (!await dossier.exists()) return;
    for (var tentative = 0; tentative < 5; tentative++) {
      try {
        await dossier.delete(recursive: true);
        return;
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 300 * (tentative + 1)));
      }
    }
    await dossier.delete(recursive: true);
  }

  /// Supprime tous les dossiers `mstk_session_*` orphelins d'une
  /// précédente exécution qui ne s'est pas terminée proprement
  /// (crash). À appeler seulement après confirmation qu'aucune autre
  /// instance de l'application n'est en cours d'exécution (le mutex
  /// d'instance unique de la Phase 4 sert de garde).
  static Future<void> nettoyerDossiersOrphelins() async {
    final base = await getTemporaryDirectory();
    if (!await base.exists()) return;
    for (final entite in base.listSync()) {
      if (entite is Directory &&
          p.basename(entite.path).startsWith(_prefixe)) {
        await supprimerDossier(entite);
      }
    }
  }
}
