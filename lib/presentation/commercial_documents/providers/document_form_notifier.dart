import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/session_provider.dart';
import '../../../domain/entities/document_type.dart';
import '../../../domain/entities/document_input.dart';
import '../../../core/services/tva_calculation_service.dart';
import 'commercial_document_providers.dart';

// ── État du formulaire ───────────────────────────────────────────────────────

/// Ligne dans le formulaire avec son input et ses totaux calculés.
class DocumentLigneFormItem {
  final DocumentLigneInput input;
  final DocumentLineTotals totaux;

  const DocumentLigneFormItem({
    required this.input,
    required this.totaux,
  });

  DocumentLigneFormItem copyWith({
    DocumentLigneInput? input,
    DocumentLineTotals? totaux,
  }) =>
      DocumentLigneFormItem(
        input: input ?? this.input,
        totaux: totaux ?? this.totaux,
      );
}

class DocumentFormState {
  final DocumentType type;
  final int? editDocumentId; // null = nouveau document
  final int? clientId;
  final String? clientNom;
  final int? storeId;
  final DateTime dateDocument;
  final double remiseGlobalePct;

  /// TVA appliquée au niveau du document (pas par ligne).
  final bool appliquerTva;

  /// Taux de TVA global en % (ex : 18.0, 10.0, 5.0). Conservé même
  /// quand [appliquerTva] est false afin de le restaurer si l'utilisateur
  /// re-coche la case.
  final double tvaGlobalePct;

  final List<DocumentLigneFormItem> lignes;
  final String? notes;
  final String? referenceExterne;
  final String? conditionsReglement;
  final bool isLoading;
  final String? error;
  final int? documentCreeeId; // renseigné après enregistrement réussi

  /// Montant payé tel que saisi par le commerçant à la création d'une
  /// vente comptoir. `null` tant qu'il n'y a pas touché : dans ce cas
  /// [montantPayeInitial] suit automatiquement le total TTC (le cas le
  /// plus fréquent — le client paie tout). Ignoré en mode édition et
  /// pour les autres types de document.
  final double? montantPayeSaisi;
  final String modePaiementInitial;

  const DocumentFormState({
    required this.type,
    this.editDocumentId,
    this.clientId,
    this.clientNom,
    this.storeId,
    required this.dateDocument,
    this.remiseGlobalePct = 0,
    this.appliquerTva = false,
    this.tvaGlobalePct = 18.0,
    this.lignes = const [],
    this.notes,
    this.referenceExterne,
    this.conditionsReglement,
    this.isLoading = false,
    this.error,
    this.documentCreeeId,
    this.montantPayeSaisi,
    this.modePaiementInitial = 'especes',
  });

  /// Vrai pour une vente comptoir créée directement (pas via la chaîne
  /// documentaire Proforma/BC/PL/BL/Avoir, pas en édition) : c'est le seul
  /// cas où le paiement est saisi dans ce formulaire.
  bool get estVenteComptoirDirecte =>
      type == DocumentType.facture && editDocumentId == null;

  double get montantPayeInitial => montantPayeSaisi ?? totalTtc;

  // ── Totaux calculés ──────────────────────────────────────────────────────

  double get _sousTotalHt =>
      lignes.fold(0.0, (s, l) => s + l.totaux.totalHt);

  double get facteurRemise => 1 - remiseGlobalePct / 100;

  /// Total HT après remise globale. Les lignes sont calculées sans TVA
  /// (tauxTva=0) : la TVA est appliquée au niveau du document.
  double get totalHt => _arrondir(_sousTotalHt * facteurRemise);

  /// Montant TVA global = Total HT × taux / 100 si [appliquerTva], sinon 0.
  double get totalTva =>
      appliquerTva ? _arrondir(totalHt * tvaGlobalePct / 100) : 0.0;

  double get totalTtc => _arrondir(totalHt + totalTva);

  double _arrondir(double v) => (v * 100).round() / 100;

