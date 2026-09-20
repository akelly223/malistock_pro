/// Entité article (produit). [stockTotal] est la somme du stock sur
/// tous les magasins, [stockMinimum] déclenche l'alerte de stock faible.
class ArticleEntity {
  final int id;
  final String code;
  final String nom;
  final int? categorieId;
  final String? categorieNom;
  final double prixAchat;
  final double prixVente;
  final double stockMinimum;
  final double stockTotal;
  final DateTime dateCreation;
  final bool actif;
  final double tauxTvaDefaut;

  /// Description libre optionnelle (notes, détails produit...).
  final String? description;

  const ArticleEntity({
    required this.id,
    required this.code,
    required this.nom,
    this.categorieId,
    this.categorieNom,
    required this.prixAchat,
    required this.prixVente,
    required this.stockMinimum,
    required this.stockTotal,
    required this.dateCreation,
    required this.actif,
    this.tauxTvaDefaut = 18,
    this.description,
  });

  /// Stock totalement épuisé (0 unité).
  bool get estEnRuptureTotale => stockTotal <= 0;

  /// Stock sous le seuil minimum mais pas encore épuisé.
  bool get estEnAlerteFaible => !estEnRuptureTotale && stockTotal <= stockMinimum;

  /// Conservé pour compatibilité : vrai dès que le stock atteint ou
  /// passe sous le seuil minimum (faible OU rupture).
  bool get enRupture => stockTotal <= stockMinimum;

  /// Niveau d'alerte : 'rupture' | 'faible' | 'normal'.
  String get niveauAlerte {
    if (estEnRuptureTotale) return 'rupture';
    if (estEnAlerteFaible) return 'faible';
    return 'normal';
  }

  double get margeUnitaire => prixVente - prixAchat;
}
