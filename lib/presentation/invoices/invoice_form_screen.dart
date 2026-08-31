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
import '../../core/widgets/cart_line_tile.dart';
import '../../core/widgets/discount_input_field.dart';
import '../../core/widgets/discount_summary.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/constants/db_constants.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/cart_item_input.dart';
import '../../domain/entities/remise_globale.dart';
import '../../domain/exceptions/stock_insuffisant_exception.dart';
import '../../core/services/draft_service.dart';
import '../clients/providers/client_provider.dart';
import '../stores/providers/store_provider.dart';
import 'providers/invoice_provider.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final int? invoiceId;

  const InvoiceFormScreen({super.key, this.invoiceId});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final List<CartItemInput> _panier = [];
  int? _clientId;
  int? _storeId;
  RemiseGlobale _remise = RemiseGlobale.zero;
  bool _isLoading = false;
  bool _isInitialise = false;
  bool _estSoumis = false;

  Timer? _timerSauvegarde;
  late DraftService _draftService;

  final Map<int, double> _stockDisponibleParArticle = {};

  bool get _estEdition => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _draftService = ref.read(draftServiceProvider);
    if (!_estEdition) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _chargerBrouillon());
    }
  }

  @override
  void dispose() {
    _timerSauvegarde?.cancel();
    if (!_estEdition && !_estSoumis && _panier.isNotEmpty) {
      _draftService.sauvegarderVente(
        panier: List.unmodifiable(_panier),
        clientId: _clientId,
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
    await _draftService.sauvegarderVente(
      panier: List.unmodifiable(_panier),
      clientId: _clientId,
      storeId: _storeId,
      remise: _remise,
    );
  }

  Future<void> _chargerBrouillon() async {
    final draft = await _draftService.chargerVente();
    if (draft == null || !mounted) return;
    setState(() {
      _panier.clear();
      _panier.addAll(draft.panier);
      _clientId = draft.clientId;
      if (draft.storeId != null) _storeId = draft.storeId;
      _remise = draft.remise;
    });
    for (final item in _panier) {
      _rafraichirStockDisponible(item.articleId);
    }
  }

  Future<void> _rafraichirStockDisponible(int articleId) async {
    if (_storeId == null) return;
    final repo = ref.read(articleRepositoryProvider);
    final stock = await repo.getStockInStore(articleId, _storeId!);
    if (mounted) {
      setState(() => _stockDisponibleParArticle[articleId] = stock);
    }
  }

  bool get _stockInsuffisantDansLePanier {
    for (final item in _panier) {
      final disponible = _stockDisponibleParArticle[item.articleId];
      if (disponible != null && item.quantite > disponible) return true;
    }
    return false;
  }

  double get _sousTotal => _panier.fold<double>(0, (s, i) => s + i.totalLigne);
  double get _montantRemise => _remise.montantPour(_sousTotal);
  double get _totalFinal {
    final t = _sousTotal - _montantRemise;
    return t < 0 ? 0 : t;
  }

  Future<void> _chargerFactureExistante() async {
    if (!_estEdition || _isInitialise) return;
    _isInitialise = true;

    final repo = ref.read(invoiceRepositoryProvider);
    final facture = await repo.getInvoiceById(widget.invoiceId!);
    if (facture == null || !mounted) return;

    setState(() {
      _clientId = facture.clientId;
      _storeId = facture.storeId;
      _remise = RemiseGlobale(valeur: facture.remiseGlobale);
      _panier.clear();
      _panier.addAll(facture.items.map((item) => CartItemInput(
            articleId: item.articleId,
            articleNom: item.articleNom,
            quantite: item.quantite,
            prixUnitaire: item.prixUnitaire,
            remisePourcentage: item.remisePourcentage,
            remiseMontant: item.remiseMontant,
          )));
    });

    for (final item in _panier) {
      _rafraichirStockDisponible(item.articleId);
    }
  }

  void _ajouterArticle(ArticleEntity article) {
    setState(() {
      final idx = _panier.indexWhere((i) => i.articleId == article.id);
      if (idx >= 0) {
        final e = _panier[idx];
        _panier[idx] = CartItemInput(
          articleId: e.articleId,
          articleNom: e.articleNom,
          quantite: e.quantite + 1,
          prixUnitaire: e.prixUnitaire,
          remisePourcentage: e.remisePourcentage,
          remiseMontant: e.remiseMontant,
        );
      } else {
        _panier.insert(0, CartItemInput(
          articleId: article.id,
          articleNom: article.nom,
          quantite: 1,
          prixUnitaire: article.prixVente,
        ));
      }
    });
    _rafraichirStockDisponible(article.id);
    _planifierSauvegarde();
  }

  void _modifierLigne(int index, CartItemInput line) {
    setState(() => _panier[index] = line);
    _planifierSauvegarde();
  }

  void _supprimerLigne(int index) {
    setState(() => _panier.removeAt(index));
    _planifierSauvegarde();
  }

  // ── Nouvelle vente ────────────────────────────────────────────────

  Future<void> _validerVente() async {
    if (_panier.isEmpty) {
      _snack('Ajoutez au moins un article.');
      return;
    }
    if (_storeId == null) {
      _snack('Sélectionnez un magasin.');
      return;
    }
    if (_stockInsuffisantDansLePanier) {
      _snack('Stock insuffisant pour au moins un article.');
      return;
    }
    if (_estEdition) {
      await _enregistrerModification();
    } else {
      await _creerVente();
    }
  }

  Future<void> _creerVente() async {
    final resultat = await _afficherDialoguePaiement();
    if (resultat == null) return;

    setState(() => _isLoading = true);
    final user = ref.read(sessionProvider);
    final repo = ref.read(invoiceRepositoryProvider);

    try {
      final id = await repo.createInvoice(
        clientId: _clientId,
        storeId: _storeId!,
        userId: user?.id ?? 0,
        items: _panier,
        remiseGlobale: _montantRemise,
        montantPayeInitial: resultat.montant,
        modePaiementInitial: resultat.mode,
      );
      _estSoumis = true;
      _timerSauvegarde?.cancel();
      await _draftService.supprimerVente();
      ref.invalidate(invoicesListProvider);
      invalidateStockDependentProviders(ref);
      if (mounted) context.pushReplacement('/invoices/$id');
    } on StockInsuffisantException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _snack(e.toString());
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _snack('Erreur : $e');
    }
  }

  // ── Modification ─────────────────────────────────────────────────

  Future<void> _enregistrerModification() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la modification ?'),
        content: const Text(
          'Le stock sera recalculé automatiquement :\n'
          '• Les quantités de l\'ancienne vente seront restituées au stock\n'
          '• Les nouvelles quantités seront déduites\n\n'
          'Le montant déjà encaissé reste inchangé. '
          'Le statut de paiement sera recalculé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Confirmer',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isLoading = true);
    final user = ref.read(sessionProvider);
    final repo = ref.read(invoiceRepositoryProvider);

    try {
      await repo.updateInvoice(
        invoiceId: widget.invoiceId!,
        clientId: _clientId,
        storeId: _storeId!,
        modifieParUserId: user?.id ?? 0,
        items: _panier,
        remiseGlobale: _montantRemise,
      );
      ref.invalidate(invoicesListProvider);
      ref.invalidate(invoiceByIdProvider(widget.invoiceId!));
      invalidateStockDependentProviders(ref);
      if (mounted) context.pop();
    } on StockInsuffisantException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _snack(e.toString());
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _snack('Erreur : $e');
    }
  }

  // ── Dialogue paiement ────────────────────────────────────────────

  Future<_PaiementResultat?> _afficherDialoguePaiement() async {
    final montantController =
        TextEditingController(text: _totalFinal.toStringAsFixed(0));
    String mode = DbConstants.paymentEspeces;
    bool payeEnTotalite = true;

    return showDialog<_PaiementResultat>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Encaissement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Total à payer : ${CurrencyFormatter.format(_totalFinal)}',
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
                label: 'Montant reçu (FCFA)',
                controller: montantController,
                keyboardType: TextInputType.number,
                enabled: true,
              ),
              const SizedBox(height: 16),
              const Text('Mode de paiement',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: mode,
                items: const [
                  DropdownMenuItem(
                      value: DbConstants.paymentEspeces,
                      child: Text('Espèces')),
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
                      value: DbConstants.paymentCheque,
                      child: Text('Chèque')),
                ],
                onChanged: (v) => setStateDialog(() => mode = v!),
              ),
              if (!payeEnTotalite && _clientId == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Astuce : pour suivre une dette, sélectionnez un client avant de valider.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => context.pop(),
                child: const Text('Annuler')),
            AppButton(
              label: 'Valider la vente',
              onPressed: () {
                final montant =
                    double.tryParse(montantController.text) ?? 0;
                context
                    .pop(_PaiementResultat(montant: montant, mode: mode));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_estEdition) _chargerFactureExistante();

    final storesAsync = ref.watch(storesListProvider);
    final clientsAsync = ref.watch(filteredClientsProvider);

    storesAsync.whenData((stores) {
      if (_storeId == null && stores.isNotEmpty && !_estEdition) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _storeId = stores.first.id);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
          title: Text(_estEdition ? 'Modifier la vente' : 'Nouvelle vente')),
      body: Row(
        children: [
          // Zone articles
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArticleAutocompleteField(
                    label: 'Ajouter un article',
                    onSearch: (query) => ref
                        .read(articleRepositoryProvider)
                        .searchArticles(query),
                    onSelected: _ajouterArticle,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _panier.isEmpty
                        ? Center(
                            child: Text(
                              _estEdition
                                  ? 'Chargement de la vente...'
                                  : 'Recherchez un article ci-dessus\npour commencer la vente.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _panier.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return CartLineTile(
                                key: ValueKey(_panier[index].articleId),
                                item: _panier[index],
                                stockDisponible:
                                    _stockDisponibleParArticle[
                                        _panier[index].articleId],
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
          // Panneau récapitulatif
          Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border:
                  Border(left: BorderSide(color: AppColors.border)),
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
                        const Text('Magasin',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _storeId,
                          items: stores
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.nom)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _storeId = v);
                            for (final item in _panier) {
                              _rafraichirStockDisponible(item.articleId);
                            }
                            _planifierSauvegarde();
                          },
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  clientsAsync.when(
                    data: (clients) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Client (optionnel)',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int?>(
                          value: _clientId,
                          decoration: const InputDecoration(
                              hintText: 'Vente comptoir'),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Vente comptoir')),
                            ...clients.map((c) => DropdownMenuItem<int?>(
                                value: c.id, child: Text(c.nom))),
                          ],
                          onChanged: (v) {
                            setState(() => _clientId = v);
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
                    onChanged: (r) {
                      setState(() => _remise = r);
                      _planifierSauvegarde();
                    },
                  ),
                  const Divider(height: 32),
                  DiscountSummary(sousTotal: _sousTotal, remise: _remise),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _estEdition
                        ? 'Enregistrer les modifications'
                        : 'Valider la vente',
                    icon: Icons.check_circle_outline,
                    isLoading: _isLoading,
                    onPressed:
                        (_panier.isEmpty || _stockInsuffisantDansLePanier)
                            ? null
                            : _validerVente,
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