  bool get peutEnregistrer => lignes.isNotEmpty && storeId != null;

  DocumentFormState copyWith({
    int? clientId,
    String? clientNom,
    bool clearClient = false,
    int? storeId,
    DateTime? dateDocument,
    double? remiseGlobalePct,
    bool? appliquerTva,
    double? tvaGlobalePct,
    List<DocumentLigneFormItem>? lignes,
    String? notes,
    String? referenceExterne,
    String? conditionsReglement,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? documentCreeeId,
    double? montantPayeSaisi,
    String? modePaiementInitial,
  }) =>
      DocumentFormState(
        type: type,
        editDocumentId: editDocumentId,
        clientId: clearClient ? null : (clientId ?? this.clientId),
        clientNom: clearClient ? null : (clientNom ?? this.clientNom),
        storeId: storeId ?? this.storeId,
        dateDocument: dateDocument ?? this.dateDocument,
        remiseGlobalePct: remiseGlobalePct ?? this.remiseGlobalePct,
        appliquerTva: appliquerTva ?? this.appliquerTva,
        tvaGlobalePct: tvaGlobalePct ?? this.tvaGlobalePct,
        lignes: lignes ?? this.lignes,
        notes: notes ?? this.notes,
        referenceExterne: referenceExterne ?? this.referenceExterne,
        conditionsReglement:
            conditionsReglement ?? this.conditionsReglement,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        documentCreeeId: documentCreeeId ?? this.documentCreeeId,
        montantPayeSaisi: montantPayeSaisi ?? this.montantPayeSaisi,
        modePaiementInitial:
            modePaiementInitial ?? this.modePaiementInitial,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class DocumentFormNotifier extends StateNotifier<DocumentFormState> {
  final Ref _ref;
  final _tva = const TVACalculationService();

  DocumentFormNotifier(this._ref, DocumentType type, {int? editDocumentId})
      : super(DocumentFormState(
          type: type,
          editDocumentId: editDocumentId,
          dateDocument: DateTime.now(),
        ));

  void setClient(int? id, String? nom) {
    if (id == null) {
      state = state.copyWith(clearClient: true);
    } else {
      state = state.copyWith(clientId: id, clientNom: nom);
    }
  }

  void setStore(int storeId) =>
      state = state.copyWith(storeId: storeId);

  void setDate(DateTime date) =>
      state = state.copyWith(dateDocument: date);

  void setRemiseGlobale(double pct) =>
      state = state.copyWith(remiseGlobalePct: pct);

  void setAppliquerTva(bool value) =>
      state = state.copyWith(appliquerTva: value);

  /// Met à jour le taux de TVA global (validation effectuée à l'enregistrement).
  void setTvaGlobale(double pct) =>
      state = state.copyWith(tvaGlobalePct: pct);

  void setNotes(String? notes) => state = state.copyWith(notes: notes);

  void setReferenceExterne(String? ref) =>
      state = state.copyWith(referenceExterne: ref);

  void setConditionsReglement(String? cond) =>
      state = state.copyWith(conditionsReglement: cond);

  void setMontantPaye(double montant) =>
      state = state.copyWith(montantPayeSaisi: montant);

  void setModePaiement(String mode) =>
      state = state.copyWith(modePaiementInitial: mode);

  // ── Gestion des lignes ────────────────────────────────────────────────────

  /// [atStart] = true lors d'un ajout par l'utilisateur (nouvel article
  /// → apparaît en haut de la liste). false lors du chargement depuis la
  /// base de données (initState) pour conserver l'ordre original.
  void ajouterLigne(DocumentLigneInput input, {bool atStart = false}) {
    // Les lignes sont toujours calculées sans TVA : tauxTva forcé à 0
    // car la TVA est désormais gérée au niveau du document.
    final ligneHt = input.copyWith(tauxTva: 0);
    final totaux = _tva.calculerLigne(
      quantite: ligneHt.quantite,
      prixUnitaireHt: ligneHt.prixUnitaireHt,
      tauxTva: 0,
      remiseLignePct: ligneHt.remiseLignePct,
    );
    final item = DocumentLigneFormItem(input: ligneHt, totaux: totaux);
    state = state.copyWith(
      lignes: atStart
          ? [item, ...state.lignes]
          : [...state.lignes, item],
      clearError: true,
    );
  }

  void mettreAJourLigne(int index, DocumentLigneInput input) {
    final ligneHt = input.copyWith(tauxTva: 0);
    final totaux = _tva.calculerLigne(
      quantite: ligneHt.quantite,
      prixUnitaireHt: ligneHt.prixUnitaireHt,
      tauxTva: 0,
      remiseLignePct: ligneHt.remiseLignePct,
    );
    final newLignes = [...state.lignes];
    newLignes[index] = DocumentLigneFormItem(input: ligneHt, totaux: totaux);
    state = state.copyWith(lignes: newLignes);
  }

  void supprimerLigne(int index) {
    final newLignes = [...state.lignes]..removeAt(index);
    state = state.copyWith(lignes: newLignes);
  }

  void deplacerLigne(int oldIndex, int newIndex) {
    final newLignes = [...state.lignes];
    final item = newLignes.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newLignes.insert(insertAt, item);
    state = state.copyWith(lignes: newLignes);
  }

  // ── Enregistrement ────────────────────────────────────────────────────────

  Future<void> sauvegarder() async {
    if (!state.peutEnregistrer) return;

    // Validation du taux de TVA
    if (state.appliquerTva) {
      if (state.tvaGlobalePct < 0) {
        state = state.copyWith(
          error: 'Le taux de TVA ne peut pas être négatif.',
        );
        return;
      }
      if (state.tvaGlobalePct > 100) {
        state = state.copyWith(
          error: 'Le taux de TVA ne peut pas dépasser 100 %.',
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = _ref.read(sessionProvider);
      final repo = _ref.read(commercialDocumentRepositoryProvider);

      // Injecter le taux TVA global dans chaque ligne avant l'enregistrement
      // afin que le repository calcule des totaux cohérents.
      final tauxPourLignes = state.appliquerTva ? state.tvaGlobalePct : 0.0;
      final lignesAvecTva = state.lignes
          .map((l) => l.input.copyWith(tauxTva: tauxPourLignes))
          .toList();

      final input = DocumentInput(
        type: state.type,
        storeId: state.storeId!,
        clientId: state.clientId,
        dateDocument: state.dateDocument,
        remiseGlobalePct: state.remiseGlobalePct,
        lignes: lignesAvecTva,
        notes: state.notes,
        referenceExterne: state.referenceExterne,
        conditionsReglement: state.conditionsReglement,
        createdById: session?.id,
        createdByNom: session?.nom,
      );

      if (state.estVenteComptoirDirecte) {
        final id = await repo.creerVenteRapide(
          input,
          montantPayeInitial: state.montantPayeInitial,
          modePaiementInitial: state.modePaiementInitial,
          userId: session?.id ?? 0,
          userNom: session?.nom ?? '',
        );
        state = state.copyWith(isLoading: false, documentCreeeId: id);
      } else if (state.editDocumentId == null) {
        final id = await repo.creer(input);
        state = state.copyWith(isLoading: false, documentCreeeId: id);
      } else {
        await repo.mettreAJourLignes(
          state.editDocumentId!,
          input.lignes,
          '',
        );
        state = state.copyWith(
            isLoading: false, documentCreeeId: state.editDocumentId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ── Provider factory ─────────────────────────────────────────────────────────

/// Fournit un [DocumentFormNotifier] pour un type donné.
/// Paramètre : (DocumentType, int? editId) — utiliser un record.
final documentFormProvider = StateNotifierProvider.autoDispose
    .family<DocumentFormNotifier, DocumentFormState, (DocumentType, int?)>(
  (ref, params) {
    final (type, editId) = params;
    return DocumentFormNotifier(ref, type, editDocumentId: editId);
  },
);
