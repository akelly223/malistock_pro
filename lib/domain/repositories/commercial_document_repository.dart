import '../entities/commercial_document.dart';
import '../entities/document_type.dart';
import '../entities/document_input.dart';

abstract class CommercialDocumentRepository {
  // ── Lecture ───────────────────────────────────────────────────────────────

  Future<List<DocumentEntity>> getParType(DocumentType type);

  /// Liste des ventes (factures + factures comptabilisées), une ligne
  /// par vente : une facture 'transforme' est exclue au profit du
  /// document qui l'a remplacée (comptabilisée ou transformée en chaîne).
  Future<List<DocumentEntity>> getVentes();

  Future<List<DocumentEntity>> getParTypeEtStatut(
      DocumentType type, DocumentStatut statut);

  /// Retourne le document avec ses lignes et paiements.
  Future<DocumentEntity?> getParId(int id);

  Future<List<DocumentEntity>> getParClient(int clientId);

  /// Retourne les documents enfants (issus d'une transformation depuis [parentId]).
  Future<List<DocumentEntity>> getEnfants(int parentId);

  // ── Création / modification ───────────────────────────────────────────────

  /// Crée un nouveau document en statut 'brouillon'.
  /// Retourne l'id du document créé.
  Future<int> creer(DocumentInput input);

  /// Crée une vente comptoir en un seul geste : le document est créé
  /// directement en statut 'valide', le stock est décrémenté (sauf si
  /// [input] provient d'une transformation, càd `parentDocumentId` non
  /// nul — le stock a alors déjà été décrémenté par le document source),
  /// et le paiement initial est enregistré. Réservé à la création directe
  /// d'une facture (pas à la chaîne documentaire Proforma/BC/BL/Avoir).
  /// Lance [StockInsuffisantException] si le stock est insuffisant.
  /// Retourne l'id du document créé.
  Future<int> creerVenteRapide(
    DocumentInput input, {
    required double montantPayeInitial,
    String? modePaiementInitial,
    required int userId,
    required String userNom,
  });

  /// Met à jour les lignes d'un document brouillon.
  /// Lance [DocumentVerrouillException] si le document n'est pas en brouillon.
  Future<void> mettreAJourLignes(
      int docId, List<DocumentLigneInput> lignes, String numero);

  // ── Cycle de vie ──────────────────────────────────────────────────────────

  /// Valide le document (brouillon → valide).
  /// Pour un BL ou BR validé, applique automatiquement l'impact stock.
  Future<void> valider(int id, {required int userId, required String userNom});

  /// Annule le document.
  /// Si un BL validé est annulé, reverse l'impact stock.
  Future<void> annuler(int id,
      {required int userId, required String userNom, required String motif});

  /// Comptabilise une facture validée (facture → facture_comptabilisee).
  Future<void> comptabiliser(int id,
      {required int userId, required String userNom});

  // ── Transformation ────────────────────────────────────────────────────────

  /// Transforme un document validé en pièce de type [cibleType].
  ///
  /// [quantitesParLigneId] permet un BL partiel : map ligneId → quantite.
  /// Si null, toutes les lignes sont reprises à leur quantité originale.
  Future<DocumentEntity> transformer({
    required int sourceId,
    required DocumentType cibleType,
    required int userId,
    required String userNom,
    Map<int, double>? quantitesParLigneId,
  });

  // ── Paiements ─────────────────────────────────────────────────────────────

  Future<void> enregistrerPaiement(
    int docId,
    DocumentPaiementInput paiement, {
    required int userId,
    required String userNom,
  });

  // ── TVA ───────────────────────────────────────────────────────────────────

  Future<List<TvaRateEntity>> getTauxTvaActifs();
}
