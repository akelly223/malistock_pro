/// Représente une ligne saisie par l'utilisateur dans le formulaire
/// d'achat fournisseur, avant calcul et persistance.
///
/// Contrairement à [CartItemInput] (ventes), pas de remise ligne par
/// ligne : un achat fournisseur se négocie globalement, pas article
/// par article (cohérent avec le cahier des charges).
class PurchaseCartItemInput {
  final int articleId;
  final String articleNom;
  final double quantite;
  final double prixAchatUnitaire;

  const PurchaseCartItemInput({
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.prixAchatUnitaire,
  });

  double get totalLigne => quantite * prixAchatUnitaire;
}
