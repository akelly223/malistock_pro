import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/db_constants.dart';
import '../utils/folder_copy_utils.dart';

/// Résultat d'un changement d'emplacement des données.
class DataLocationResult {
  final bool succes;
  final String message;
  final bool donneesExistantesReutilisees;

  const DataLocationResult({
    required this.succes,
    required this.message,
    this.donneesExistantesReutilisees = false,
  });
}

/// Permet de déporter le dossier de données (base SQLite + logo,
/// signature, cachet, sauvegardes...) vers un dossier au choix — par
/// exemple un dossier synchronisé par Google Drive, OneDrive ou
/// Dropbox, pour retrouver ses données sur plusieurs ordinateurs sans
/// serveur central.
///
/// Le pointeur vers ce dossier est stocké localement, hors du dossier
/// de données lui-même (donc jamais synchronisé) : chaque ordinateur
/// doit choisir explicitement son dossier partagé une fois, via
/// [deplacerVers].
///
/// ATTENTION (documentée aussi côté UI) : un fichier SQLite n'est pas
/// conçu pour être ouvert simultanément par deux processus sur deux
/// machines différentes. L'application appelante DOIT fermer sa
/// connexion à la base (checkpoint WAL + close) avant tout appel à
/// [deplacerVers] ou [reinitialiser], et l'utilisateur doit attendre
/// la fin de la synchronisation avant d'ouvrir l'app sur un autre
/// poste. C'est un compromis assumé pour ce cas d'usage (un seul
/// poste actif à la fois), pas une synchronisation temps réel
/// multi-utilisateur.
abstract final class DataLocationService {
  static const _fichierPointeur = 'emplacement_donnees.json';

  static Future<File> _fichierConfig() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fichierPointeur));
  }

  /// Dossier de données par défaut (Documents\MaliStockPro).
  static Future<String> getCheminParDefaut() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'MaliStockPro');
  }

  /// Dossier personnalisé choisi par l'utilisateur, ou null si aucun
  /// n'est configuré (ou si le dossier configuré n'existe plus, ex :
  /// clé USB débranchée ou dossier Drive pas encore synchronisé sur
  /// ce poste — dans ce cas on retombe sur le dossier par défaut).
  static Future<String?> getCheminPersonnalise() async {
    try {
      final fichier = await _fichierConfig();
      if (!await fichier.exists()) return null;
      final contenu = jsonDecode(await fichier.readAsString());
      final chemin = contenu is Map ? contenu['chemin'] as String? : null;
      if (chemin == null || chemin.isEmpty) return null;
      if (!await Directory(chemin).exists()) return null;
      return chemin;
    } catch (_) {
      return null;
    }
  }

  /// Dossier de données effectif (personnalisé si configuré et
  /// disponible, sinon le dossier par défaut).
  static Future<String> getCheminEffectif() async {
    return await getCheminPersonnalise() ?? await getCheminParDefaut();
  }

  /// Déplace les données vers [cheminCible] et enregistre ce nouveau
  /// dossier comme emplacement courant.
  ///
  /// Si [cheminCible] contient déjà un fichier de base de données
  /// (cas d'un dossier Drive déjà lié depuis un autre poste et déjà
  /// synchronisé ici), il est conservé tel quel et les données
  /// locales ne sont PAS copiées par-dessus — pour ne jamais écraser
  /// des données potentiellement plus complètes. Les données locales
  /// de ce poste restent intactes à leur emplacement précédent, en
  /// secours.
  ///
  /// L'appelant doit avoir fermé la connexion à la base AVANT
  /// d'appeler cette méthode (voir avertissement de la classe).
  static Future<DataLocationResult> deplacerVers(String cheminCible) async {
    try {
      final cibleDir = Directory(cheminCible);
      if (!await cibleDir.exists()) {
        await cibleDir.create(recursive: true);
      }

      final fichierBaseCible =
          File(p.join(cheminCible, DbConstants.dbFileName));
      final cibleAUneBaseExistante = await fichierBaseCible.exists();

      if (!cibleAUneBaseExistante) {
        final sourceDir = Directory(await getCheminEffectif());
        if (await sourceDir.exists()) {
          await copierDossierDonneesApp(sourceDir, cibleDir);
        }
      }

      await _ecrireCheminPersonnalise(cheminCible);

      return DataLocationResult(
        succes: true,
        message: cibleAUneBaseExistante
            ? 'Dossier lié : les données déjà présentes dans ce dossier seront utilisées.'
            : 'Données copiées vers le nouvel emplacement.',
        donneesExistantesReutilisees: cibleAUneBaseExistante,
      );
    } catch (e) {
      return DataLocationResult(
        succes: false,
        message: 'Erreur lors du changement d\'emplacement : $e',
      );
    }
  }

  /// Revient à l'emplacement par défaut (dossier local des
  /// Documents). Les données du dossier personnalisé ne sont ni
  /// supprimées ni rapatriées automatiquement.
  static Future<void> reinitialiser() async {
    final fichier = await _fichierConfig();
    if (await fichier.exists()) {
      await fichier.delete();
    }
  }

  static Future<void> _ecrireCheminPersonnalise(String chemin) async {
    final fichier = await _fichierConfig();
    await fichier.create(recursive: true);
    await fichier.writeAsString(jsonEncode({'chemin': chemin}));
  }

}
