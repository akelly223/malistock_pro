import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/article_autocomplete_field.dart';
import '../../core/widgets/cart_line_tile.dart';
import '../../core/widgets/discount_input_field.dart';
import '../../core/widgets/discount_summary.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/cart_item_input.dart';
import '../../domain/entities/remise_globale.dart';
import '../../core/services/draft_service.dart';
import '../clients/providers/client_provider.dart';
import '../stores/providers/store_provider.dart';
import 'providers/quote_provider.dart';
import 'quotes_list_screen.dart';

/// Formulaire de devis, utilisé à la fois pour la création (sans
/// [quoteId]) et la modification (avec [quoteId]) — même comportement
/// que le formulaire article, qui suit déjà ce pattern.
class QuoteFormScreen extends ConsumerStatefulWidget {
  final int? quoteId;

  const QuoteFormScreen({super.key, this.quoteId});

  @override
  ConsumerState<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends ConsumerState<QuoteFormScreen> {
  final List<CartItemInput> _panier = [];
  int? _clientId;
  int? _storeId;
  RemiseGlobale _remise = RemiseGlobale.zero;
  bool _isLoading = false;
  bool _isInitialised = false;
  bool _estSoumis = false;

  Timer? _timerSauvegarde;
  late DraftService _draftService;

  bool get _estEdition => widget.quoteId != null;

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
      _draftService.sauvegarderDevis(
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
    await _draftService.sauvegarderDevis(
      panier: List.unmodifiable(_panier),
      clientId: _clientId,
      storeId: _storeId,
      remise: _remise,
    );
  }

  Future<void> _chargerBrouillon() async {
    final draft = await _draftService.chargerDevis();
    if (draft == null || !mounted) return;
    setState(() {
      _panier.clear();
      _panier.addAll(draft.panier);
      _clientId = draft.clientId;
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

  /// Charge les données du devis existant une seule fois, au premier
  /// build, pour pré-remplir le panier et le récapitulatif.
  Future<void> _chargerDevisExistant() async {
    if (widget.quoteId == null || _isInitialised) return;
    _isInitialised = true; // évite un double-chargement pendant l'await

    final repo = ref.read(quoteRepositoryProvider);
    final quote = await repo.getQuoteById(widget.quoteId!);
    if (quote == null || !mounted) return;

    setState(() {
      _clientId = quote.clientId;
      _storeId = quote.storeId;
      // La base ne conserve que le montant final de la remise, pas le
      // mode (FCFA ou %) utilisé à la saisie : on recharge donc
      // toujours en mode montant fixe, équivalent au montant
      // initialement appliqué.
      _remise = RemiseGlobale(valeur: quote.remiseGlobale);
      _panier.clear();
      _panier.addAll(quote.items.map((item) => CartItemInput(
            articleId: item.articleId,
            articleNom: item.articleNom,
            quantite: item.quantite,
            prixUnitaire: item.prixUnitaire,
            remisePourcentage: item.remisePourcentage,
            remiseMontant: item.remiseMontant,
          )));
    });
  }

  void _ajouterArticle(ArticleEntity article) {
    setState(() {
      final indexExistant =
          _panier.indexWhere((i) => i.articleId == article.id);
      if (indexExistant >= 0) {
        final existant = _panier[indexExistant];
        _panier[indexExistant] = CartItemInput(
          articleId: existant.articleId,
          articleNom: existant.articleNom,
          quantite: existant.quantite + 1,
          prixUnitaire: existant.prixUnitaire,
          remisePourcentage: existant.remisePourcentage,
          remiseMontant: existant.remiseMontant,
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
    _planifierSauvegarde();
  }

  void _modifierLigne(int index, CartItemInput nouvelleLigne) {
    setState(() => _panier[index] = nouvelleLigne);
    _planifierSauvegarde();
  }

  void _supprimerLigne(int index) {
    setState(() => _panier.removeAt(index));
    _planifierSauvegarde();
  }

  Future<void> _enregistrerDevis() async {
    if (_panier.isEmpty || _storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez des articles et un magasin.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final repo = ref.read(quoteRepositoryProvider);
    try {
      if (_estEdition) {
        await repo.updateQuote(
          quoteId: widget.quoteId!,
          clientId: _clientId,
          storeId: _storeId!,
          items: _panier,
          remiseGlobale: _montantRemise,
        );
        ref.invalidate(quoteByIdProvider(widget.quoteId!));
      } else {
        await repo.createQuote(
          clientId: _clientId,
          storeId: _storeId!,
          items: _panier,
          remiseGlobale: _montantRemise,
        );
        _estSoumis = true;
        _timerSauvegarde?.cancel();
        await _draftService.supprimerDevis();
      }
      ref.invalidate(quotesListProvider);
      if (mounted) context.pop();
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
    if (_estEdition) _chargerDevisExistant();

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
        title: Text(_estEdition ? 'Modifier le devis' : 'Nouveau devis'),
      ),
      body: Row(
        children: [
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
                              'Recherchez un article ci-dessus.',
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
            width: 340,
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
                    data: (stores) => DropdownButtonFormField<int>(
                      initialValue: _storeId,
                      decoration: const InputDecoration(labelText: 'Magasin'),
                      items: stores
                          .map((s) =>
                              DropdownMenuItem(value: s.id, child: Text(s.nom)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _storeId = v);
                        _planifierSauvegarde();
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  clientsAsync.when(
                    data: (clients) => DropdownButtonFormField<int?>(
                      initialValue: _clientId,
                      decoration:
                          const InputDecoration(labelText: 'Client (optionnel)'),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('Sans client')),
                        ...clients.map((c) =>
                            DropdownMenuItem<int?>(value: c.id, child: Text(c.nom))),
                      ],
                      onChanged: (v) {
                        setState(() => _clientId = v);
                        _planifierSauvegarde();
                      },
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
                  const SizedBox(height: 20),
                  AppButton(
                    label: _estEdition
                        ? 'Enregistrer les modifications'
                        : 'Enregistrer le devis',
                    icon: Icons.check_circle_outline,
                    isLoading: _isLoading,
                    onPressed: _panier.isEmpty ? null : _enregistrerDevis,
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
