import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/article_autocomplete_field.dart';
import '../../core/widgets/article_quick_create_dialog.dart';
import '../../core/widgets/discount_input_field.dart';
import '../../core/widgets/discount_summary.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/constants/db_constants.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/purchase_cart_item_input.dart';
import '../../domain/entities/remise_globale.dart';
import '../../core/services/draft_service.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/permissions/permissions.dart';
import '../suppliers/suppliers_list_screen.dart';
import '../stores/providers/store_provider.dart';
import 'providers/purchase_provider.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  final int? purchaseId;

  /// Statut initial pour une nouvelle saisie : 'recu' (achat, défaut)
  /// ou 'commande' (bon de commande, sans impact stock).
  final String initialStatut;

  const PurchaseFormScreen({
    super.key,
    this.purchaseId,
    this.initialStatut = DbConstants.purchaseStatutRecu,
  });

  @override
  ConsumerState<PurchaseFormScreen> createState() =>
      _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final List<PurchaseCartItemInput> _panier = [];
  int? _supplierId;
  int? _storeId;
  RemiseGlobale _remise = RemiseGlobale.zero;
  bool _isLoading = false;
  bool _isInitialise = false;
  bool _estSoumis = false;
  late String _statut;

  Timer? _timerSauvegarde;
  late DraftService _draftService;

  bool get _estEdition => widget.purchaseId != null;
  bool get _estCommande => _statut == DbConstants.purchaseStatutCommande;

  @override
  void initState() {
    super.initState();
    _statut = widget.initialStatut;
    _draftService = ref.read(draftServiceProvider);
    if (!_estEdition) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chargerBrouillon());
    }
  }

  @override
  void dispose() {
    _timerSauvegarde?.cancel();
    if (!_estEdition && !_estSoumis && _panier.isNotEmpty) {
      _draftService.sauvegarderAchat(
        panier: List.unmodifiable(_panier),
        supplierId: _supplierId,
        storeId: _storeId,
        remise: _remise,
      );
    }
    super.dispose();
  }

  void _planifierSauvegarde() {
    if (_estEdition) return;
    _timerSauvegarde?.cancel();
    _timerSauvegarde = Timer(
      const Duration(milliseconds: 1500),
      _sauvegarderBrouillon,
    );
  }

  Future<void> _sauvegarderBrouillon() async {
    if (_estEdition || _panier.isEmpty) return;
    await _draftService.sauvegarderAchat(
      panier: List.unmodifiable(_panier),
      supplierId: _supplierId,
      storeId: _storeId,
      remise: _remise,
    );
  }

  Future<void> _chargerBrouillon() async {
    final draft = await _draftService.chargerAchat();
    if (draft == null || !mounted) return;
    setState(() {
      _panier.clear();
      _panier.addAll(draft.panier);
      _supplierId = draft.supplierId;
      if (draft.storeId != null) _storeId = draft.storeId;
      _remise = draft.remise;
    });
  }

  double get _sousTotal => _panier.fold<double>(0, (s, i) => s + i.totalLigne);

  double get _montantRemise => _remise.montantPour(_sousTotal);

  double get _totalFinal {
    final total = _sousTotal - _montantRemise;
    return total < 0 ? 0 : total;
  }

  /// Charge les données de l'achat existant au premier build en mode
  /// édition pour pré-remplir le formulaire (fournisseur, magasin,
  /// articles, quantités, prix, remise).
  Future<void> _chargerAchatExistant() async {
    if (!_estEdition || _isInitialise) return;
    _isInitialise = true;

    final repo = ref.read(purchaseRepositoryProvider);
    final achat = await repo.getPurchaseById(widget.purchaseId!);
    if (achat == null || !mounted) return;

    setState(() {
      _supplierId = achat.supplierId;
      _storeId = achat.storeId;
      _statut = achat.statut;
      _remise = RemiseGlobale(valeur: achat.remiseGlobale);
      _panier.clear();
      _panier.addAll(achat.items.map((item) => PurchaseCartItemInput(
            articleId: item.articleId,
            articleNom: item.articleNom,
            quantite: item.quantite,
            prixAchatUnitaire: item.prixAchatUnitaire,
          )));
    });
  }

  void _ajouterArticle(ArticleEntity article) {
    setState(() {
      final indexExistant =
          _panier.indexWhere((i) => i.articleId == article.id);
      if (indexExistant >= 0) {
        final existant = _panier[indexExistant];
        _panier[indexExistant] = PurchaseCartItemInput(
          articleId: existant.articleId,
          articleNom: existant.articleNom,
          quantite: existant.quantite + 1,
          prixAchatUnitaire: existant.prixAchatUnitaire,
        );
      } else {
        _panier.insert(0, PurchaseCartItemInput(
          articleId: article.id,
          articleNom: article.nom,
          quantite: 1,
          prixAchatUnitaire: article.prixAchat,
        ));
      }
    });
    _planifierSauvegarde();
  }

  /// Ouvre la création rapide d'article sans quitter l'achat en cours.
  /// Le magasin de réception déjà sélectionné est affiché à titre
  /// informatif ; l'article créé (prix d'achat inclus) est ajouté
  /// automatiquement au panier par [ArticleAutocompleteField].
  Future<ArticleEntity?> _ouvrirCreationArticle(
      BuildContext context, String texteSaisi) {
    final stores = ref.read(storesListProvider).valueOrNull ?? const [];
    String? magasinNom;
    for (final store in stores) {
      if (store.id == _storeId) {
        magasinNom = store.nom;
        break;
      }
    }
    return ArticleQuickCreateDialog.show(
      context,
      nomInitial: texteSaisi,
      magasinContexte: magasinNom,
    );
  }

  void _modifierLigne(int index, PurchaseCartItemInput nouvelleLigne) {
    setState(() => _panier[index] = nouvelleLigne);
    _planifierSauvegarde();
  }

  void _supprimerLigne(int index) {
    setState(() => _panier.removeAt(index));
    _planifierSauvegarde();
  }

  Future<void> _validerAchat() async {
    if (_panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un article.')),
      );
      return;
    }
    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un magasin de réception.')),
      );
      return;
    }
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un fournisseur.')),
      );
      return;
    }

    if (_estEdition) {
      await _enregistrerModification();
    } else {
      await _creerNouvelAchat();
    }
  }

  Future<void> _creerNouvelAchat() async {
    // Un bon de commande n'est pas encore payé : la marchandise n'a
    // pas été livrée, il n'y a donc rien à régler pour l'instant.
    _PaiementResultat? resultat;
    if (!_estCommande) {
      resultat = await _afficherDialoguePaiement();
      if (resultat == null) return;
    }

    setState(() => _isLoading = true);
    final user = ref.read(sessionProvider);
    final repo = ref.read(purchaseRepositoryProvider);

    try {
      final purchaseId = await repo.createPurchase(
        supplierId: _supplierId!,
        storeId: _storeId!,
        userId: user?.id ?? 0,
        items: _panier,
        remiseGlobale: _montantRemise,
        montantPayeInitial: resultat?.montant ?? 0,
        modePaiementInitial: resultat?.mode,
        statut: _statut,
      );
      _estSoumis = true;
      _timerSauvegarde?.cancel();
      await _draftService.supprimerAchat();
      ref.invalidate(filteredPurchasesProvider);
      invalidateStockDependentProviders(ref);
      if (mounted) context.pushReplacement('/purchases/$purchaseId');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _enregistrerModification() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la modification ?'),
        content: Text(
          _estCommande
              ? 'Les articles et quantités du bon de commande seront mis à jour. '
                  'Le stock ne sera impacté qu\'à la réception de la commande.'
              : 'Le stock sera recalculé automatiquement :\n'
                  '• Les quantités de l\'ancien achat seront retirées du stock\n'
                  '• Les nouvelles quantités seront ajoutées\n\n'
                  'Cette action est traçable et réversible en remodifiant l\'achat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Confirmer la modification',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isLoading = true);
    final user = ref.read(sessionProvider);
    final repo = ref.read(purchaseRepositoryProvider);

    try {
      await repo.updatePurchase(
        purchaseId: widget.purchaseId!,
        supplierId: _supplierId!,
        storeId: _storeId!,
        modifieParUserId: user?.id ?? 0,
        items: _panier,
        remiseGlobale: _montantRemise,
      );
      ref.invalidate(filteredPurchasesProvider);
      ref.invalidate(purchaseByIdProvider(widget.purchaseId!));
      invalidateStockDependentProviders(ref);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<_PaiementResultat?> _afficherDialoguePaiement() async {
    final montantController =
        TextEditingController(text: _totalFinal.toStringAsFixed(0));
    String mode = DbConstants.paymentEspeces;
    bool payeEnTotalite = true;

    return showDialog<_PaiementResultat>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Règlement fournisseur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total de l\'achat : ${CurrencyFormatter.format(_totalFinal)}',
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Payé intégralement')),
                  ButtonSegment(value: false, label: Text('Paiement partiel')),
                ],
                selected: {payeEnTotalite},
                onSelectionChanged: (s) => setStateDialog(() {
                  payeEnTotalite = s.first;
                  montantController.text = payeEnTotalite
                      ? _totalFinal.toStringAsFixed(0)
                      : '0';
                }),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Montant versé (FCFA)',
                controller: montantController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Mode de paiement',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: mode,
                items: const [
                  DropdownMenuItem(
                      value: DbConstants.paymentEspeces, child: Text('Espèces')),
                  DropdownMenuItem(
                      value: DbConstants.paymentOrangeMoney,
                      child: Text('Orange Money')),
                  DropdownMenuItem(
                      value: DbConstants.paymentMoovMoney,
                      child: Text('Moov Money')),
                  DropdownMenuItem(
                      value: DbConstants.paymentVirement,
                      child: Text('Virement')),
                  DropdownMenuItem(
                      value: DbConstants.paymentCheque, child: Text('Chèque')),
                ],
                onChanged: (v) => setStateDialog(() => mode = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => context.pop(),
                child: const Text('Annuler')),
            AppButton(
              label: 'Valider l\'achat',
              onPressed: () {
                final montant = double.tryParse(montantController.text) ?? 0;
                context.pop(_PaiementResultat(montant: montant, mode: mode));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutGererAchats(utilisateur)) {
      return const AccessDeniedView(titre: 'Achats fournisseurs');
    }

    if (_estEdition) _chargerAchatExistant();

    final storesAsync = ref.watch(storesListProvider);
    final suppliersAsync = ref.watch(suppliersListProvider);

    storesAsync.whenData((stores) {
      if (_storeId == null && stores.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _storeId = stores.first.id);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
          title: Text(_estEdition
              ? (_estCommande ? 'Modifier le bon de commande' : 'Modifier l\'achat')
              : (_estCommande
                  ? 'Nouveau bon de commande'
                  : 'Nouvel achat fournisseur'))),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_estEdition) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: DbConstants.purchaseStatutRecu,
                          label: Text('Achat (réception immédiate)'),
                          icon: Icon(Icons.inventory_2_outlined),
                        ),
                        ButtonSegment(
                          value: DbConstants.purchaseStatutCommande,
                          label: Text('Bon de commande'),
                          icon: Icon(Icons.assignment_outlined),
                        ),
                      ],
                      selected: {_statut},
                      onSelectionChanged: (s) =>
                          setState(() => _statut = s.first),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ArticleAutocompleteField(
                    label: 'Ajouter un article',
                    onSearch: (query) => ref
                        .read(articleRepositoryProvider)
                        .searchArticles(query),
                    onSelected: _ajouterArticle,
                    onCreateArticle: _ouvrirCreationArticle,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _panier.isEmpty
                        ? Center(
                            child: Text(
                              'Recherchez un article ci-dessus\npour commencer l\'achat.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _panier.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _PurchaseLineTile(
                                key: ValueKey(_panier[index].articleId),
                                item: _panier[index],
                                onChanged: (line) =>
                                    _modifierLigne(index, line),
                                onRemove: () => _supprimerLigne(index),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Récapitulatif', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  storesAsync.when(
                    data: (stores) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Magasin de réception',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _storeId,
                          items: stores
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.nom)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _storeId = v);
                            _planifierSauvegarde();
                          },
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  suppliersAsync.when(
                    data: (suppliers) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fournisseur',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _supplierId,
                          decoration: const InputDecoration(
                              hintText: 'Sélectionner un fournisseur'),
                          items: suppliers
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.nom)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _supplierId = v);
                            _planifierSauvegarde();
                          },
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  DiscountInputField(
                    remise: _remise,
                    onChanged: (nouvelleRemise) {
                      setState(() => _remise = nouvelleRemise);
                      _planifierSauvegarde();
                    },
                  ),
                  const Divider(height: 32),
                  DiscountSummary(sousTotal: _sousTotal, remise: _remise),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _estEdition
                        ? 'Enregistrer les modifications'
                        : (_estCommande
                            ? 'Créer le bon de commande'
                            : 'Valider l\'achat'),
                    icon: Icons.check_circle_outline,
                    isLoading: _isLoading,
                    onPressed: _panier.isEmpty ? null : _validerAchat,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaiementResultat {
  final double montant;
  final String mode;

  _PaiementResultat({required this.montant, required this.mode});
}

