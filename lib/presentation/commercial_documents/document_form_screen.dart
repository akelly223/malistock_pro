import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/services/draft_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/document_header_form.dart';
import '../../core/widgets/document_lines_editor.dart';
import '../../core/widgets/document_totals_footer.dart';
import '../../core/widgets/sale_payment_section.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/entities/document_input.dart';
import '../articles/providers/article_provider.dart';
import 'providers/commercial_document_providers.dart';
import 'providers/document_form_notifier.dart';

/// Formulaire de création / édition d'un document commercial V2.
///
/// [routePrefix] sert à la navigation post-enregistrement.
/// [documentId] non null = mode édition (lignes rechargées depuis la BD).
class DocumentFormScreen extends ConsumerStatefulWidget {
  final DocumentType type;
  final int? documentId;
  final String routePrefix;

  const DocumentFormScreen({
    super.key,
    required this.type,
    required this.routePrefix,
    this.documentId,
  });

  @override
  ConsumerState<DocumentFormScreen> createState() =>
      _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  (DocumentType, int?) get _key => (widget.type, widget.documentId);

  late final DraftService _draftService;
  late final String _draftType;
  ProviderSubscription<DocumentFormState>? _subscription;
  Timer? _timerSauvegarde;
  bool _estSoumis = false;
  DocumentFormState? _dernierEtat;

