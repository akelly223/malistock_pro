import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/active_container_provider.dart';
import '../../core/container/mstk_exceptions.dart';
import '../../core/container/recent_files_service.dart';
import 'widgets/mot_de_passe_dialog.dart';

/// Actions "Fichier" (Nouveau, Ouvrir, Enregistrer une copie sous,
/// Sauvegarde, Fermer) partagées entre l'écran d'accueil et le menu
/// Fichier de la fenêtre principale, pour ne pas dupliquer deux fois
/// la logique de sélection de fichier et de gestion d'erreurs.
abstract final class ContainerActions {
  static Future<bool> _confirmerFermeturePieceEnCours(
      BuildContext context, WidgetRef ref) async {
    if (ref.read(activeContainerProvider) == null) return true;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fermer le dossier actuel ?'),
        content: const Text(
          'Le dossier actuellement ouvert va être fermé. Pensez à l\'avoir '
          'enregistré si besoin (menu Fichier > Sauvegarde).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Fermer et continuer')),
        ],
      ),
    );
    return confirme == true;
  }

  static void _erreur(BuildContext context, Object e) {
    final message = e is MstkException ? e.message : 'Erreur : $e';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> nouveau(BuildContext context, WidgetRef ref) async {
    if (!await _confirmerFermeturePieceEnCours(context, ref)) return;
    if (!context.mounted) return;

    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: 'Créer un nouveau dossier MaliStock Pro',
      fileName: 'MonEntreprise.mstk',
      allowedExtensions: ['mstk'],
    );
    if (chemin == null || !context.mounted) return;
    final cheminFinal =
        chemin.toLowerCase().endsWith('.mstk') ? chemin : '$chemin.mstk';

    final motDePasse = await demanderMotDePasse(context, creation: true);
    if (motDePasse == null || !context.mounted) return;

    try {
      await ref.read(activeContainerProvider.notifier).creerNouveau(
            File(cheminFinal),
            motDePasse: motDePasse == motDePasseAucun ? null : motDePasse,
          );
      await RecentFilesService.ajouter(cheminFinal);
      if (context.mounted) context.go('/dashboard');
    } catch (e) {
      if (context.mounted) _erreur(context, e);
    }
  }

  static Future<void> ouvrir(
    BuildContext context,
    WidgetRef ref, {
    String? cheminPredefini,
  }) async {
    if (!await _confirmerFermeturePieceEnCours(context, ref)) return;
    if (!context.mounted) return;

    var chemin = cheminPredefini;
    if (chemin == null) {
      final resultat = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mstk'],
        dialogTitle: 'Ouvrir un dossier MaliStock Pro',
      );
      chemin = resultat?.files.single.path;
    }
    if (chemin == null || !context.mounted) return;

    await _ouvrirAvecMotDePasseSiNecessaire(context, ref, chemin);
  }

  static Future<void> _ouvrirAvecMotDePasseSiNecessaire(
    BuildContext context,
    WidgetRef ref,
    String chemin, {
    String? motDePasse,
  }) async {
    try {
      await ref
          .read(activeContainerProvider.notifier)
          .ouvrir(File(chemin), motDePasse: motDePasse);
      await RecentFilesService.ajouter(chemin);
      if (context.mounted) context.go('/dashboard');
    } on MstkAuthentificationException {
      if (!context.mounted) return;
      // Ne demande un mot de passe qu'au moment où le fichier
      // s'avère réellement en exiger un (plutôt que de le demander
      // systématiquement en amont pour tous les fichiers).
      final saisi = await demanderMotDePasse(
        context,
        creation: false,
        erreurPrecedente: motDePasse != null,
      );
      if (saisi == null || !context.mounted) return;
      await _ouvrirAvecMotDePasseSiNecessaire(context, ref, chemin,
          motDePasse: saisi);
    } catch (e) {
      if (context.mounted) _erreur(context, e);
    }
  }

  static Future<void> sauvegarder(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(activeContainerProvider.notifier).sauvegarder();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dossier enregistré.')));
      }
    } catch (e) {
      if (context.mounted) _erreur(context, e);
    }
  }

  static Future<void> enregistrerSousCopie(
      BuildContext context, WidgetRef ref) async {
    if (ref.read(activeContainerProvider) == null) return;

    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer une copie sous',
      fileName: 'Copie.mstk',
      allowedExtensions: ['mstk'],
    );
    if (chemin == null || !context.mounted) return;
    final cheminFinal =
        chemin.toLowerCase().endsWith('.mstk') ? chemin : '$chemin.mstk';

    try {
      await ref
          .read(activeContainerProvider.notifier)
          .enregistrerCopie(File(cheminFinal));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copie enregistrée : $cheminFinal')));
      }
    } catch (e) {
      if (context.mounted) _erreur(context, e);
    }
  }

  static Future<void> fermer(BuildContext context, WidgetRef ref) async {
    if (!await _confirmerFermeturePieceEnCours(context, ref)) return;
    await ref.read(activeContainerProvider.notifier).fermer();
    if (context.mounted) context.go('/accueil');
  }
}