/// Ligne du panier d'achat, éditable (quantité, prix d'achat).
class _PurchaseLineTile extends StatefulWidget {
  final PurchaseCartItemInput item;
  final void Function(PurchaseCartItemInput) onChanged;
  final VoidCallback onRemove;

  const _PurchaseLineTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_PurchaseLineTile> createState() => _PurchaseLineTileState();
}

class _PurchaseLineTileState extends State<_PurchaseLineTile> {
  late TextEditingController _quantiteController;
  late TextEditingController _prixController;

  @override
  void initState() {
    super.initState();
    _quantiteController =
        TextEditingController(text: widget.item.quantite.toStringAsFixed(0));
    _prixController = TextEditingController(
        text: widget.item.prixAchatUnitaire.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_PurchaseLineTile old) {
    super.didUpdateWidget(old);
    final quantiteAffichee = double.tryParse(_quantiteController.text);
    if (quantiteAffichee != widget.item.quantite) {
      _quantiteController.text = widget.item.quantite.toStringAsFixed(0);
    }
    final prixAffiche = double.tryParse(_prixController.text);
    if (prixAffiche != widget.item.prixAchatUnitaire) {
      _prixController.text = widget.item.prixAchatUnitaire.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixController.dispose();
    super.dispose();
  }

  void _update() {
    final qte = double.tryParse(_quantiteController.text) ?? 1;
    final prix = double.tryParse(_prixController.text) ?? 0;
    widget.onChanged(PurchaseCartItemInput(
      articleId: widget.item.articleId,
      articleNom: widget.item.articleNom,
      quantite: qte <= 0 ? 1 : qte,
      prixAchatUnitaire: prix,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(widget.item.articleNom, style: AppTextStyles.bodyBold),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _quantiteController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Qté'),
              onChanged: (_) => _update(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _prixController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Prix achat'),
              onChanged: (_) => _update(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              CurrencyFormatter.format(widget.item.totalLigne),
              style: AppTextStyles.bodyBold,
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
