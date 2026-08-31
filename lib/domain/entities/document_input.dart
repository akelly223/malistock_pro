import 'document_type.dart';

/// Données d'entrée pour créer une nouvelle pièce commerciale.
class DocumentInput {
  final DocumentType type;
  final int storeId;
  final int? clientId;
  final DateTime dateDocument;
  final double remiseGlobalePct;
  final List<DocumentLigneInput> lignes;
  final String? notes;
  final String? referenceExterne;
  final String? conditionsReglement;
  final int? createdById;
  final String? createdByNom;
  final int? parentDocumentId;

  const DocumentInput({
    required this.type,
    required this.storeId,
    this.clientId,
    required this.dateDocument,
    this.remiseGlobalePct = 0,
    required this.lignes,
    this.notes,
    this.referenceExterne,
    this.conditionsReglement,
    this.createdById,
    this.createdByNom,
    this.parentDocumentId,
  });
}

/// Données d'une ligne de pièce commerciale.
class DocumentLigneInput {
  final int articleId;
  final String articleCode;
  final String articleNom;
  final double quantite;
  final double prixUnitaireHt;
  final double tauxTva;
  final double remiseLignePct;
  final String? notesLigne;

  const DocumentLigneInput({
    required this.articleId,
    required this.articleCode,
    required this.articleNom,
    required this.quantite,
    required this.prixUnitaireHt,
    required this.tauxTva,
    this.remiseLignePct = 0,
    this.notesLigne,
  });

  DocumentLigneInput copyWith({
    int? articleId,
    String? articleCode,
    String? articleNom,
    double? quantite,
    double? prixUnitaireHt,
    double? tauxTva,
    double? remiseLignePct,
    String? notesLigne,
  }) =>
      DocumentLigneInput(
        articleId: articleId ?? this.articleId,
        articleCode: articleCode ?? this.articleCode,
        articleNom: articleNom ?? this.articleNom,
        quantite: quantite ?? this.quantite,
        prixUnitaireHt: prixUnitaireHt ?? this.prixUnitaireHt,
        tauxTva: tauxTva ?? this.tauxTva,
        remiseLignePct: remiseLignePct ?? this.remiseLignePct,
        notesLigne: notesLigne ?? this.notesLigne,
      );
}

/// Données pour enregistrer un paiement sur un document.
class DocumentPaiementInput {
  final double montant;
  final DateTime datePaiement;
  final String modePaiement;
  final String? reference;
  final int? avoirDocumentId;

  const DocumentPaiementInput({
    required this.montant,
    required this.datePaiement,
    required this.modePaiement,
    this.reference,
    this.avoirDocumentId,
  });
}
