class StockMovementEntity {
  final int id;
  final int articleId;
  final String articleNom;
  final String articleCode;
  final int storeId;
  final String storeNom;
  final String typeMouvement; // entree|sortie|transfert|perte|casse
  final double quantite;
  final String? reference;
  final DateTime dateMouvement;
  final int userId;

  /// Commun à toutes les lignes créées en une seule fois depuis le
  /// dialogue "Mouvement manuel" — permet de les regrouper dans
  /// l'historique et de régénérer le reçu correspondant après coup.
  final String? groupeId;

  const StockMovementEntity({
    required this.id,
    required this.articleId,
    required this.articleNom,
    required this.articleCode,
    required this.storeId,
    required this.storeNom,
    required this.typeMouvement,
    required this.quantite,
    this.reference,
    required this.dateMouvement,
    required this.userId,
    this.groupeId,
  });
}

class StockTransferEntity {
  final int id;
  final int articleId;
  final String articleNom;
  final int storeFromId;
  final String storeFromNom;
  final int storeToId;
  final String storeToNom;
  final double quantite;
  final DateTime dateTransfert;
  final int userId;
  final String statut;

  const StockTransferEntity({
    required this.id,
    required this.articleId,
    required this.articleNom,
    required this.storeFromId,
    required this.storeFromNom,
    required this.storeToId,
    required this.storeToNom,
    required this.quantite,
    required this.dateTransfert,
    required this.userId,
    required this.statut,
  });
}
