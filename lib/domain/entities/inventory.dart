class InventoryEntity {
  final int id;
  final String numero;
  final int storeId;
  final String storeNom;
  final int? categorieId;
  final String? categorieNom;
  final String statut; // brouillon|valide|annule
  final DateTime dateCreation;
  final DateTime? dateValidation;
  final int createdByUserId;
  final String? createdByNom;
  final int? validatedByUserId;
  final String? validatedByNom;
  final int nbArticles;
  final int nbSansEcart;
  final int nbAvecEcart;
  final int nbIntrouvables;
  final String? observation;

  const InventoryEntity({
    required this.id,
    required this.numero,
    required this.storeId,
    required this.storeNom,
    this.categorieId,
    this.categorieNom,
    required this.statut,
    required this.dateCreation,
    this.dateValidation,
    required this.createdByUserId,
    this.createdByNom,
    this.validatedByUserId,
    this.validatedByNom,
    required this.nbArticles,
    required this.nbSansEcart,
    required this.nbAvecEcart,
    required this.nbIntrouvables,
    this.observation,
  });

  /// Nombre de lignes pas encore comptées (ni import, ni saisie
  /// manuelle) — utile pour l'affichage du résumé avant validation.
  int get nbNonControles =>
      nbArticles - nbSansEcart - nbAvecEcart - nbIntrouvables;

  bool get estModifiable => statut == 'brouillon';
}

class InventoryLineEntity {
  final int id;
  final int inventoryId;
  final int? articleId;
  final String articleCode;
  final String articleNom;
  final String? categorieNom;
  final double stockTheorique;
  final double? stockPhysique;
  final double? ecart;
  final String? observation;
  final bool introuvable;

  const InventoryLineEntity({
    required this.id,
    required this.inventoryId,
    this.articleId,
    required this.articleCode,
    required this.articleNom,
    this.categorieNom,
    required this.stockTheorique,
    this.stockPhysique,
    this.ecart,
    this.observation,
    required this.introuvable,
  });

  bool get estControle => stockPhysique != null;
  bool get aUnEcart => ecart != null && ecart != 0;
}

/// Une ligne lue depuis le fichier de comptage réimporté par le
/// commerçant (avant rapprochement avec les lignes d'inventaire).
class InventoryCountRow {
  final String code;
  final double stockPhysique;
  final String? observation;

  const InventoryCountRow({
    required this.code,
    required this.stockPhysique,
    this.observation,
  });
}

/// Résumé retourné après un import de comptage, affiché avant
/// validation (section "Validation" du cahier des charges).
class InventoryImportSummary {
  final int lignesMisesAJour;
  final int nouvellesLignes;
  final List<String> codesIntrouvables;

  const InventoryImportSummary({
    required this.lignesMisesAJour,
    required this.nouvellesLignes,
    required this.codesIntrouvables,
  });
}
