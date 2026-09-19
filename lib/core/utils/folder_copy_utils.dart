import 'dart:io';
import 'package:path/path.dart' as p;

import '../constants/db_constants.dart';

/// Entrées système/cloud connues à ne jamais copier : corbeilles OS
/// (`.Trash` sur macOS/iCloud Drive, `$RECYCLE.BIN` sur Windows...) et
/// fichiers d'indexation, jamais des données de l'application. Les
/// rencontrer dans un dossier source ne doit pas faire échouer toute
/// la copie.
const _entreesIgnorees = {
  '.trash',
  '.trashes',
  '.fseventsd',
  '.spotlight-v100',
  'system volume information',
  r'$recycle.bin',
  '.ds_store',
  'thumbs.db',
  'desktop.ini',
};

/// Entrées que l'application peut réellement créer à la racine de son
/// dossier de données (voir `AppDatabase.getDatabaseDirectory()`,
/// `LogoService`, `BackupService`) : la base SQLite et ses fichiers
/// annexes WAL/SHM/journal, plus les sous-dossiers logo/signature/
/// cachet/sauvegardes. Toute autre entrée à cette racine n'appartient
/// pas à l'application.
final _entreesDonneesApp = {
  DbConstants.dbFileName.toLowerCase(),
  '${DbConstants.dbFileName.toLowerCase()}-wal',
  '${DbConstants.dbFileName.toLowerCase()}-shm',
  '${DbConstants.dbFileName.toLowerCase()}-journal',
  'logo',
  'signature',
  'cachet',
  'sauvegardes',
};

/// Copie vers [cible] uniquement les entrées de [source] que
/// l'application a pu elle-même y créer (voir [_entreesDonneesApp]),
/// en ignorant tout le reste.
///
/// [source] est un « dossier de données » choisi par l'utilisateur
/// (emplacement personnalisé, ou ancien dossier legacy à convertir en
/// `.mstk`) : rien n'empêche qu'il pointe en réalité sur la racine
/// entière d'un service cloud (iCloud Drive, OneDrive...) plutôt que
/// sur un sous-dossier dédié. Copier aveuglément tout son contenu
/// copierait alors des quantités arbitraires de fichiers personnels
/// sans rapport avec l'application — au mieux une copie interminable
/// (le fournisseur cloud doit d'abord télécharger chaque fichier), au
/// pire un échec sur un fichier hors du contrôle de l'application
/// (voir aussi [_entreesIgnorees] pour les dossiers système/corbeille
/// que le fournisseur cloud lui-même y ajoute).
///
/// Retourne les chemins des fichiers ignorés à cause d'une erreur de
/// copie (jamais ceux simplement hors du périmètre de l'application),
/// pour que l'appelant puisse en avertir l'utilisateur.
Future<List<String>> copierDossierDonneesApp(
  Directory source,
  Directory cible,
) async {
  final ignores = <String>[];
  await cible.create(recursive: true);
  for (final entite in source.listSync(recursive: false)) {
    final nom = p.basename(entite.path);
    if (!_entreesDonneesApp.contains(nom.toLowerCase())) continue;

    final cheminCible = p.join(cible.path, nom);
    if (entite is Directory) {
      await _copier(entite, Directory(cheminCible), ignores);
    } else if (entite is File) {
      try {
        await entite.copy(cheminCible);
      } on FileSystemException {
        ignores.add(entite.path);
      }
    }
  }
  return ignores;
}

Future<void> _copier(
  Directory source,
  Directory cible,
  List<String> ignores,
) async {
  await cible.create(recursive: true);
  for (final entite in source.listSync(recursive: false)) {
    final nom = p.basename(entite.path);
    if (_entreesIgnorees.contains(nom.toLowerCase())) continue;

    final cheminCible = p.join(cible.path, nom);
    if (entite is Directory) {
      await _copier(entite, Directory(cheminCible), ignores);
    } else if (entite is File) {
      try {
        await entite.copy(cheminCible);
      } on FileSystemException {
        ignores.add(entite.path);
      }
    }
  }
}
