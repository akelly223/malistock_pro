import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../data/local/database.dart';

/// Résultat d'une opération de sauvegarde ou restauration, pour
/// remonter un message clair à l'utilisateur sans exposer de détails
/// techniques bruts.
class BackupResult {
  final bool succes;
  final String message;
  final String? filePath;

  const BackupResult({
    required this.succes,
    required this.message,
    this.filePath,
  });
}

/// Sauvegarde et restauration complètes des données de l'application
/// (base SQLite + PDF générés + logo entreprise) sous forme d'une
/// archive ZIP unique, manipulable par un commerçant sans connaissance
/// technique : un seul fichier à copier sur une clé USB ou un disque
/// externe.
class BackupService {
  BackupService._();

  static const String _backupFolderName = 'sauvegardes';

  /// Crée une archive ZIP horodatée contenant tout le dossier de
  /// données de l'application, et retourne son chemin.
  ///
  /// [db] est nécessaire pour forcer un point de cohérence SQLite
  /// (checkpoint WAL) avant la copie, afin que le fichier .sqlite
  /// inclus dans l'archive ne soit jamais à moitié écrit.
  static Future<BackupResult> exporterSauvegarde(AppDatabase db) async {
    try {
      // Force l'écriture de toute donnée en mémoire tampon sur le
      // disque avant de copier le fichier .sqlite. Sans effet si la
      // base n'est pas en mode WAL, donc toujours sûr à appeler.
      await db.customStatement('PRAGMA wal_checkpoint(FULL)');

      final dataDir = Directory(await AppDatabase.getDatabaseDirectory());
      if (!await dataDir.exists()) {
        return const BackupResult(
          succes: false,
          message: 'Aucune donnée à sauvegarder pour le moment.',
        );
      }

      final backupDir =
          Directory(p.join(dataDir.path, _backupFolderName));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final horodatage = _formatHorodatage(DateTime.now());
      final nomFichier = 'sauvegarde_$horodatage.zip';
      final cheminArchive = p.join(backupDir.path, nomFichier);

      final encoder = ZipFileEncoder();
      encoder.create(cheminArchive);

      // Parcourt tout le dossier de données SAUF le dossier des
      // sauvegardes lui-même, pour ne pas imbriquer une sauvegarde
      // dans la suivante indéfiniment.
      final entries = dataDir.listSync(recursive: false);
      for (final entry in entries) {
        final nom = p.basename(entry.path);
        if (nom == _backupFolderName) continue;

        if (entry is Directory) {
          encoder.addDirectory(entry, includeDirName: true);
        } else if (entry is File) {
          encoder.addFile(entry);
        }
      }

      encoder.close();

      return BackupResult(
        succes: true,
        message: 'Sauvegarde créée avec succès.',
        filePath: cheminArchive,
      );
    } catch (e) {
      return BackupResult(
        succes: false,
        message: 'Erreur lors de la sauvegarde : $e',
      );
    }
  }

