/// Représente une ligne saisie par l'utilisateur dans le formulaire
/// devis/facture, avant calcul et persistance.
class CartItemInput {
  final int articleId;
  final String articleNom;
  final double quantite;
  final double prixUnitaire;
  final double remisePourcentage;
  final double remiseMontant;

  const CartItemInput({
    required this.articleId,
    required this.articleNom,
    required this.quantite,
    required this.prixUnitaire,
    this.remisePourcentage = 0,
    this.remiseMontant = 0,
  });

  double get totalLigneBrut => quantite * prixUnitaire;

  double get totalLigne {
    double total = totalLigneBrut;
    if (remisePourcentage > 0) {
      total -= total * (remisePourcentage / 100);
    }
    total -= remiseMontant;
    return total < 0 ? 0 : total;
  }
}
