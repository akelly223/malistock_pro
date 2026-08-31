import '../entities/stock_movement.dart';

abstract class StockRepository {
  Future<List<StockMovementEntity>> getAllMovements();
  Future<List<StockMovementEntity>> getMovementsForArticle(int articleId);

  Future<void> registerMovement({
    required int articleId,
    required int storeId,
    required String typeMouvement,
    required double quantite,
    String? reference,
    required int userId,
    String? groupeId,
  });

  Future<List<StockTransferEntity>> getAllTransfers();

  /// Transfère une quantité d'un article entre deux magasins. Met à
  /// jour le stock des deux magasins et crée les mouvements associés.
  Future<void> transferStock({
    required int articleId,
    required int storeFromId,
    required int storeToId,
    required double quantite,
    required int userId,
  });
}
