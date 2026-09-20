class SupplierEntity {
  final int id;
  final String nom;
  final String? telephone;
  final String? adresse;
  final DateTime dateCreation;

  /// Reste à payer sur l'ensemble des achats, calculé en direct depuis
  /// `purchases` (pas de colonne dénormalisée, pour ne jamais désynchroniser).
  final double detteTotale;

  const SupplierEntity({
    required this.id,
    required this.nom,
    this.telephone,
    this.adresse,
    required this.dateCreation,
    this.detteTotale = 0,
  });

  bool get estDebiteur => detteTotale > 0.01;
}
