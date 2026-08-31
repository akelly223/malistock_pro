import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/inventory.dart';
import 'inventory_new_dialog.dart';
import 'providers/inventory_provider.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventairesAsync = ref.watch(inventoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvel inventaire',
              icon: Icons.playlist_add_check_rounded,
              onPressed: () => showNewInventoryDialog(context, ref),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: inventairesAsync.when(
          data: (inventaires) {
            if (inventaires.isEmpty) {
              return EmptyState(
                icon: Icons.playlist_add_check_rounded,
                message:
                    'Aucun inventaire pour le moment.\nCréez un inventaire pour compter votre stock physique.',
                action: AppButton(
                  label: 'Nouvel inventaire',
                  icon: Icons.add_rounded,
                  onPressed: () => showNewInventoryDialog(context, ref),
                ),
              );
            }
            return ListView.separated(
              itemCount: inventaires.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CarteInventaire(
                inventaire: inventaires[i],
                onTap: () => context.push('/inventory/${inventaires[i].id}'),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
        ),
      ),
    );
  }
}

class _CarteInventaire extends StatelessWidget {
  final InventoryEntity inventaire;
  final VoidCallback onTap;

  const _CarteInventaire({required this.inventaire, required this.onTap});

  (Color, String) _styleStatut() {
    switch (inventaire.statut) {
      case 'valide':
        return (AppColors.success, 'Validé');
      case 'annule':
        return (AppColors.textSecondary, 'Annulé');
      default:
        return (AppColors.warning, 'Brouillon');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (couleur, libelle) = _styleStatut();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: couleur.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(libelle,
                    style: TextStyle(color: couleur, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inventaire.numero, style: AppTextStyles.bodyBold),
                    Text(
                      '${inventaire.storeNom}'
                      '${inventaire.categorieNom != null ? ' · ${inventaire.categorieNom}' : ''}'
                      ' · ${DateFormatter.formatDateTime(inventaire.dateCreation)}'
                      '${inventaire.createdByNom != null ? ' · ${inventaire.createdByNom}' : ''}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${inventaire.nbArticles} articles',
                      style: AppTextStyles.bodyBold),
                  if (inventaire.nbAvecEcart > 0)
                    Text('${inventaire.nbAvecEcart} écart(s)',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning)),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
