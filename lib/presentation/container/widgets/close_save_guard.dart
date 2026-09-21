import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/providers/active_container_provider.dart';
import '../../../app/router/app_router.dart';
import '../../../core/container/mstk_exceptions.dart';

/// Empêche la fermeture "sèche" de la fenêtre (bouton X / Alt+F4).
///
/// `windows/runner/win32_window.cpp` configure `SetQuitOnClose(true)` :
/// sans ce garde-fou, cliquer sur la croix tue le processus
/// immédiatement (WM_DESTROY → PostQuitMessage), sans jamais
/// rechiffrer/réécrire le conteneur `.mstk` ouvert sur disque — toute
/// la session en cours (admin créé, articles importés, ventes
/// saisies...) n'a jamais existé que dans le dossier de travail
/// temporaire et disparaît avec lui.
///
/// `ActiveContainerNotifier` sauvegarde déjà automatiquement quelques
/// secondes après chaque modification (voir `_demarrerAutosave` dans
/// active_container_provider.dart) : à ce stade, il ne reste presque
/// jamais rien à écrire. Ce widget reste néanmoins le filet de
/// sécurité qui couvre la fenêtre de quelques secondes entre la
/// dernière modification et l'auto-sauvegarde suivante.
///
/// Même "presque rien à écrire", chaque sauvegarde redérive la clé de
/// chiffrement via PBKDF2 à 210 000 itérations (volontairement lent,
/// voir `MstkCrypto`) : attendre cette sauvegarde AVANT de faire
/// disparaître la fenêtre donnerait l'impression d'une appli qui rame
/// à la fermeture. Ce widget cache donc la fenêtre immédiatement (perçu
/// comme une fermeture instantanée), termine la sauvegarde en arrière-
/// plan pendant que la fenêtre est invisible, puis ferme réellement le
/// processus. En cas d'échec de la sauvegarde, la fenêtre est
/// réaffichée et l'utilisateur choisit en connaissance de cause plutôt
/// que de perdre ses données en silence — seul ce cas rare (disque
/// plein, permissions...) est perceptible.
class CloseSaveGuard extends ConsumerStatefulWidget {
  final Widget child;
  const CloseSaveGuard({super.key, required this.child});

  @override
  ConsumerState<CloseSaveGuard> createState() => _CloseSaveGuardState();
}

class _CloseSaveGuardState extends ConsumerState<CloseSaveGuard>
    with WindowListener {
  bool _fermetureEnCours = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Un second WM_CLOSE peut arriver pendant qu'on traite déjà le
    // premier (ex : l'utilisateur reclique sur la croix pendant la
    // sauvegarde) : on l'ignore plutôt que de dupliquer la logique.
    if (_fermetureEnCours) return;

    final container = ref.read(activeContainerProvider);
    if (container == null) {
      // Aucun dossier ouvert (écran d'accueil) : rien à sauvegarder.
      await windowManager.destroy();
      return;
    }

    _fermetureEnCours = true;
    // Fermeture perçue comme instantanée : la fenêtre disparaît tout
    // de suite, la sauvegarde (souvent déjà à jour grâce à l'auto-
    // sauvegarde, mais jamais gratuite à cause du PBKDF2) se termine
    // pendant que le processus tourne encore, invisible.
    await windowManager.hide();

    try {
      await ref.read(activeContainerProvider.notifier).sauvegarderPourFermeture();
      await windowManager.destroy();
    } catch (e) {
      _fermetureEnCours = false;
      await windowManager.show();
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        // Aucune UI disponible pour prévenir : fermer quand même plutôt
        // que de bloquer l'application indéfiniment sans explication.
        await windowManager.destroy();
        return;
      }

      final message = e is MstkException ? e.message : 'Erreur : $e';
      final quitterQuandMeme = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Échec de la sauvegarde'),
          content: Text(
            'Impossible d\'enregistrer le dossier avant de fermer.\n\n'
            '$message\n\n'
            'Quitter maintenant effacera les modifications non '
            'enregistrées de cette session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler (rester ouvert)'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Quitter sans enregistrer'),
            ),
          ],
        ),
      );
      if (quitterQuandMeme == true) {
        await windowManager.destroy();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
