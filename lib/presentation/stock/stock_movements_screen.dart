import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/article_autocomplete_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/db_constants.dart';
import '../../core/services/stock_entry_receipt_pdf_service.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/stock_movement.dart';
import '../settings/providers/settings_provider.dart';
import '../stores/providers/store_provider.dart';

final stockMovementsProvider =
    FutureProvider.autoDispose<List<StockMovementEntity>>((ref) async {
  final repo = ref.watch(stockRepositoryProvider);
  return repo.getAllMovements();
});

class StockMovementsScreen extends ConsumerWidget {
  const StockMovementsScreen({super.key});

  Future<void> _afficherTransfertDialog(
      BuildContext context, WidgetRef ref) async {
    ArticleEntity? articleChoisi;
    int? storeFromId;
    int? storeToId;
    final quantiteController = TextEditingController();

    final stores = await ref.read(storeRepositoryProvider).getAllStores();
    if (stores.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Créez au moins deux magasins pour transférer du stock.')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Transfert de stock'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ArticleAutocompleteField(
                  label: 'Article',
                  onSearch: (q) =>
                      ref.read(articleRepositoryProvider).searchArticles(q),
                  onSelected: (a) => setStateDialog(() => articleChoisi = a),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration:
                      const InputDecoration(labelText: 'Magasin source'),
                  items: stores
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.nom)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => storeFromId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration:
                      const InputDecoration(labelText: 'Magasin destination'),
                  items: stores
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.nom)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => storeToId = v),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Quantité',
                  controller: quantiteController,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            AppButton(
              label: 'Transférer',
              onPressed: () async {
                final quantite = double.tryParse(quantiteController.text) ?? 0;
                if (articleChoisi == null ||
                    storeFromId == null ||
                    storeToId == null ||
                    quantite <= 0 ||
                    storeFromId == storeToId) {
                  return;
                }
                final user = ref.read(sessionProvider);
                try {
                  await ref.read(stockRepositoryProvider).transferStock(
                        articleId: articleChoisi!.id,
                        storeFromId: storeFromId!,
                        storeToId: storeToId!,
                        quantite: quantite,
                        userId: user?.id ?? 0,
                      );
                  ref.invalidate(stockMovementsProvider);
                  invalidateStockDependentProviders(ref);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Entrée/sortie/perte/casse manuelle, sans passer par un achat ni
  /// une vente — utile notamment pour réceptionner plusieurs livres en
  /// dépôt-vente d'un coup (aucune dette ne doit être créée à la
  /// réception) ou pour reprendre des invendus non encore vendus (la
  /// dette éventuelle n'existant que sur les exemplaires déjà vendus,
  /// une simple sortie de stock suffit). Contrairement à un champ
  /// article unique, chaque
  /// sélection dans l'autocomplétion AJOUTE une ligne à une liste :
  /// sans ça, sélectionner un article videait juste le champ sans
  /// aucun retour visuel, donnant l'impression que le clic ne
  /// faisait rien.
  Future<void> _afficherMouvementManuelDialog(
      BuildContext context, WidgetRef ref) async {
    int? storeId;
    var type = DbConstants.movementEntree;
    var imprimerRecu = true;
    final referenceController = TextEditingController();
    final lignes = <_LigneMouvementManuel>[];

    final stores = await ref.read(storeRepositoryProvider).getAllStores();
    if (stores.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Créez d\'abord un magasin.')),
        );
      }
      return;
    }
    storeId = stores.first.id;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Mouvement de stock manuel'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ArticleAutocompleteField(
                  label: 'Ajouter un article',
                  onSearch: (q) =>
                      ref.read(articleRepositoryProvider).searchArticles(q),
                  onSelected: (a) => setStateDialog(() {
                    final existante =
                        lignes.where((l) => l.article.id == a.id).firstOrNull;
                    if (existante != null) {
                      final actuelle =
                          double.tryParse(existante.quantiteController.text) ??
                              0;
                      existante.quantiteController.text =
                          (actuelle + 1).toStringAsFixed(0);
                    } else {
                      lignes.insert(0, _LigneMouvementManuel(article: a));
                    }
                  }),
                ),
                const SizedBox(height: 12),
                if (lignes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Aucun article ajouté pour le moment.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: lignes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final ligne = lignes[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(ligne.article.nom,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: ligne.quantiteController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                      isDense: true, labelText: 'Qté'),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    setStateDialog(() => lignes.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: storeId,
                  decoration: const InputDecoration(labelText: 'Magasin'),
                  items: stores
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.nom)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => storeId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                        value: DbConstants.movementEntree,
                        child: Text('Entrée (réception, dépôt-vente...)')),
                    DropdownMenuItem(
                        value: DbConstants.movementSortie,
                        child: Text(
                            'Sortie (retour au fournisseur/auteur, don...)')),
                    DropdownMenuItem(
                        value: DbConstants.movementPerte,
                        child: Text('Perte')),
                    DropdownMenuItem(
                        value: DbConstants.movementCasse,
                        child: Text('Casse')),
                  ],
                  onChanged: (v) => setStateDialog(() => type = v!),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Référence (optionnel)',
                  controller: referenceController,
                  hint: 'Ex: nom de l\'auteur',
                ),
                if (type == DbConstants.movementEntree ||
                    type == DbConstants.movementSortie)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(type == DbConstants.movementEntree
                        ? 'Imprimer un reçu de réception (à remettre à l\'auteur/fournisseur)'
                        : 'Imprimer un bon de sortie (à remettre à l\'auteur/fournisseur)'),
                    value: imprimerRecu,
                    onChanged: (v) =>
                        setStateDialog(() => imprimerRecu = v ?? false),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            AppButton(
              label: 'Enregistrer',
              onPressed: () async {
                if (lignes.isEmpty || storeId == null) return;
                final quantites = lignes
                    .map((l) => double.tryParse(l.quantiteController.text) ?? 0)
                    .toList();
                if (quantites.any((q) => q <= 0)) return;

                final user = ref.read(sessionProvider);
                final reference = referenceController.text.trim().isEmpty
                    ? null
                    : referenceController.text.trim();
                final storeNom = stores.firstWhere((s) => s.id == storeId).nom;
                final groupeId = const Uuid().v4();
                try {
                  for (var i = 0; i < lignes.length; i++) {
                    await ref.read(stockRepositoryProvider).registerMovement(
                          articleId: lignes[i].article.id,
                          storeId: storeId!,
                          typeMouvement: type,
                          quantite: quantites[i],
                          reference: reference,
                          userId: user?.id ?? 0,
                          groupeId: groupeId,
                        );
                  }
                  ref.invalidate(stockMovementsProvider);
                  invalidateStockDependentProviders(ref);
                  if (context.mounted) Navigator.pop(context);

                  final estEntreeOuSortie = type == DbConstants.movementEntree ||
                      type == DbConstants.movementSortie;
                  if (estEntreeOuSortie && imprimerRecu) {
                    final settings = await ref.read(appSettingsProvider.future);
                    await StockEntryReceiptPdfService.print(
                      lignes: [
                        for (var i = 0; i < lignes.length; i++)
                          (
                            code: lignes[i].article.code,
                            nom: lignes[i].article.nom,
                            quantite: quantites[i],
                          ),
                      ],
                      storeNom: storeNom,
                      reference: reference,
                      date: DateTime.now(),
                      settings: settings,
                      estSortie: type == DbConstants.movementSortie,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _couleurType(String type) {
    switch (type) {
      case DbConstants.movementEntree:
        return AppColors.success;
      case DbConstants.movementSortie:
        return AppColors.danger;
      case DbConstants.movementTransfert:
        return AppColors.secondary;
      case DbConstants.movementInventaire:
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  String _labelType(String type) {
    switch (type) {
      case DbConstants.movementEntree:
        return 'Entrée';
      case DbConstants.movementSortie:
        return 'Sortie';
      case DbConstants.movementTransfert:
        return 'Transfert';
      case DbConstants.movementPerte:
        return 'Perte';
      case DbConstants.movementCasse:
        return 'Casse';
      case DbConstants.movementInventaire:
        return 'Inventaire';
      default:
        return type;
    }
  }

  /// Un ajustement d'inventaire porte le signe de l'écart directement
  /// dans `quantite` (peut être positif ou négatif), contrairement aux
  /// autres types où le signe est déduit de `typeMouvement` et la
  /// quantité est toujours positive.
  String _libelleQuantite(StockMovementEntity m) {
    if (m.typeMouvement == DbConstants.movementInventaire) {
      final signe = m.quantite > 0 ? '+' : '';
      return '$signe${m.quantite.toStringAsFixed(0)}';
    }
    final signe = m.typeMouvement == DbConstants.movementEntree ? '+' : '-';
    return '$signe${m.quantite.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouvements de stock'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Mouvement manuel'),
              onPressed: () => _afficherMouvementManuelDialog(context, ref),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Transférer du stock',
              icon: Icons.swap_horiz_rounded,
              onPressed: () => _afficherTransfertDialog(context, ref),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: movementsAsync.when(
          data: (movements) {
            if (movements.isEmpty) {
              return const EmptyState(
                icon: Icons.swap_horiz_rounded,
                message: 'Aucun mouvement de stock enregistré.',
              );
            }
            final items = _agencerAffichage(movements);
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return item.groupe != null
                    ? _carteMouvementGroupe(context, ref, item.groupe!)
                    : _carteMouvementSimple(item.simple!);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }

  /// Regroupe les mouvements partageant un même [groupeId] (un même
  /// lot saisi en une fois depuis "Mouvement manuel") pour les
  /// afficher comme une seule entrée d'historique au lieu d'une ligne
  /// par article — sinon un lot de 10 livres produirait 10 lignes
  /// identiques dans la liste, illisible et sans lien entre elles.
  List<_MouvementAffichage> _agencerAffichage(
      List<StockMovementEntity> movements) {
    final groupesVus = <String>{};
    final items = <_MouvementAffichage>[];
    for (final m in movements) {
      final g = m.groupeId;
      if (g == null) {
        items.add(_MouvementAffichage.simple(m));
      } else if (groupesVus.add(g)) {
        items.add(_MouvementAffichage.groupe(
            movements.where((x) => x.groupeId == g).toList()));
      }
    }
    return items;
  }

  Widget _carteMouvementSimple(StockMovementEntity m) {
    final couleur = _couleurType(m.typeMouvement);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _labelType(m.typeMouvement),
              style: TextStyle(color: couleur, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.articleNom, style: AppTextStyles.bodyBold),
                Text(
                  '${m.storeNom} · ${DateFormatter.formatDateTime(m.dateMouvement)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            _libelleQuantite(m),
            style: AppTextStyles.bodyBold.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }

  Widget _carteMouvementGroupe(
      BuildContext context, WidgetRef ref, List<StockMovementEntity> lignes) {
    final premiere = lignes.first;
    final couleur = _couleurType(premiere.typeMouvement);
    final totalQuantite = lignes.fold<double>(0, (s, m) => s + m.quantite);
    final signe =
        premiere.typeMouvement == DbConstants.movementEntree ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: couleur.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _labelType(premiere.typeMouvement),
                  style:
                      TextStyle(color: couleur, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lignes.length} article${lignes.length > 1 ? 's' : ''}'
                      '${premiere.reference != null && premiere.reference!.isNotEmpty ? ' · ${premiere.reference}' : ''}',
                      style: AppTextStyles.bodyBold,
                    ),
                    Text(
                      '${premiere.storeNom} · ${DateFormatter.formatDateTime(premiere.dateMouvement)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '$signe${totalQuantite.toStringAsFixed(0)}',
                style: AppTextStyles.bodyBold.copyWith(color: couleur),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lignes.map((m) => Padding(
                padding: const EdgeInsets.only(left: 46, top: 2, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                        child:
                            Text(m.articleNom, style: AppTextStyles.caption)),
                    Text(m.quantite.toStringAsFixed(0),
                        style: AppTextStyles.caption),
                  ],
                ),
              )),
          if (premiere.typeMouvement == DbConstants.movementEntree ||
              premiere.typeMouvement == DbConstants.movementSortie) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(
                    premiere.typeMouvement == DbConstants.movementEntree
                        ? 'Réimprimer le reçu'
                        : 'Réimprimer le bon de sortie'),
                onPressed: () => _reimprimerRecu(context, ref, lignes),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Régénère le reçu à partir des mouvements déjà enregistrés — pour
  /// le cas où l'impression a été oubliée ou fermée par erreur lors
  /// de la saisie initiale.
  Future<void> _reimprimerRecu(BuildContext context, WidgetRef ref,
      List<StockMovementEntity> lignes) async {
    try {
      final settings = await ref.read(appSettingsProvider.future);
      final premiere = lignes.first;
      await StockEntryReceiptPdfService.print(
        lignes: [
          for (final m in lignes)
            (code: m.articleCode, nom: m.articleNom, quantite: m.quantite),
        ],
        storeNom: premiere.storeNom,
        reference: premiere.reference,
        date: premiere.dateMouvement,
        settings: settings,
        estSortie: premiere.typeMouvement == DbConstants.movementSortie,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }
}

/// Élément affichable dans l'historique des mouvements : soit un
/// mouvement isolé (vente, transfert, ajustement...), soit un lot de
/// mouvements partageant un [StockMovementEntity.groupeId] (saisie
/// manuelle groupée).
class _MouvementAffichage {
  final StockMovementEntity? simple;
  final List<StockMovementEntity>? groupe;

  _MouvementAffichage.simple(StockMovementEntity m)
      : simple = m,
        groupe = null;

  _MouvementAffichage.groupe(List<StockMovementEntity> lignes)
      : simple = null,
        groupe = lignes;
}

/// Une ligne du dialogue "Mouvement de stock manuel" : un article
/// avec sa propre quantité, pour permettre d'en saisir plusieurs
/// d'un coup (ex : réception d'un lot de livres en dépôt-vente).
class _LigneMouvementManuel {
  final ArticleEntity article;
  final TextEditingController quantiteController;

  _LigneMouvementManuel({required this.article})
      : quantiteController = TextEditingController(text: '1');
}