  @override
  void initState() {
    super.initState();
    _draftService = ref.read(draftServiceProvider);
    _draftType = DraftType.pourDocumentType(widget.type);

    if (widget.documentId != null) {
      // Mode édition : charge le document existant
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final doc =
            await ref.read(documentParIdProvider(widget.documentId!).future);
        if (doc == null || !mounted) return;
        final notifier = ref.read(documentFormProvider(_key).notifier);
        notifier.setClient(doc.clientId, doc.clientNom);
        notifier.setStore(doc.storeId);
        notifier.setDate(doc.dateDocument);
        notifier.setRemiseGlobale(doc.remiseGlobalePct);
        notifier.setNotes(doc.notes);
        notifier.setReferenceExterne(doc.referenceExterne);
        notifier.setConditionsReglement(doc.conditionsReglement);

        // Récupérer le taux TVA depuis la première ligne (toutes les lignes
        // partagent le même taux depuis la V3).
        final tvaTaux =
            doc.lignes.isNotEmpty ? doc.lignes.first.tauxTva : 0.0;
        if (tvaTaux > 0) {
          notifier.setTvaGlobale(tvaTaux);
          notifier.setAppliquerTva(true);
        }

        for (final l in doc.lignes) {
          // On force tauxTva=0 dans le formulaire : la TVA est désormais
          // gérée au niveau du document, pas par ligne.
          notifier.ajouterLigne(DocumentLigneInput(
            articleId: l.articleId,
            articleCode: l.articleCode,
            articleNom: l.articleNom,
            quantite: l.quantite,
            prixUnitaireHt: l.prixUnitaireHt,
            tauxTva: 0,
            remiseLignePct: l.remiseLignePct,
          ));
        }
      });
    } else {
      // Mode création : essaie de charger un brouillon existant
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final draft = await _draftService.chargerDocument(_draftType);
        if (draft == null || !mounted) return;
        final notifier = ref.read(documentFormProvider(_key).notifier);
        if (draft.clientId != null) {
          notifier.setClient(draft.clientId, draft.clientNom);
        }
        if (draft.storeId != null) notifier.setStore(draft.storeId!);
        if (draft.dateDocument != null) notifier.setDate(draft.dateDocument!);
        notifier.setRemiseGlobale(draft.remiseGlobalePct);
        notifier.setAppliquerTva(draft.appliquerTva);
        notifier.setTvaGlobale(draft.tvaGlobalePct);
        if (draft.notes != null) notifier.setNotes(draft.notes);
        if (draft.referenceExterne != null) {
          notifier.setReferenceExterne(draft.referenceExterne);
        }
        if (draft.conditionsReglement != null) {
          notifier.setConditionsReglement(draft.conditionsReglement);
        }
        for (final l in draft.lignes) {
          notifier.ajouterLigne(l);
        }
      });
    }

    // Écoute les changements du formulaire pour la sauvegarde automatique
    _subscription = ref.listenManual(
      documentFormProvider(_key),
      (prev, next) {
        _dernierEtat = next;
        if (next.documentCreeeId != null) {
          _estSoumis = true;
          _timerSauvegarde?.cancel();
          _draftService.supprimerDocument(_draftType);
          return;
        }
        if (!_estSoumis && widget.documentId == null && next.lignes.isNotEmpty) {
          _planifierSauvegarde(next);
        }
      },
    );
  }

  void _planifierSauvegarde(DocumentFormState state) {
    _timerSauvegarde?.cancel();
    _timerSauvegarde = Timer(const Duration(milliseconds: 1500), () {
      _sauvegarderBrouillon(state);
    });
  }

  Future<void> _sauvegarderBrouillon(DocumentFormState state) async {
    if (_estSoumis || widget.documentId != null || state.lignes.isEmpty) return;
    await _draftService.sauvegarderDocument(
      draftType: _draftType,
      clientId: state.clientId,
      clientNom: state.clientNom,
      storeId: state.storeId,
      dateDocument: state.dateDocument,
      remiseGlobalePct: state.remiseGlobalePct,
      appliquerTva: state.appliquerTva,
      tvaGlobalePct: state.tvaGlobalePct,
      notes: state.notes,
      referenceExterne: state.referenceExterne,
      conditionsReglement: state.conditionsReglement,
      lignes: state.lignes.map((l) => l.input).toList(),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    _timerSauvegarde?.cancel();
    final state = _dernierEtat;
    if (!_estSoumis &&
        widget.documentId == null &&
        state != null &&
        state.lignes.isNotEmpty) {
      _draftService.sauvegarderDocument(
        draftType: _draftType,
        clientId: state.clientId,
        clientNom: state.clientNom,
        storeId: state.storeId,
        dateDocument: state.dateDocument,
        remiseGlobalePct: state.remiseGlobalePct,
        appliquerTva: state.appliquerTva,
        tvaGlobalePct: state.tvaGlobalePct,
        notes: state.notes,
        referenceExterne: state.referenceExterne,
        conditionsReglement: state.conditionsReglement,
        lignes: state.lignes.map((l) => l.input).toList(),
      );
    }
    super.dispose();
  }

  void _invaliderTout(int docId) {
    ref.invalidate(proformasProvider);
    ref.invalidate(bonsCommandeProvider);
    ref.invalidate(preparationsLivraisonProvider);
    ref.invalidate(bonsLivraisonProvider);
    ref.invalidate(bonsRetourProvider);
    ref.invalidate(avoirsProvider);
    ref.invalidate(facturesV2Provider);
    ref.invalidate(documentParIdProvider(docId));
  }

  Future<List<ArticleEntity>> _chercherArticles(String query) =>
      ref.read(articleRepositoryProvider).searchArticles(query);

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(documentFormProvider(_key));
    final notifier = ref.read(documentFormProvider(_key).notifier);

    // Navigation automatique après enregistrement réussi
    ref.listen(documentFormProvider(_key), (prev, next) {
      if (next.documentCreeeId != null &&
          prev?.documentCreeeId != next.documentCreeeId) {
        _invaliderTout(next.documentCreeeId!);
        if (widget.documentId == null) {
          context.pushReplacement(
              '${widget.routePrefix}/${next.documentCreeeId}');
        } else {
          if (context.canPop()) context.pop();
        }
      }
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.error!),
              backgroundColor: AppColors.danger),
        );
      }
    });

    // Brut HT = somme des totaux lignes avant remise globale
    final sousTotalHt =
        formState.lignes.fold(0.0, (s, l) => s + l.totaux.totalHt);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.documentId == null
              ? 'Nouveau ${widget.type.libelle}'
              : 'Modifier ${widget.type.libelle}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DocumentHeaderForm(
              clientId: formState.clientId,
              clientNom: formState.clientNom,
              storeId: formState.storeId,
              dateDocument: formState.dateDocument,
              referenceExterne: formState.referenceExterne,
              conditionsReglement: formState.conditionsReglement,
              // Masqués à la création d'une vente comptoir (facture neuve) :
              // inutiles pour une vente rapide, mais toujours visibles en
              // édition ou pour une facture comptabilisée.
              showReference: (widget.type == DocumentType.facture ||
                      widget.type == DocumentType.factureComptabilisee) &&
                  !formState.estVenteComptoirDirecte,
              showConditions: (widget.type == DocumentType.facture ||
                      widget.type == DocumentType.factureComptabilisee) &&
                  !formState.estVenteComptoirDirecte,
              onClientChanged: (id) => notifier.setClient(id, null),
              onStoreChanged: notifier.setStore,
              onDateChanged: notifier.setDate,
              onReferenceChanged: notifier.setReferenceExterne,
              onConditionsChanged: notifier.setConditionsReglement,
            ),
            const SizedBox(height: 24),
            DocumentLinesEditor(
              lignes: formState.lignes,
              onSearchArticle: _chercherArticles,
              onAjouter: (input) =>
                  notifier.ajouterLigne(input, atStart: true),
              onMettreAJour: notifier.mettreAJourLigne,
              onSupprimer: notifier.supprimerLigne,
              articlesRecents: formState.storeId == null
                  ? const []
                  : ref
                          .watch(articlesRecentsProvider(formState.storeId!))
                          .valueOrNull ??
                      const [],
            ),
            const SizedBox(height: 24),
            DocumentTotalsFooter(
              totalHtBrut: sousTotalHt,
              totalHt: formState.totalHt,
              totalTva: formState.totalTva,
              totalTtc: formState.totalTtc,
              remiseGlobalePct: formState.remiseGlobalePct,
              appliquerTva: formState.appliquerTva,
              tvaGlobalePct: formState.tvaGlobalePct,
              onRemiseChanged: notifier.setRemiseGlobale,
              onAppliquerTvaChanged: notifier.setAppliquerTva,
              onTvaChanged: notifier.setTvaGlobale,
            ),
            if (formState.estVenteComptoirDirecte) ...[
              const SizedBox(height: 24),
              SalePaymentSection(
                totalTtc: formState.totalTtc,
                clientSelectionne: formState.clientId != null,
                montantPaye: formState.montantPayeInitial,
                modePaiement: formState.modePaiementInitial,
                onMontantChanged: notifier.setMontantPaye,
                onModeChanged: notifier.setModePaiement,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                if (context.canPop()) context.pop();
              },
              child: const Text('Annuler'),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: formState.estVenteComptoirDirecte
                  ? 'Enregistrer la vente'
                  : 'Enregistrer',
              icon: Icons.save_outlined,
              isLoading: formState.isLoading,
              onPressed: formState.peutEnregistrer && !formState.isLoading
                  ? notifier.sauvegarder
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
