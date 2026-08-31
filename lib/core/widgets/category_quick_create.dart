import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/repository_providers.dart';
import '../../presentation/articles/providers/article_provider.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// Ouvre une popup de saisie pour créer une nouvelle catégorie (ex:
/// Roman, Développement personnel, Livres pour enfants) sans quitter
/// l'écran en cours. Retourne l'id de la catégorie créée, ou null si
/// l'utilisateur a annulé.
///
/// Partagé entre le formulaire article complet et la création rapide
/// d'article intégrée aux documents (achats, ventes, devis...).
Future<int?> creerNouvelleCategorieDialog(
    BuildContext context, WidgetRef ref) async {
  final nomController = TextEditingController();

  final nomSaisi = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nouvelle catégorie'),
      content: AppTextField(
        label: 'Nom de la catégorie',
        controller: nomController,
        hint: 'Ex: Roman, Développement personnel...',
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Annuler'),
        ),
        AppButton(
          label: 'Créer',
          onPressed: () => context.pop(nomController.text.trim()),
        ),
      ],
    ),
  );

  if (nomSaisi == null || nomSaisi.isEmpty) return null;

  final repo = ref.read(articleRepositoryProvider);
  final nouvelId = await repo.createCategory(nomSaisi);
  ref.invalidate(categoriesListProvider);
  return nouvelId;
}
