import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import '../../domain/exceptions/transformation_impossible_exception.dart';

/// Règles du cycle commercial (aucune dépendance à la base de données).
///
/// La règle générale : seul un document VALIDÉ peut être transformé.
/// Un brouillon doit d'abord être validé. Un document transformé ou
/// annulé ne peut plus produire de nouveau document.
class DocumentTransformationService {
  const DocumentTransformationService();

  /// Retourne les types de pièces qu'on peut créer depuis [source].
  List<DocumentType> transformationsPossibles(DocumentEntity source) {
    if (source.statut != DocumentStatut.valide) return [];
    return switch (source.type) {
      DocumentType.proforma => [DocumentType.bonCommande],
      DocumentType.bonCommande => [DocumentType.preparationLivraison, DocumentType.bonLivraison],
      DocumentType.preparationLivraison => [DocumentType.bonLivraison],
      DocumentType.bonLivraison => [DocumentType.facture],
      DocumentType.facture => [DocumentType.factureComptabilisee, DocumentType.bonRetour],
      DocumentType.bonRetour => [DocumentType.avoir],
      _ => [],
    };
  }

  /// Vérifie si la transformation [source] → [cible] est autorisée.
  bool peutTransformer(DocumentEntity source, DocumentType cible) =>
      transformationsPossibles(source).contains(cible);

  /// Lève [TransformationImpossibleException] si la transformation n'est pas
  /// autorisée, ou retourne normalement si elle l'est.
  void validerTransformation(DocumentEntity source, DocumentType cible) {
    if (source.statut != DocumentStatut.valide) {
      throw TransformationImpossibleException(
        sourceNumero: source.numero,
        sourceType: source.type,
        sourceStatut: source.statut,
        cibleType: cible,
        raison: 'Le document doit être validé avant transformation '
            '(statut actuel : ${source.statut.libelle})',
      );
    }
    if (!peutTransformer(source, cible)) {
      throw TransformationImpossibleException(
        sourceNumero: source.numero,
        sourceType: source.type,
        sourceStatut: source.statut,
        cibleType: cible,
      );
    }
  }

  /// Détermine si la transformation est partielle (certaines lignes ont
  /// une quantité réduite par rapport à l'original).
  bool estPartielle(
    DocumentEntity source,
    Map<int, double>? quantitesParLigneId,
  ) {
    if (quantitesParLigneId == null) return false;
    return source.lignes.any((l) {
      final qte = quantitesParLigneId[l.id];
      return qte != null && qte < l.quantite;
    });
  }
}