  /// Restaure une archive ZIP préalablement créée par
  /// [exporterSauvegarde], en écrasant les données actuelles.
  ///
  /// IMPORTANT : [db] est fermée explicitement avant toute
  /// manipulation de fichiers. Sur Windows, un dossier contenant un
  /// fichier encore ouvert par un processus (ici la connexion SQLite
  /// active de l'application) ne peut être ni renommé ni déplacé —
  /// c'est la cause exacte de l'erreur "Accès refusé (errno=5)"
  /// observée en production. Fermer la connexion avant de toucher
  /// aux fichiers élimine ce verrou.
  ///
  /// L'application DOIT être redémarrée après cet appel : la
  /// connexion fermée ici ne sera jamais rouverte côté code, pour
  /// éviter tout risque d'incohérence avec une base déjà partiellement
  /// remplacée pendant que l'app continue de tourner.
  static Future<BackupResult> restaurerSauvegarde(
      String cheminZip, AppDatabase db) async {
    try {
      final fichierZip = File(cheminZip);
      if (!await fichierZip.exists()) {
        return const BackupResult(
          succes: false,
          message: 'Le fichier de sauvegarde sélectionné est introuvable.',
        );
      }

      // Ferme la connexion SQLite active AVANT toute manipulation de
      // fichiers, pour libérer le verrou Windows sur malistock_pro.sqlite.
      // Sans cette étape, tout déplacement/renommage du dossier de
      // données échoue avec "Accès refusé" sur Windows.
      await db.close();

      final dataDir = Directory(await AppDatabase.getDatabaseDirectory());

      // Sauvegarde de sécurité du dossier actuel avant restauration,
      // au cas où l'archive sélectionnée serait corrompue ou invalide
      // — on ne veut jamais perdre les données actuelles sans filet.
      //
      // Copie fichier par fichier plutôt que renommer le dossier
      // entier : plus robuste face aux verrous Windows résiduels
      // (antivirus, indexation Windows Search...) qui peuvent encore
      // tenir un descripteur ouvert sur un sous-fichier même après
      // la fermeture de la connexion Drift elle-même.
      if (await dataDir.exists()) {
        final dossierSecours = Directory(
            '${dataDir.path}_avant_restauration_${_formatHorodatage(DateTime.now())}');
        await _copierDossier(dataDir, dossierSecours);
        await _supprimerDossierAvecRetry(dataDir);
      }

      await Directory(dataDir.path).create(recursive: true);

      final bytes = await fichierZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final fichier in archive) {
        final cheminSortie = p.normalize(p.join(dataDir.path, fichier.name));
        // Rejette toute entrée d'archive dont le chemin résultant sort
        // du dossier de données (ex: nom contenant "..\" ou un chemin
        // absolu) — protection contre une archive "zip slip" forgée
        // qui écrirait un fichier arbitraire ailleurs sur le disque.
        if (!p.isWithin(dataDir.path, cheminSortie)) {
          continue;
        }
        if (fichier.isFile) {
          final contenu = fichier.content;
          final fichierSortie = File(cheminSortie);
          await fichierSortie.create(recursive: true);
          if (contenu is List<int>) {
            await fichierSortie.writeAsBytes(contenu);
          }
        } else {
          await Directory(cheminSortie).create(recursive: true);
        }
      }

      return const BackupResult(
        succes: true,
        message:
            'Sauvegarde restaurée. Fermez puis relancez l\'application pour appliquer les données restaurées.',
      );
    } catch (e) {
      return BackupResult(
        succes: false,
        message: 'Erreur lors de la restauration : $e',
      );
    }
  }

  /// Copie récursivement le contenu d'un dossier vers un autre,
  /// fichier par fichier — utilisé à la place d'un renommage de
  /// dossier, qui échoue sur Windows si un sous-fichier est encore
  /// verrouillé par un autre processus.
  static Future<void> _copierDossier(Directory source, Directory cible) async {
    await cible.create(recursive: true);
    for (final entite in source.listSync(recursive: false)) {
      final nom = p.basename(entite.path);
      final cheminCible = p.join(cible.path, nom);
      if (entite is Directory) {
        await _copierDossier(entite, Directory(cheminCible));
      } else if (entite is File) {
        await entite.copy(cheminCible);
      }
    }
  }

  /// Supprime un dossier avec plusieurs tentatives espacées : sur
  /// Windows, un fichier peut rester verrouillé quelques centaines de
  /// millisecondes après la fermeture de la connexion qui l'utilisait
  /// (l'OS libère le descripteur de façon asynchrone). Réessayer
  /// évite un échec ponctuel qui n'a aucune cause réelle persistante.
  static Future<void> _supprimerDossierAvecRetry(Directory dossier) async {
    for (var tentative = 0; tentative < 5; tentative++) {
      try {
        await dossier.delete(recursive: true);
        return;
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 300 * (tentative + 1)));
      }
    }
    // Dernière tentative sans rattraper l'erreur : si ça échoue
    // encore, l'appelant doit le savoir plutôt qu'échouer
    // silencieusement plus loin dans la restauration.
    await dossier.delete(recursive: true);
  }

  /// Liste les sauvegardes déjà créées, les plus récentes en premier.
  static Future<List<File>> listerSauvegardes() async {
    final dataDir = Directory(await AppDatabase.getDatabaseDirectory());
    final backupDir = Directory(p.join(dataDir.path, _backupFolderName));
    if (!await backupDir.exists()) return [];

    final fichiers = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();
    fichiers.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return fichiers;
  }

  static String _formatHorodatage(DateTime date) {
    final annee = date.year.toString().padLeft(4, '0');
    final mois = date.month.toString().padLeft(2, '0');
    final jour = date.day.toString().padLeft(2, '0');
    final heure = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$annee-$mois-${jour}_$heure$minute';
  }

  /// Déclenche une sauvegarde automatique silencieuse si aucune
  /// sauvegarde (manuelle ou automatique) n'a déjà été faite
  /// aujourd'hui. Conçue pour être appelée une fois au lancement de
  /// l'application, sans bloquer ni notifier l'utilisateur en cas de
  /// succès — seul un échec mérite d'être signalé, pour ne pas
  /// laisser le commerçant croire que ses données sont protégées
  /// alors que la sauvegarde a réellement échoué.
  ///
  /// Ne remplace jamais la sauvegarde manuelle : c'est un filet de
  /// sécurité supplémentaire, pas le seul mécanisme de sauvegarde.
  static Future<BackupResult?> sauvegarderAutomatiquementSiNecessaire(
      AppDatabase db) async {
    try {
      final sauvegardesExistantes = await listerSauvegardes();
      final aujourdHui = DateTime.now();

      final dejaSauvegardeAujourdHui = sauvegardesExistantes.any((fichier) {
        final modifie = fichier.statSync().modified;
        return modifie.year == aujourdHui.year &&
            modifie.month == aujourdHui.month &&
            modifie.day == aujourdHui.day;
      });

      if (dejaSauvegardeAujourdHui) return null;

      return await exporterSauvegarde(db);
    } catch (e) {
      return BackupResult(
        succes: false,
        message: 'Sauvegarde automatique impossible : $e',
      );
    }
  }
}
