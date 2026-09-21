import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
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

      dossier = await TempWorkspaceService.creerDossier();
      // Déchiffrement (PBKDF2 potentiellement lent en pur Dart, voir
      // MstkCrypto) + extraction du zip sur un isolate séparé, pour ne
      // jamais geler l'UI le temps de l'ouverture.
      await compute(
        _dechiffrerEtExtraireEnArrierePlan,
        _ParametresLecture(octets, motDePasse, dossier.path),
      );

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
    // Zip (I/O + compression synchrones) + chiffrement (PBKDF2
    // potentiellement plusieurs secondes en pur Dart, voir MstkCrypto)
    // sur un isolate séparé, pour ne jamais geler l'UI — en particulier
    // l'auto-sauvegarde en tâche de fond et la fermeture de fenêtre
    // (CloseSaveGuard) qui doivent rester instantanées côté utilisateur.
    final octetsFichier = await compute(
      _construireContainerEnArrierePlan,
      _ParametresEcriture(dossierSource.path, motDePasse),
    );

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

// ─── Fonctions d'isolate séparé (requis par `compute` : uniquement des
// fonctions top-level ou statiques, jamais des closures) ───────────
//
// Le zip (I/O + compression synchrones) et la dérivation de clé PBKDF2
// (potentiellement plusieurs secondes en pur Dart, voir MstkCrypto)
// sont les deux étapes coûteuses d'une ouverture/sauvegarde de
// conteneur `.mstk`. Les exécuter sur l'isolate UI gèlerait
// l'application (menu, boutons, fermeture de fenêtre...) le temps de
// l'opération — d'où leur délégation systématique à un isolate séparé
// via `compute`, qui ne renvoie que le résultat final (des
// `Uint8List`, transférables sans copie profonde coûteuse).

/// Paramètres de [_construireContainerEnArrierePlan] : uniquement des
/// types simples, transférables entre isolates.
class _ParametresEcriture {
  final String dossierSourcePath;
  final String? motDePasse;
  const _ParametresEcriture(this.dossierSourcePath, this.motDePasse);
}

/// Zippe [_ParametresEcriture.dossierSourcePath] et le chiffre :
/// retourne l'en-tête + ciphertext prêts à être écrits tels quels dans
/// le fichier `.mstk`.
Future<Uint8List> _construireContainerEnArrierePlan(
    _ParametresEcriture params) async {
  final zipBytes =
      MstkContainerService._zipperDossier(Directory(params.dossierSourcePath));
  final chiffre =
      await MstkCrypto.chiffrer(zipBytes, motDePasse: params.motDePasse);

  final header = MstkHeader(
    version: MstkHeader.currentVersion,
    motDePasseRequis:
        params.motDePasse != null && params.motDePasse!.isNotEmpty,
    kdfId: chiffre.kdfId,
    kdfIterations: chiffre.kdfIterations,
    sel: chiffre.sel,
    nonce: chiffre.nonce,
    taillePayload: zipBytes.length,
    tagAuthentification: chiffre.tagAuthentification,
  );

  return Uint8List(MstkHeader.headerLength + chiffre.ciphertext.length)
    ..setRange(0, MstkHeader.headerLength, header.encode())
    ..setRange(MstkHeader.headerLength,
        MstkHeader.headerLength + chiffre.ciphertext.length,
        chiffre.ciphertext);
}

/// Paramètres de [_dechiffrerEtExtraireEnArrierePlan].
class _ParametresLecture {
  final Uint8List octetsFichier;
  final String? motDePasse;
  final String dossierDestinationPath;
  const _ParametresLecture(
      this.octetsFichier, this.motDePasse, this.dossierDestinationPath);
}

/// Déchiffre [_ParametresLecture.octetsFichier] et extrait le zip
/// obtenu dans [_ParametresLecture.dossierDestinationPath]. Laisse
/// remonter [MstkCorrompuException]/[MstkAuthentificationException]/
/// [MstkVersionFutureException] telles quelles : ce sont de simples
/// porteuses de données (message + éventuels champs primitifs), donc
/// transférables entre isolates sans adaptation.
Future<void> _dechiffrerEtExtraireEnArrierePlan(
    _ParametresLecture params) async {
  final header = MstkHeader.decode(params.octetsFichier);
  final ciphertext = params.octetsFichier.sublist(MstkHeader.headerLength);
  final zipBytes = await MstkCrypto.dechiffrer(
    header: header,
    ciphertext: ciphertext,
    motDePasse: params.motDePasse,
  );
  MstkContainerService._extraireZip(
      zipBytes, Directory(params.dossierDestinationPath));
}
