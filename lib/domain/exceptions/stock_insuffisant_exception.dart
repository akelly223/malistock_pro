/// Levée lorsqu'une opération (vente, transfert) tenterait de faire
/// passer le stock d'un article sous zéro. Porte le détail de
/// l'article et des quantités pour permettre un message clair côté
/// interface, plutôt qu'une erreur technique générique.
class StockInsuffisantException implements Exception {
  final String articleNom;
  final double stockDisponible;
  final double quantiteDemandee;

  const StockInsuffisantException({
    required this.articleNom,
    required this.stockDisponible,
    required this.quantiteDemandee,
  });

  @override
  String toString() {
    return 'Stock insuffisant pour "$articleNom" : $stockDisponible disponible(s), '
        '$quantiteDemandee demandé(s).';
  }
}
