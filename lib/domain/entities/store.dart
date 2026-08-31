class StoreEntity {
  final int id;
  final String nom;
  final String? adresse;
  final bool estPrincipal;
  final DateTime dateCreation;

  const StoreEntity({
    required this.id,
    required this.nom,
    this.adresse,
    required this.estPrincipal,
    required this.dateCreation,
  });
}
