import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'mstk_crypto.dart';
import 'mstk_exceptions.dart';
import 'mstk_header.dart';
import 'temp_workspace_service.dart';

/// Le fichier `.mstk` visé est déjà ouvert par une autre instance (ou
/// un autre processus) de l'application.
final class MstkVerrouilleException extends MstkException {
  const MstkVerrouilleException(
      [super.message =
          'Ce fichier est déjà ouvert par une autre instance de MaliStock Pro.']);
}

/// Un fichier `.mstk` actuellement ouvert : verrou OS exclusif tenu
/// sur le fichier, dossier de travail temporaire contenant les
/// données déchiffrées (base SQLite classique + logo/signature/
/// cachet), prêtes à être utilisées normalement par `AppDatabase`.
class OpenedMstkContainer {
  String cheminFichier;
  final Directory dossierTravail;
  RandomAccessFile _verrou;
  String? motDePasse;

  OpenedMstkContainer._(
      this.cheminFichier, this.dossierTravail, this._verrou, this.motDePasse);
}

/// Orchestration du cycle de vie d'un fichier `.mstk` : ouverture
/// (verrou exclusif + déchiffrement vers un dossier temporaire),
/// sauvegarde (rechiffrement + écriture atomique), fermeture
/// (nettoyage du dossier temporaire).
///
/// Ce service ne connaît pas Drift/`AppDatabase` : l'appelant est
/// responsable de fermer la connexion DB avant [sauvegarder]/[fermer]
/// et de la rouvrir après [ouvrir]/[creerNouveau] (voir
/// `ActiveContainerContext`), exactement comme `BackupService` le fait
/// déjà pour les sauvegardes ZIP classiques.
abstract final class MstkContainerService {
  /// Chemins actuellement ouverts par CE processus. Le verrou OS
  /// ([_verrouiller]) protège contre un autre processus (autre
  /// instance de l'app, ou double-clic pendant qu'elle tourne déjà —
  /// Phase 4) ; ce registre en mémoire protège contre une double
  /// ouverture DANS le même processus, cas où le verrou OS seul s'est
  /// avéré peu fiable sous Windows (deux handles du même processus
  /// peuvent parfois se re-verrouiller sans erreur).
  static final Set<String> _cheminsOuverts = <String>{};

  static String _cle(File fichier) => p.normalize(fichier.absolute.path);

  /// Ouvre [fichier] : verrouille l'accès exclusif, valide l'en-tête,
  /// déchiffre et extrait le contenu dans un nouveau dossier
  /// temporaire.
  ///
  /// Lève [MstkVerrouilleException] si le fichier est déjà ouvert
  /// ailleurs, et les exceptions de [MstkCrypto]/[MstkHeader] pour un
  /// mot de passe incorrect ou un fichier corrompu.
  static Future<OpenedMstkContainer> ouvrir(
    File fichier, {
    String? motDePasse,
  }) async {
    final cle = _cle(fichier);
    if (_cheminsOuverts.contains(cle)) {
      throw const MstkVerrouilleException();
    }
    _cheminsOuverts.add(cle);

    final RandomAccessFile verrou;
    try {
      verrou = await _verrouiller(fichier);
    } catch (_) {
      _cheminsOuverts.remove(cle);
      rethrow;
    }

    Directory? dossier;
    try {
      final taille = await verrou.length();
      await verrou.setPosition(0);
      final octets = Uint8List.fromList(await verrou.read(taille));

      final header = MstkHeader.decode(octets);
      final ciphertext = octets.sublist(MstkHeader.headerLength);
      final zipBytes = await MstkCrypto.dechiffrer(
        header: header,
        ciphertext: ciphertext,
        motDePasse: motDePasse,
      );

      dossier = await TempWorkspaceService.creerDossier();
      _extraireZip(zipBytes, dossier);

      return OpenedMstkContainer._(
          fichier.path, dossier, verrou, motDePasse);
    } catch (_) {
      if (dossier != null) await TempWorkspaceService.supprimerDossier(dossier);
      await verrou.unlock();
      await verrou.close();
      _cheminsOuverts.remove(cle);
      rethrow;
    }
  }

  /// Crée un nouveau conteneur vide à [fichier] (écrase si déjà
  /// présent — l'appelant doit avoir confirmé avec l'utilisateur) et
  /// l'ouvre immédiatement, verrouillé.
  static Future<OpenedMstkContainer> creerNouveau(
    File fichier, {
    String? motDePasse,
  }) async {
    final cle = _cle(fichier);
    if (_cheminsOuverts.contains(cle)) {
      throw const MstkVerrouilleException();
    }
    _cheminsOuverts.add(cle);

    final dossier = await TempWorkspaceService.creerDossier();
    try {
      await _ecrireContainer(
        cheminDestination: fichier.path,
        dossierSource: dossier,
        motDePasse: motDePasse,
      );
      final verrou = await _verrouiller(fichier);
      return OpenedMstkContainer._(
          fichier.path, dossier, verrou, motDePasse);
    } catch (_) {
      await TempWorkspaceService.supprimerDossier(dossier);
      _cheminsOuverts.remove(cle);
      rethrow;
    }
  }

