import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/stock_movements_table.dart';
import '../local/tables/stock_transfers_table.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../core/constants/db_constants.dart';

class StockRepositoryImpl implements StockRepository {
  final AppDatabase db;

  StockRepositoryImpl(this.db);

  Future<StockMovementEntity> _toEntity(StockMovement m) async {
    final article = await db.articlesDao.getArticleById(m.articleId);
    final store = await db.storesDao.getStoreById(m.storeId);
    return StockMovementEntity(
      id: m.id,
      articleId: m.articleId,
      articleNom: article?.nom ?? '???',
      articleCode: article?.code ?? '',
      storeId: m.storeId,
      storeNom: store?.nom ?? '???',
      typeMouvement: m.typeMouvement,
      quantite: m.quantite,
      reference: m.reference,
      dateMouvement: m.dateMouvement,
      userId: m.userId,
      groupeId: m.groupeId,
    );
  }

  @override
  Future<List<StockMovementEntity>> getAllMovements() async {
    final list = await db.stockDao.getAllMovements();
    final result = <StockMovementEntity>[];
    for (final m in list) {
      result.add(await _toEntity(m));
    }
    return result;
  }

  @override
  Future<List<StockMovementEntity>> getMovementsForArticle(
      int articleId) async {
    final list = await db.stockDao.getMovementsForArticle(articleId);
    final result = <StockMovementEntity>[];
    for (final m in list) {
      result.add(await _toEntity(m));
    }
    return result;
  }

  @override
  Future<void> registerMovement({
    required int articleId,
    required int storeId,
    required String typeMouvement,
    required double quantite,
    String? reference,
    required int userId,
    String? groupeId,
  }) async {
    await db.transaction(() async {
      await db.stockDao.createMovement(StockMovementsCompanion.insert(
        articleId: articleId,
        storeId: storeId,
        typeMouvement: typeMouvement,
        quantite: quantite,
        reference: Value(reference),
        userId: userId,
        groupeId: Value(groupeId),
      ));

      // Une entrée augmente le stock, tout le reste (sortie, perte,
      // casse) le diminue.
      final delta = typeMouvement == DbConstants.movementEntree
          ? quantite
          : -quantite;
      await db.articlesDao.adjustStock(
        articleId: articleId,
        storeId: storeId,
        delta: delta,
      );
    });
  }

  @override
  Future<List<StockTransferEntity>> getAllTransfers() async {
    final list = await db.stockDao.getAllTransfers();
    final result = <StockTransferEntity>[];
    for (final t in list) {
      final article = await db.articlesDao.getArticleById(t.articleId);
      final storeFrom = await db.storesDao.getStoreById(t.storeFromId);
      final storeTo = await db.storesDao.getStoreById(t.storeToId);
      result.add(StockTransferEntity(
        id: t.id,
        articleId: t.articleId,
        articleNom: article?.nom ?? '???',
        storeFromId: t.storeFromId,
        storeFromNom: storeFrom?.nom ?? '???',
        storeToId: t.storeToId,
        storeToNom: storeTo?.nom ?? '???',
        quantite: t.quantite,
        dateTransfert: t.dateTransfert,
        userId: t.userId,
        statut: t.statut,
      ));
    }
    return result;
  }

  /// Transfère une quantité d'un magasin source vers un magasin
  /// destination : décrémente le stock source, incrémente le stock
  /// destination, et crée deux mouvements de stock liés pour garder
  /// un historique complet et traçable.
  @override
  Future<void> transferStock({
    required int articleId,
    required int storeFromId,
    required int storeToId,
    required double quantite,
    required int userId,
  }) async {
    await db.transaction(() async {
      final stockSource =
          await db.articlesDao.getStockForArticleInStore(articleId, storeFromId);
      if (stockSource < quantite) {
        throw Exception('Stock insuffisant dans le magasin source');
      }

      await db.stockDao.createTransfer(StockTransfersCompanion.insert(
        articleId: articleId,
        storeFromId: storeFromId,
        storeToId: storeToId,
        quantite: quantite,
        userId: userId,
      ));

      await db.articlesDao.adjustStock(
        articleId: articleId,
        storeId: storeFromId,
        delta: -quantite,
      );
      await db.articlesDao.adjustStock(
        articleId: articleId,
        storeId: storeToId,
        delta: quantite,
      );

      await db.stockDao.createMovement(StockMovementsCompanion.insert(
        articleId: articleId,
        storeId: storeFromId,
        typeMouvement: DbConstants.movementTransfert,
        quantite: quantite,
        reference: const Value('Transfert sortant'),
        userId: userId,
      ));
      await db.stockDao.createMovement(StockMovementsCompanion.insert(
        articleId: articleId,
        storeId: storeToId,
        typeMouvement: DbConstants.movementTransfert,
        quantite: quantite,
        reference: const Value('Transfert entrant'),
        userId: userId,
      ));
    });
  }
}
