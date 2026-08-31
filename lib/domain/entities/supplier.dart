class SupplierEntity {
  final int id;
  final String nom;
  final String? telephone;
  final String? adresse;
  final DateTime dateCreation;

  /// Reste à payer sur l'ensemble des achats, calculé en direct depuis
  /// `purchases` (pas de colonne dénormalisée, pour ne jamais désynchroniser).
  final double detteTotale;

  /// Vrai si ce fournisseur est un auteur en dépôt-vente : les articles
  /// qui lui sont liés ne génèrent une dette qu'à la vente, pas à la
  /// réception.
  final bool estDepot;

  /// Pourcentage du prix de vente reversé à l'auteur (0-100), utilisé
  /// uniquement si [estDepot] est vrai.
  final double partAuteurPct;

  const SupplierEntity({
    required this.id,
    required this.nom,
    this.telephone,
    this.adresse,
    required this.dateCreation,
    this.detteTotale = 0,
    this.estDepot = false,
    this.partAuteurPct = 0,
  });

  bool get estDebiteur => detteTotale > 0.01;
}