  /// Rezippe, rechiffre et réécrit [container] sur disque de façon
  /// atomique (fichier temporaire `.tmp` puis renommage) — le fichier
  /// original n'est jamais dans un état partiellement écrit, même en
  /// cas de crash pendant l'opération. Le verrou est brièvement relâché
  /// puis repris (nécessaire sous Windows pour pouvoir renommer par-
  /// dessus un fichier ouvert — même raisonnement que
  /// `BackupService.restaurerSauvegarde`).
  ///
  /// L'appelant doit avoir fait `PRAGMA wal_checkpoint(FULL)` puis
  /// fermé la connexion `AppDatabase` avant d'appeler cette méthode.
  static Future<void> sauvegarder(
    OpenedMstkContainer container, {
    String? nouveauMotDePasse,
  }) async {
    final motDePasse = nouveauMotDePasse ?? container.motDePasse;
    await _ecrireContainer(
      cheminDestination: container.cheminFichier,
      dossierSource: container.dossierTravail,
      motDePasse: motDePasse,
      remplacerFichierVerrouille: container._verrou,
    );
    container.motDePasse = motDePasse;
    // Reprend le verrou sur le fichier fraîchement remplacé.
    container._verrou = await _verrouiller(File(container.cheminFichier));
  }

  /// Enregistre une copie de [container] à [nouveauFichier] sans
  /// modifier le fichier ouvert ni son verrou.
  static Future<void> enregistrerSousCopie(
    OpenedMstkContainer container,
    File nouveauFichier, {
    String? motDePasse,
  }) {
    return _ecrireContainer(
      cheminDestination: nouveauFichier.path,
      dossierSource: container.dossierTravail,
      motDePasse: motDePasse ?? container.motDePasse,
    );
  }

  /// Ferme [container] : relâche le verrou et supprime le dossier de
  /// travail temporaire. N'enregistre rien — appeler [sauvegarder]
  /// avant si besoin.
  static Future<void> fermer(OpenedMstkContainer container) async {
    await container._verrou.unlock();
    await container._verrou.close();
    await TempWorkspaceService.supprimerDossier(container.dossierTravail);
    _cheminsOuverts.remove(_cle(File(container.cheminFichier)));
  }

  // ─── Verrouillage ────────────────────────────────────────────────

  static Future<RandomAccessFile> _verrouiller(File fichier) async {
    final raf = await fichier.open(mode: FileMode.append);
    try {
      return await raf.lock(FileLock.exclusive);
    } on FileSystemException {
      await raf.close();
      throw const MstkVerrouilleException();
    }
  }

  // ─── Écriture (chiffrement + assemblage de l'en-tête) ───────────

  static Future<void> _ecrireContainer({
    required String cheminDestination,
    required Directory dossierSource,
    required String? motDePasse,
    RandomAccessFile? remplacerFichierVerrouille,
  }) async {
    final zipBytes = _zipperDossier(dossierSource);
    final chiffre = await MstkCrypto.chiffrer(zipBytes, motDePasse: motDePasse);

    final header = MstkHeader(
      version: MstkHeader.currentVersion,
      motDePasseRequis: motDePasse != null && motDePasse.isNotEmpty,
      kdfId: chiffre.kdfId,
      kdfIterations: chiffre.kdfIterations,
      sel: chiffre.sel,
      nonce: chiffre.nonce,
      taillePayload: zipBytes.length,
      tagAuthentification: chiffre.tagAuthentification,
    );

    final octetsFichier = Uint8List(MstkHeader.headerLength + chiffre.ciphertext.length)
      ..setRange(0, MstkHeader.headerLength, header.encode())
      ..setRange(MstkHeader.headerLength, MstkHeader.headerLength + chiffre.ciphertext.length,
          chiffre.ciphertext);

    final cheminTmp = '$cheminDestination.tmp';
    await File(cheminTmp).writeAsBytes(octetsFichier, flush: true);

    if (remplacerFichierVerrouille != null) {
      // Sous Windows, impossible de renommer par-dessus un fichier
      // dont un handle est encore ouvert : on relâche le verrou juste
      // avant, le temps du renommage.
      await remplacerFichierVerrouille.unlock();
      await remplacerFichierVerrouille.close();
    }
    await File(cheminTmp).rename(cheminDestination);
  }

  // ─── Zip en mémoire (réutilise le principe de BackupService, sans
  // passer par un fichier .zip intermédiaire sur disque) ───────────

  static Uint8List _zipperDossier(Directory dossier) {
    final archive = Archive();
    for (final entite in dossier.listSync(recursive: true)) {
      if (entite is! File) continue;
      final cheminRelatif =
          p.relative(entite.path, from: dossier.path).replaceAll('\\', '/');
      final octets = entite.readAsBytesSync();
      archive.addFile(ArchiveFile(cheminRelatif, octets.length, octets));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive) ?? <int>[]);
  }

  /// Extrait [zipBytes] dans [cible], avec la même garde anti
  /// "zip-slip" que `BackupService.restaurerSauvegarde` (rejette toute
  /// entrée dont le chemin résultant sortirait de [cible]).
  static void _extraireZip(Uint8List zipBytes, Directory cible) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final fichier in archive) {
      final cheminSortie = p.normalize(p.join(cible.path, fichier.name));
      if (!p.isWithin(cible.path, cheminSortie)) continue;

      if (fichier.isFile) {
        final contenu = fichier.content;
        final fichierSortie = File(cheminSortie);
        fichierSortie.createSync(recursive: true);
        if (contenu is List<int>) {
          fichierSortie.writeAsBytesSync(contenu);
        }
      } else {
        Directory(cheminSortie).createSync(recursive: true);
      }
    }
  }
}
