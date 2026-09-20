import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../container/container_actions.dart';

/// Bouton "Fichier" de la fenêtre principale : Nouveau, Ouvrir,
/// Enregistrer une copie sous, Sauvegarde, Fermer le dossier — les
/// mêmes actions que l'écran d'accueil, disponibles pendant qu'un
/// dossier est déjà ouvert.
class FileMenuButton extends ConsumerStatefulWidget {
  const FileMenuButton({super.key});

  @override
  ConsumerState<FileMenuButton> createState() => _FileMenuButtonState();
}

class _FileMenuButtonState extends ConsumerState<FileMenuButton> {
  // Empêche un second clic (Fermer pendant une Sauvegarde en cours,
  // par ex.) de lancer une deuxième opération sur le même conteneur
  // .mstk pendant qu'une première est déjà en train d'écrire dessus.
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: PopupMenuButton<_FileMenuAction>(
        tooltip: 'Fichier',
        enabled: !_isBusy,
        icon: _isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: Padding(
                  padding: EdgeInsets.all(1),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.description_outlined, color: AppColors.textSecondary),
        onSelected: (action) => _executer(action),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _FileMenuAction.nouveau,
            child: ListTile(
              leading: Icon(Icons.add_circle_outline_rounded),
              title: Text('Nouveau'),
            ),
          ),
          PopupMenuItem(
            value: _FileMenuAction.ouvrir,
            child: ListTile(
              leading: Icon(Icons.folder_open_rounded),
              title: Text('Ouvrir'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _FileMenuAction.sauvegarder,
            child: ListTile(
              leading: Icon(Icons.save_rounded),
              title: Text('Sauvegarde'),
            ),
          ),
          PopupMenuItem(
            value: _FileMenuAction.enregistrerSousCopie,
            child: ListTile(
              leading: Icon(Icons.file_copy_outlined),
              title: Text('Enregistrer une copie sous'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _FileMenuAction.fermer,
            child: ListTile(
              leading: Icon(Icons.close_rounded),
              title: Text('Fermer le dossier'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executer(_FileMenuAction action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      switch (action) {
        case _FileMenuAction.nouveau:
          await ContainerActions.nouveau(context, ref);
        case _FileMenuAction.ouvrir:
          await ContainerActions.ouvrir(context, ref);
        case _FileMenuAction.sauvegarder:
          await ContainerActions.sauvegarder(context, ref);
        case _FileMenuAction.enregistrerSousCopie:
          await ContainerActions.enregistrerSousCopie(context, ref);
        case _FileMenuAction.fermer:
          await ContainerActions.fermer(context, ref);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

enum _FileMenuAction { nouveau, ouvrir, sauvegarder, enregistrerSousCopie, fermer }
