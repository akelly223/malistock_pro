import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/permissions/permissions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/category_quick_create.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/article_repository.dart';
import 'providers/article_provider.dart';

/// Taux de conversion fixe utilisé pour le calculateur dépôt-vente
/// (1 € = 655 FCFA, valeur pratique de l'utilisateur — voir
/// [[project_depot_vente_auteurs]]). Volontairement pas le taux BCEAO
/// exact (655,957) : c'est la valeur qu'il utilise pour ses calculs.
const double _tauxEuroCfa = 655;

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
  final _prixEuroController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _categorieId;
  int? _supplierId;
  bool _isLoading = false;
  bool _isInitialised = false;
  ArticleEntity? _articleExistant;

  bool get _estEdition => widget.articleId != null;

  /// Pourcentage reversé à l'auteur pour le fournisseur sélectionné
  /// (80% par défaut si introuvable, cohérent avec le défaut du
  /// dialogue de création fournisseur).
  double _partAuteurPct(List<SupplierEntity> depotSuppliers, int? supplierId) {
    for (final s in depotSuppliers) {
      if (s.id == supplierId) return s.partAuteurPct;
    }
    return 80;
  }

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
    _prixEuroController.dispose();
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
        if (article.prixEuro != null) {
          _prixEuroController.text = article.prixEuro!.toStringAsFixed(2);
        }
        _categorieId = article.categorieId;
        _supplierId = article.supplierId;
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
    final prixEuroSaisi =
        double.tryParse(_prixEuroController.text.replaceAll(',', '.'));
    final prixEuro = (prixEuroSaisi != null && prixEuroSaisi > 0)
        ? prixEuroSaisi
        : null;
    final tauxConversionEuro = prixEuro != null ? _tauxEuroCfa : null;

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
          supplierId: _supplierId,
          description: description,
          prixEuro: prixEuro,
          tauxConversionEuro: tauxConversionEuro,
        ));
      } else {
        await repo.createArticle(
          code: _codeController.text.trim(),
          nom: _nomController.text.trim(),
          categorieId: _categorieId,
          prixAchat: prixAchat,
          prixVente: prixVente,
          stockMinimum: stockMinimum,
          supplierId: _supplierId,
          description: description,
          prixEuro: prixEuro,
          tauxConversionEuro: tauxConversionEuro,
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
    final depotSuppliersAsync = ref.watch(depotSuppliersProvider);
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
                  depotSuppliersAsync.when(
                    data: (depotSuppliers) {
                      if (depotSuppliers.isEmpty &&
                          _supplierId == null) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fournisseur dépôt-vente (auteur / maison d\'édition)',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int?>(
                            initialValue: _supplierId,
                            decoration: const InputDecoration(
                                hintText: 'Aucun (article normal)'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Aucun (article normal)'),
                              ),
                              ...depotSuppliers.map((s) => DropdownMenuItem<int?>(
                                    value: s.id,
                                    child: Text(
                                        '${s.nom} (${s.partAuteurPct.toStringAsFixed(0)}%)'),
                                  )),
                            ],
                            onChanged: modeLectureSeule
                                ? null
                                : (v) => setState(() => _supplierId = v),
                          ),
                          if (_supplierId != null && !modeLectureSeule)
                            _CalculateurPrixEuro(
                              controller: _prixEuroController,
                              partAuteurPct: _partAuteurPct(
                                  depotSuppliers, _supplierId),
                              onPrixConverti: (cfa) => _prixVenteController
                                  .text = cfa > 0 ? cfa.toStringAsFixed(0) : '',
                            ),
                        ],
                      );
                    },
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

/// Calculateur dépôt-vente : convertit un prix affiché en euros (cas
/// fréquent pour les livres reçus d'auteurs/maisons d'édition
/// européennes) en FCFA au taux fixe [_tauxEuroCfa], et affiche
/// immédiatement la part qui revient à l'auteur et celle qui reste à
/// la librairie. But : éviter à l'utilisateur de reconvertir et
/// recalculer à la main à chaque règlement d'auteur après une vente
/// (voir demande utilisateur du 2026-08-17, mémoire
/// [[project_depot_vente_auteurs]]). Purement un outil de saisie —
/// rien ici n'est persisté, seul le prix de vente FCFA converti est
/// reporté dans le champ "Prix de vente" du formulaire.
class _CalculateurPrixEuro extends StatelessWidget {
  final TextEditingController controller;
  final double partAuteurPct;
  final ValueChanged<double> onPrixConverti;

  const _CalculateurPrixEuro({
    required this.controller,
    required this.partAuteurPct,
    required this.onPrixConverti,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.euro_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Calculateur prix en euros (1 € = ${_tauxEuroCfa.toStringAsFixed(0)} FCFA)',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prix indiqué sur le livre (€)',
              hintText: 'Ex: 18',
              isDense: true,
            ),
            onChanged: (v) {
              final euro = double.tryParse(v.replaceAll(',', '.')) ?? 0;
              onPrixConverti(euro * _tauxEuroCfa);
              // Force le rebuild de l'aperçu part auteur / part
              // boutique ci-dessous sans dépendre d'un setState
              // parent (le contrôleur notifie déjà ses listeners).
            },
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final euro =
                  double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              final totalCfa = euro * _tauxEuroCfa;
              final partAuteur = totalCfa * partAuteurPct / 100;
              final partBoutique = totalCfa - partAuteur;
              if (euro <= 0) {
                return const Text(
                  'Saisissez le prix en euros pour voir la répartition.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                );
              }
              return Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [
                  _ligneRepartition('Prix converti', totalCfa),
                  _ligneRepartition(
                      'Part auteur (${partAuteurPct.toStringAsFixed(0)}%)',
                      partAuteur),
                  _ligneRepartition(
                      'Ma part (${(100 - partAuteurPct).toStringAsFixed(0)}%)',
                      partBoutique),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _ligneRepartition(String libelle, double montant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(libelle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(CurrencyFormatter.format(montant),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
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
