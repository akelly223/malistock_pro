import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/category_quick_create.dart';
import '../../domain/entities/article.dart';
import '../../domain/repositories/article_repository.dart';
import 'providers/article_provider.dart';

class ArticleFormScreen extends ConsumerStatefulWidget {
  final int? articleId;

  const ArticleFormScreen({super.key, this.articleId});

  @override
  ConsumerState<ArticleFormScreen> createState() => _ArticleFormScreenState();
}

class _ArticleFormScreenState extends ConsumerState<ArticleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nomController = TextEditingController();
  final _prixAchatController = TextEditingController();
  final _prixVenteController = TextEditingController();
  final _stockMinimumController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categorieId;
  bool _isLoading = false;
  bool _isInitialised = false;
  ArticleEntity? _articleExistant;

  bool get _estEdition => widget.articleId != null;

  /// Crée une nouvelle catégorie via la popup partagée et la
  /// sélectionne automatiquement pour l'article en cours.
  Future<void> _creerNouvelleCategorie() async {
    final nouvelId = await creerNouvelleCategorieDialog(context, ref);
    if (nouvelId != null) setState(() => _categorieId = nouvelId);
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

  Future<void> _chargerArticleExistant() async {
    if (widget.articleId == null || _isInitialised) return;
    final repo = ref.read(articleRepositoryProvider);
    final article = await repo.getArticleById(widget.articleId!);
    if (article != null) {
      setState(() {
        _articleExistant = article;
        _codeController.text = article.code;
        _nomController.text = article.nom;
        _prixAchatController.text = article.prixAchat.toStringAsFixed(0);
        _prixVenteController.text = article.prixVente.toStringAsFixed(0);
        _stockMinimumController.text = article.stockMinimum.toStringAsFixed(0);
        _descriptionController.text = article.description ?? '';
        _categorieId = article.categorieId;
        _isInitialised = true;
      });
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    final utilisateur = ref.read(sessionProvider);
    if (_estEdition && !Permissions.peutGererCatalogueArticles(utilisateur)) {
      // Garde-fou réel : même si le bouton Enregistrer est caché en
      // mode lecture seule, on ne fait jamais confiance uniquement à
      // l'UI pour bloquer une action sensible.
      return;
    }

    setState(() => _isLoading = true);

    final repo = ref.read(articleRepositoryProvider);
    final peutVoirPrixAchat = Permissions.peutVoirPrixAchat(utilisateur);

    // Le prix d'achat est entièrement invisible pour un employé, y
    // compris à la création : on conserve la valeur déjà existante
    // en édition, ou 0 par défaut en création (à renseigner plus
    // tard par un administrateur). Garde-fou réel indépendant de
    // l'état de l'UI, jamais lu depuis un champ qui n'existe même
    // pas à l'écran pour ce rôle.
    final prixAchat = peutVoirPrixAchat
        ? double.tryParse(_prixAchatController.text) ?? 0
        : (_articleExistant?.prixAchat ?? 0);
    final prixVente = double.tryParse(_prixVenteController.text) ?? 0;
    final stockMinimum = double.tryParse(_stockMinimumController.text) ?? 0;
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    try {
      if (_estEdition && _articleExistant != null) {
        await repo.updateArticle(ArticleEntity(
          id: _articleExistant!.id,
          code: _codeController.text.trim(),
          nom: _nomController.text.trim(),
          categorieId: _categorieId,
          prixAchat: prixAchat,
          prixVente: prixVente,
          stockMinimum: stockMinimum,
          stockTotal: _articleExistant!.stockTotal,
          dateCreation: _articleExistant!.dateCreation,
          actif: true,
          description: description,
        ));
      } else {
        await repo.createArticle(
          code: _codeController.text.trim(),
          nom: _nomController.text.trim(),
          categorieId: _categorieId,
          prixAchat: prixAchat,
          prixVente: prixVente,
          stockMinimum: stockMinimum,
          description: description,
        );
      }
      ref.invalidate(articlesListProvider);
      ref.invalidate(filteredArticlesProvider);
      invalidateStockDependentProviders(ref);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _supprimer() async {
    if (widget.articleId == null || _articleExistant == null) return;

    final nomArticle = _articleExistant!.nom;
    final repo = ref.read(articleRepositoryProvider);

    // Pré-vérification : on sait d'avance si l'article est utilisé
    // pour pouvoir l'indiquer dans la boîte de confirmation, pas une
    // surprise après que l'utilisateur ait saisi le nom.
    final estUtilise = await repo.estArticleUtilise(widget.articleId!);

    final confirme = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _DialogueConfirmationSuppression(nomArticle: nomArticle, estUtilise: estUtilise),
    );

    if (confirme != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final resultat = await repo.supprimerOuArchiverArticle(widget.articleId!);

      ref.invalidate(articlesListProvider);
      ref.invalidate(filteredArticlesProvider);
      invalidateStockDependentProviders(ref);

      if (mounted) {
        final message = resultat == SuppressionArticleResult.supprime
            ? '✅ Article supprimé définitivement.'
            : '✅ Article archivé car il est utilisé dans des documents existants.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estEdition) _chargerArticleExistant();
    final categoriesAsync = ref.watch(categoriesListProvider);
    final utilisateur = ref.watch(sessionProvider);
    final peutVoirPrixAchat = Permissions.peutVoirPrixAchat(utilisateur);
    final peutSupprimer = Permissions.peutSupprimerArticle(utilisateur);
    final peutGererCatalogue =
        Permissions.peutGererCatalogueArticles(utilisateur);

    // Un employé qui ouvre un article existant le consulte
    // uniquement : aucun champ modifiable, pas de bouton
    // Enregistrer. La création (jamais atteinte par un employé,
    // route bloquée) reste pleinement éditable pour un admin.
    final modeLectureSeule = _estEdition && !peutGererCatalogue;

    return Scaffold(
      appBar: AppBar(
        title: Text(modeLectureSeule
            ? 'Détail article'
            : (_estEdition ? 'Modifier l\'article' : 'Nouvel article')),
        actions: [
          if (_estEdition && peutSupprimer)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _supprimer,
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (modeLectureSeule) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Consultation uniquement. Seul un administrateur peut modifier cet article.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Code article',
                          controller: _codeController,
                          hint: 'Ex: ART-001',
                          enabled: !modeLectureSeule,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Code requis'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Nom de l\'article',
                    controller: _nomController,
                    hint: 'Ex: Riz parfumé 25kg',
                    enabled: !modeLectureSeule,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
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
                                  ...categories.map((c) => DropdownMenuItem<int?>(
                                        value: c.id,
                                        child: Text(c.nom),
                                      )),
                                ],
                                onChanged: modeLectureSeule
                                    ? null
                                    : (v) => setState(() => _categorieId = v),
                              ),
                            ),
                            if (!modeLectureSeule) ...[
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
                      // Le prix d'achat est entièrement invisible pour
                      // un employé (pas seulement désactivé) : aucune
                      // information sur la marge ne doit lui être
                      // accessible, conformément à la règle validée.
                      if (peutVoirPrixAchat) ...[
                        Expanded(
                          child: AppTextField(
                            label: 'Prix d\'achat (FCFA)',
                            controller: _prixAchatController,
                            keyboardType: TextInputType.number,
                            enabled: !modeLectureSeule,
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
                          enabled: !modeLectureSeule,
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
                    enabled: !modeLectureSeule,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Description (optionnelle)',
                    controller: _descriptionController,
                    hint: 'Notes, détails produit...',
                    maxLines: 3,
                    enabled: !modeLectureSeule,
                  ),
                  if (!modeLectureSeule) ...[
                    const SizedBox(height: 28),
                    AppButton(
                      label: _estEdition ? 'Enregistrer' : 'Créer l\'article',
                      icon: Icons.check_circle_outline,
                      isLoading: _isLoading,
                      onPressed: _enregistrer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Boîte de dialogue de confirmation de suppression d'article,
/// bloquante jusqu'à ce que l'utilisateur saisisse exactement le
/// nom de l'article — pattern identique à GitHub et aux logiciels
/// professionnels pour les actions irréversibles ou importantes.
class _DialogueConfirmationSuppression extends StatefulWidget {
  final String nomArticle;
  final bool estUtilise;

  const _DialogueConfirmationSuppression({
    required this.nomArticle,
    required this.estUtilise,
  });

  @override
  State<_DialogueConfirmationSuppression> createState() =>
      _DialogueConfirmationSuppressionState();
}

class _DialogueConfirmationSuppressionState
    extends State<_DialogueConfirmationSuppression> {
  final _controller = TextEditingController();
  bool _nomCorrespond = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String valeur) {
    final correspond = valeur.trim() == widget.nomArticle.trim();
    if (correspond != _nomCorrespond) {
      setState(() => _nomCorrespond = correspond);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Text('⚠️ ', style: TextStyle(fontSize: 20)),
          Text('Suppression d\'article'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.estUtilise
                  ? 'Cet article est utilisé dans des ventes, achats ou devis '
                      'existants. Il sera archivé (retiré des listes) sans '
                      'effacer l\'historique — l\'action reste irréversible '
                      'sans intervention technique.'
                  : 'Vous êtes sur le point de supprimer définitivement cet '
                      'article. Il n\'apparaît dans aucun document existant. '
                      'Cette action est irréversible.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Pour confirmer, saisissez exactement le nom de l\'article :',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.nomArticle,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Tapez le nom ci-dessus...',
                suffixIcon: _nomCorrespond
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _nomCorrespond
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(
            widget.estUtilise ? 'Archiver définitivement' : 'Supprimer définitivement',
            style: TextStyle(
              color: _nomCorrespond ? Colors.white : Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }
}
