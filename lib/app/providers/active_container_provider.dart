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

class ActiveContainerNotifier extends StateNotifier<OpenedMstkContainer?> {
  final Ref _ref;
  ActiveContainerNotifier(this._ref) : super(null);

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
