import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/store.dart';
import 'providers/store_provider.dart';

class StoresListScreen extends ConsumerWidget {
  const StoresListScreen({super.key});

  Future<void> _afficherFormulaire(
      BuildContext context, WidgetRef ref, StoreEntity? existant) async {
    final nomController = TextEditingController(text: existant?.nom);
    final adresseController = TextEditingController(text: existant?.adresse);
    bool estPrincipal = existant?.estPrincipal ?? false;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title:
              Text(existant == null ? 'Nouveau magasin' : 'Modifier le magasin'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                    label: 'Nom (ex: Dépôt principal)',
                    controller: nomController),
                const SizedBox(height: 12),
                AppTextField(label: 'Adresse', controller: adresseController),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Magasin principal'),
                  value: estPrincipal,
                  onChanged: (v) => setStateDialog(() => estPrincipal = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Annuler')),
            AppButton(
                label: 'Enregistrer', onPressed: () => context.pop(true)),
          ],
        ),
      ),
    );

    if (confirme == true && nomController.text.trim().isNotEmpty) {
      final repo = ref.read(storeRepositoryProvider);
      if (existant == null) {
        await repo.createStore(
          nom: nomController.text.trim(),
          adresse: adresseController.text.trim().isEmpty
              ? null
              : adresseController.text.trim(),
          estPrincipal: estPrincipal,
        );
      } else {
        await repo.updateStore(StoreEntity(
          id: existant.id,
          nom: nomController.text.trim(),
          adresse: adresseController.text.trim(),
          estPrincipal: estPrincipal,
          dateCreation: existant.dateCreation,
        ));
      }
      ref.invalidate(storesListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Magasins'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouveau magasin',
              icon: Icons.add_rounded,
              onPressed: () => _afficherFormulaire(context, ref, null),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: storesAsync.when(
          data: (stores) {
            if (stores.isEmpty) {
              return EmptyState(
                icon: Icons.store_outlined,
                message: 'Aucun magasin créé.\nCréez votre dépôt principal pour commencer.',
                action: AppButton(
                  label: 'Créer un magasin',
                  onPressed: () => _afficherFormulaire(context, ref, null),
                ),
              );
            }
            return ListView.separated(
              itemCount: stores.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final store = stores[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.store_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(store.nom, style: AppTextStyles.bodyBold),
                                if (store.estPrincipal) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Principal',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.secondary)),
                                  ),
                                ],
                              ],
                            ),
                            if (store.adresse != null)
                              Text(store.adresse!, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _afficherFormulaire(context, ref, store),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}
