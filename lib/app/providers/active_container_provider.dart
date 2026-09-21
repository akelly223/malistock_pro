import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/container/active_container_context.dart';
import '../../core/container/mstk_container_service.dart';
import 'repository_providers.dart';
import 'session_provider.dart';

/// État du conteneur `.mstk` actuellement ouvert : `null` tant
/// qu'aucun dossier n'est ouvert (l'écran d'accueil doit s'afficher).
final activeContainerProvider =
    StateNotifierProvider<ActiveContainerNotifier, OpenedMstkContainer?>(
        (ref) => ActiveContainerNotifier(ref));

/// Délai d'inactivité après la dernière écriture avant de déclencher
/// l'auto-sauvegarde (voir [ActiveContainerNotifier._demarrerAutosave]).
/// Assez court pour qu'une fermeture (bouton X) tombe presque toujours
/// après une sauvegarde déjà à jour, assez long pour ne pas rechiffrer
/// le conteneur entier à chaque ligne d'un import de plusieurs
/// centaines d'articles.
const _delaiAutosave = Duration(seconds: 2);

class ActiveContainerNotifier extends StateNotifier<OpenedMstkContainer?> {
  final Ref _ref;
  ActiveContainerNotifier(this._ref) : super(null);

  StreamSubscription<void>? _ecouteModifications;
  Timer? _minuteurAutosave;
  bool _sauvegardeEnCours = false;
  bool _autreSauvegardeDemandee = false;

  /// Ferme le conteneur actuellement ouvert, s'il y en a un : ferme
  /// explicitement la connexion `AppDatabase` AVANT toute manipulation
  /// de fichiers (verrous Windows — même raisonnement que
  /// `BackupService`), puis invalide le provider pour qu'une nouvelle
  /// instance soit reconstruite au prochain accès.
  ///
  /// Réinitialise aussi la session utilisateur : l'utilisateur connecté
  /// appartient à la base du fichier qu'on ferme, il n'a aucun sens
  /// dans un autre fichier (ou aucun fichier) une fois celui-ci fermé.
  Future<void> fermer() async {
    final container = state;
    if (container == null) return;

    _arreterAutosave();
    await _ref.read(databaseProvider).close();
    // ActiveContainerContext ET state DOIVENT être vidés AVANT
    // d'invalider databaseProvider : si un écran l'observe encore à cet
    // instant, l'invalidation le reconstruit immédiatement (pas
    // paresseusement), et il ne doit jamais pouvoir repointer sur le
    // dossier de travail de [container] pendant que la ligne suivante
    // s'apprête à le supprimer.
    ActiveContainerContext.definir(null);
    state = null;
    _ref.invalidate(databaseProvider);

    await MstkContainerService.fermer(container);
    _ref.read(sessionProvider.notifier).logout();
  }

  Future<void> ouvrir(File fichier, {String? motDePasse}) async {
    await fermer();
    final container =
        await MstkContainerService.ouvrir(fichier, motDePasse: motDePasse);
    _activer(container);
  }

  Future<void> creerNouveau(File fichier, {String? motDePasse}) async {
    await fermer();
    final container = await MstkContainerService.creerNouveau(fichier,
        motDePasse: motDePasse);
    _activer(container);
  }

  void _activer(OpenedMstkContainer container) {
    ActiveContainerContext.definir(container.dossierTravail.path);
    state = container;
    // Au cas où databaseProvider aurait déjà été lu avant l'ouverture
    // (ne devrait pas arriver avec la garde du routeur, mais sans
    // risque de le faire par sécurité).
    _ref.invalidate(databaseProvider);
    _demarrerAutosave();
  }

  /// Écoute chaque écriture validée sur `AppDatabase` (`tableUpdates()`,
  /// mécanisme natif de Drift utilisé aussi par les requêtes `.watch()`)
  /// et programme une auto-sauvegarde après [_delaiAutosave] d'accalmie.
  /// Redémarré depuis zéro à chaque nouvelle écriture : un import de
  /// nombreux articles ne déclenche qu'UNE sauvegarde, juste après la
  /// dernière ligne, jamais une par ligne.
  void _demarrerAutosave() {
    _ecouteModifications?.cancel();
    _ecouteModifications =
        _ref.read(databaseProvider).tableUpdates().listen((_) {
      _minuteurAutosave?.cancel();
      _minuteurAutosave = Timer(_delaiAutosave, _declencherAutosave);
    });
  }

  void _arreterAutosave() {
    _ecouteModifications?.cancel();
    _ecouteModifications = null;
    _minuteurAutosave?.cancel();
    _minuteurAutosave = null;
    _autreSauvegardeDemandee = false;
  }

  Future<void> _declencherAutosave() async {
    if (_sauvegardeEnCours) {
      // Une sauvegarde (auto ou manuelle) est déjà en cours : on
      // redemandera une auto-sauvegarde juste après, plutôt que de
      // lancer deux réécritures concurrentes du même fichier.
      _autreSauvegardeDemandee = true;
      return;
    }
    _sauvegardeEnCours = true;
    try {
      await sauvegarder();
    } catch (_) {
      // Best-effort et silencieux : une auto-sauvegarde en tâche de
      // fond ne doit jamais interrompre l'utilisateur. La sauvegarde
      // manuelle (menu Fichier) et la fermeture de fenêtre
      // (`CloseSaveGuard`) resignalent l'erreur explicitement si elle
      // persiste.
    } finally {
      _sauvegardeEnCours = false;
      if (_autreSauvegardeDemandee) {
        _autreSauvegardeDemandee = false;
        _minuteurAutosave = Timer(_delaiAutosave, _declencherAutosave);
      }
    }
  }

  /// Enregistre le conteneur ouvert sur disque (rechiffrement),
  /// après avoir vidé le WAL SQLite pour que le fichier sur disque
  /// reflète bien toutes les écritures validées.
  Future<void> sauvegarder({String? nouveauMotDePasse}) async {
    final container = state;
    if (container == null) return;
    await _ref.read(databaseProvider).customStatement('PRAGMA wal_checkpoint(FULL)');
    await MstkContainerService.sauvegarder(container,
        nouveauMotDePasse: nouveauMotDePasse);
  }

  /// Sauvegarde finale appelée par `CloseSaveGuard` juste avant de
  /// fermer réellement la fenêtre. Annule le minuteur d'auto-sauvegarde
  /// (devenu inutile) et attend qu'une auto-sauvegarde déjà en vol se
  /// termine avant d'en lancer une autre, pour ne jamais avoir deux
  /// réécritures concurrentes du même fichier `.mstk`.
  Future<void> sauvegarderPourFermeture() async {
    _minuteurAutosave?.cancel();
    _minuteurAutosave = null;
    while (_sauvegardeEnCours) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await sauvegarder();
  }

  /// Enregistre une copie du conteneur ouvert à un autre emplacement,
  /// sans modifier le fichier ouvert ni son verrou.
  Future<void> enregistrerCopie(File nouveauFichier,
      {String? motDePasse}) async {
    final container = state;
    if (container == null) return;
    await _ref.read(databaseProvider).customStatement('PRAGMA wal_checkpoint(FULL)');
    await MstkContainerService.enregistrerSousCopie(
        container, nouveauFichier,
        motDePasse: motDePasse);
  }
}
