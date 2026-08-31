import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../app/theme/app_colors.dart';
import '../../core/permissions/permissions.dart';
import '../../domain/entities/article.dart';
import '../../presentation/articles/providers/article_provider.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'category_quick_create.dart';

/// Dialog de création rapide d'un article sans quitter le document en
/// cours (achat, vente, devis...).
///
/// Cœur du système de "sélection d'article avec création intégrée" :
/// ouverte depuis [ArticleAutocompleteField] quand aucun article ne
/// correspond à la recherche, elle retourne le nouvel [ArticleEntity]
/// (prix d'achat inclus) pour que l'appelant l'ajoute directement à sa
/// ligne en cours, sans aucune ressaisie.
class ArticleQuickCreateDialog extends ConsumerStatefulWidget {
  /// Pré-remplit la désignation avec ce que l'utilisateur avait déjà
  /// tapé dans le champ de recherche.
  final String? nomInitial;

  /// Contexte informatif affiché (ex: magasin de réception de l'achat
  /// en cours). N'est pas un champ de l'article — le stock est
  /// alimenté par le document lui-même (réception d'achat, etc.), pas
  /// par la création de l'article.
  final String? magasinContexte;

  const ArticleQuickCreateDialog({
    super.key,
    this.nomInitial,
    this.magasinContexte,
  });

  /// Ouvre le dialog et retourne l'article créé, ou null si annulé.
  static Future<ArticleEntity?> show(
    BuildContext context, {
    String? nomInitial,
    String? magasinContexte,
  }) {
    return showDialog<ArticleEntity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArticleQuickCreateDialog(
        nomInitial: nomInitial,
        magasinContexte: magasinContexte,
      ),
    );
  }

  @override
  ConsumerState<ArticleQuickCreateDialog> createState() =>
      _ArticleQuickCreateDialogState();
}

class _ArticleQuickCreateDialogState
    extends ConsumerState<ArticleQuickCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nomController = TextEditingController();
  final _prixAchatController = TextEditingController();
  final _prixVenteController = TextEditingController();
  final _stockMinimumController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  int? _categorieId;
  bool _isLoading = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _nomController.text = widget.nomInitial ?? '';
    _genererCode();
  }

  /// Propose un code article automatiquement, sans bloquer le reste du
  /// formulaire pendant que la requête s'exécute.
  Future<void> _genererCode() async {
    final repo = ref.read(articleRepositoryProvider);
    final code = await repo.genererProchainCodeArticle();
    if (!mounted) return;
    setState(() => _codeController.text = code);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nomController.dispose();
    _prixAchatController.dispose();
    _prixVenteController.dispose();
    _stockMinimumController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _creerNouvelleCategorie() async {
    final nouvelId = await creerNouvelleCategorieDialog(context, ref);
    if (nouvelId != null && mounted) setState(() => _categorieId = nouvelId);
  }

  Future<void> _creer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _erreur = null;
    });

    final repo = ref.read(articleRepositoryProvider);
    final utilisateur = ref.read(sessionProvider);
    final peutVoirPrixAchat = Permissions.peutVoirPrixAchat(utilisateur);

    final prixAchat = peutVoirPrixAchat
        ? double.tryParse(_prixAchatController.text) ?? 0
        : 0.0;
    final prixVente = double.tryParse(_prixVenteController.text) ?? 0;
    final stockMinimum = double.tryParse(_stockMinimumController.text) ?? 0;
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    try {
      final id = await repo.createArticle(
        code: _codeController.text.trim(),
        nom: _nomController.text.trim(),
        categorieId: _categorieId,
        prixAchat: prixAchat,
        prixVente: prixVente,
        stockMinimum: stockMinimum,
        description: description,
      );
      final nouvelArticle = await repo.getArticleById(id);
      if (!mounted) return;

      ref.invalidate(articlesListProvider);
      ref.invalidate(filteredArticlesProvider);
      invalidateStockDependentProviders(ref);

      context.pop(nouvelArticle);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _erreur = 'Impossible de créer l\'article : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final utilisateur = ref.watch(sessionProvider);
    final peutVoirPrixAchat = Permissions.peutVoirPrixAchat(utilisateur);

    return AlertDialog(
      title: const Text('Créer un article'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.magasinContexte != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Magasin : ${widget.magasinContexte}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: AppTextField(
                        label: 'Code article',
                        controller: _codeController,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requis'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: 'Désignation',
                        controller: _nomController,
                        hint: 'Ex: Riz parfumé 25kg',
                        autofocus: true,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nom requis'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                categoriesAsync.when(
                  data: (categories) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Catégorie',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _categorieId,
                              decoration: const InputDecoration(
                                  hintText: 'Aucune catégorie'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Aucune catégorie'),
                                ),
                                ...categories.map(
                                    (c) => DropdownMenuItem<int?>(
                                          value: c.id,
                                          child: Text(c.nom),
                                        )),
                              ],
                              onChanged: (v) =>
                                  setState(() => _categorieId = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: _creerNouvelleCategorie,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Nouvelle'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (peutVoirPrixAchat) ...[
                      Expanded(
                        child: AppTextField(
                          label: 'Prix d\'achat (FCFA)',
                          controller: _prixAchatController,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requis'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: AppTextField(
                        label: 'Prix de vente (FCFA)',
                        controller: _prixVenteController,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requis'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Stock minimum (alerte rupture)',
                  controller: _stockMinimumController,
                  keyboardType: TextInputType.number,
                  hint: 'Ex: 10',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Description (optionnelle)',
                  controller: _descriptionController,
                  hint: 'Notes, détails produit...',
                  maxLines: 2,
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(_erreur!,
                      style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => context.pop(),
          child: const Text('Annuler'),
        ),
        AppButton(
          label: 'Créer et utiliser',
          icon: Icons.check_circle_outline,
          isLoading: _isLoading,
          onPressed: _creer,
        ),
      ],
    );
  }
}
