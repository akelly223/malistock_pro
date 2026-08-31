import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../articles/providers/article_provider.dart';
import '../stores/providers/store_provider.dart';
import 'providers/inventory_provider.dart';

/// Boîte de dialogue de création d'un nouvel inventaire : choix du
/// magasin (obligatoire) et d'une catégorie (optionnelle, base pour
/// l'inventaire tournant/partiel à venir).
Future<void> showNewInventoryDialog(BuildContext context, WidgetRef ref) {
  int? storeId;
  int? categorieId;
  bool creating = false;

  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        // Consumer dédié : un `ref.watch` doit être appelé depuis un
        // widget qui appartient lui-même à la sous-arborescence du
        // dialogue, sinon Riverpod rattache l'abonnement à l'écran
        // parent (celui qui a ouvert la boîte) et reconstruit CET
        // écran quand les données arrivent — jamais le dialogue, qui
        // reste alors bloqué indéfiniment sur son état de chargement.
        return Consumer(
          builder: (context, dialogRef, _) {
            final storesAsync = dialogRef.watch(storesListProvider);
            final categoriesAsync = dialogRef.watch(categoriesListProvider);

            return AlertDialog(
              title: const Text('Nouvel inventaire'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    storesAsync.when(
                      data: (stores) {
                        if (stores.isEmpty) {
                          return const Text(
                              'Créez d\'abord un magasin pour lancer un inventaire.');
                        }
                        storeId ??= stores.first.id;
                        return DropdownButtonFormField<int>(
                          value: storeId,
                          decoration: const InputDecoration(
                            labelText: 'Magasin *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.store_rounded),
                          ),
                          items: stores
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.nom)))
                              .toList(),
                          onChanged: (v) => setStateDialog(() => storeId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erreur magasins : $e'),
                    ),
                    const SizedBox(height: 16),
                    categoriesAsync.when(
                      data: (categories) => DropdownButtonFormField<int?>(
                        value: categorieId,
                        decoration: const InputDecoration(
                          labelText: 'Catégorie (optionnel)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('Toutes les catégories')),
                          ...categories.map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.nom))),
                        ],
                        onChanged: (v) =>
                            setStateDialog(() => categorieId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Erreur catégories : $e'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Le stock théorique de chaque article sera capturé au '
                      'moment de la création.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                AppButton(
                  label: 'Créer',
                  isLoading: creating,
                  onPressed: storeId == null
                      ? null
                      : () async {
                          setStateDialog(() => creating = true);
                          final user = ref.read(sessionProvider);
                          try {
                            final id = await ref
                                .read(inventoryRepositoryProvider)
                                .creerInventaire(
                                  storeId: storeId!,
                                  categorieId: categorieId,
                                  userId: user?.id ?? 0,
                                );
                            ref.invalidate(inventoriesListProvider);
                            if (context.mounted) {
                              Navigator.pop(context);
                              context.push('/inventory/$id');
                            }
                          } catch (e) {
                            setStateDialog(() => creating = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur : $e')),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    ),
  );
}
