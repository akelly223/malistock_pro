import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../container/container_actions.dart';

/// Bouton "Fichier" de la fenêtre principale : Nouveau, Ouvrir,
/// Enregistrer une copie sous, Sauvegarde, Fermer le dossier — les
/// mêmes actions que l'écran d'accueil, disponibles pendant qu'un
/// dossier est déjà ouvert.
class FileMenuButton extends ConsumerWidget {
  const FileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: PopupMenuButton<_FileMenuAction>(
        tooltip: 'Fichier',
        icon: const Icon(Icons.description_outlined, color: AppColors.textSecondary),
        onSelected: (action) => _executer(context, ref, action),
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

  Future<void> _executer(
      BuildContext context, WidgetRef ref, _FileMenuAction action) {
    switch (action) {
      case _FileMenuAction.nouveau:
        return ContainerActions.nouveau(context, ref);
      case _FileMenuAction.ouvrir:
        return ContainerActions.ouvrir(context, ref);
      case _FileMenuAction.sauvegarder:
        return ContainerActions.sauvegarder(context, ref);
      case _FileMenuAction.enregistrerSousCopie:
        return ContainerActions.enregistrerSousCopie(context, ref);
      case _FileMenuAction.fermer:
        return ContainerActions.fermer(context, ref);
    }
  }
}

enum _FileMenuAction { nouveau, ouvrir, sauvegarder, enregistrerSousCopie, fermer }
