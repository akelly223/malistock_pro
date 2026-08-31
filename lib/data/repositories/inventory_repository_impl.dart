import 'package:drift/drift.dart';
import '../local/database.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../core/constants/db_constants.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final AppDatabase db;

  InventoryRepositoryImpl(this.db);

  static String _normaliser(String code) => code.trim().toLowerCase();

  Future<InventoryEntity> _toEntity(
    Inventory i, {
    required Map<int, String> storesParId,
    required Map<int, String> categoriesParId,
    required Map<int, String> usersParId,
  }) async {
    return InventoryEntity(
      id: i.id,
      numero: i.numero,
      storeId: i.storeId,
      storeNom: storesParId[i.storeId] ?? '???',
      categorieId: i.categorieId,
      categorieNom: i.categorieId != null ? categoriesParId[i.categorieId] : null,
      statut: i.statut,
      dateCreation: i.dateCreation,
      dateValidation: i.dateValidation,
      createdByUserId: i.createdByUserId,
      createdByNom: usersParId[i.createdByUserId],
      validatedByUserId: i.validatedByUserId,
      validatedByNom:
          i.validatedByUserId != null ? usersParId[i.validatedByUserId] : null,
      nbArticles: i.nbArticles,
      nbSansEcart: i.nbSansEcart,
      nbAvecEcart: i.nbAvecEcart,
      nbIntrouvables: i.nbIntrouvables,
      observation: i.observation,
    );
  }

  Future<
      ({
        Map<int, String> stores,
        Map<int, String> categories,
        Map<int, String> users,
      })> _chargerLibelles() async {
    final stores = await db.storesDao.getAllStores();
    final categories = await db.articlesDao.getAllCategories();
    final users = await db.usersDao.getAllUsers();
    return (
      stores: {for (final s in stores) s.id: s.nom},
      categories: {for (final c in categories) c.id: c.nom},
      users: {for (final u in users) u.id: u.nom},
    );
  }

  InventoryLineEntity _ligneToEntity(InventoryLine l) => InventoryLineEntity(
        id: l.id,
        inventoryId: l.inventoryId,
        articleId: l.articleId,
        articleCode: l.articleCode,
        articleNom: l.articleNom,
        categorieNom: l.categorieNom,
        stockTheorique: l.stockTheorique,
        stockPhysique: l.stockPhysique,
        ecart: l.ecart,
        observation: l.observation,
        introuvable: l.introuvable,
      );

  @override
  Future<List<InventoryEntity>> getAllInventories() async {
    final libelles = await _chargerLibelles();
    final rows = await db.inventoriesDao.getAllInventories();
    final result = <InventoryEntity>[];
    for (final row in rows) {
      result.add(await _toEntity(
        row,
        storesParId: libelles.stores,
        categoriesParId: libelles.categories,
        usersParId: libelles.users,
      ));
    }
    return result;
  }

  @override
  Future<InventoryEntity?> getInventoryById(int id) async {
    final row = await db.inventoriesDao.getInventoryById(id);
    if (row == null) return null;
    final libelles = await _chargerLibelles();
    return _toEntity(
      row,
      storesParId: libelles.stores,
      categoriesParId: libelles.categories,
      usersParId: libelles.users,
    );
  }

  @override
  Future<List<InventoryLineEntity>> getLines(int inventoryId) async {
    final rows = await db.inventoriesDao.getLinesForInventory(inventoryId);
    return rows.map(_ligneToEntity).toList();
  }

  @override
  Future<int> creerInventaire({
    required int storeId,
    int? categorieId,
    required int userId,
  }) async {
    final tousLesArticles = await db.articlesDao.getAllArticles();
    final articles = categorieId == null
        ? tousLesArticles
        : tousLesArticles.where((a) => a.categorieId == categorieId).toList();

    final stockRows = await db.articlesDao.getStockRowsForStore(storeId);
    final stockParArticle = <int, double>{
      for (final r in stockRows) r.articleId: r.quantite,
    };

    final categories = await db.articlesDao.getAllCategories();
    final nomCategorie = <int, String>{for (final c in categories) c.id: c.nom};

    final numero = await db.documentCountersDao
        .genererProchainNumero(DbConstants.inventoryPrefix);

    return db.transaction(() async {
      final inventoryId = await db.inventoriesDao.insertInventory(
        InventoriesCompanion.insert(
          numero: numero,
          storeId: storeId,
          categorieId: Value(categorieId),
          createdByUserId: userId,
        ),
      );

      final lignes = articles.map((a) {
        final theorique = stockParArticle[a.id] ?? 0;
        return InventoryLinesCompanion.insert(
          inventoryId: inventoryId,
          articleId: Value(a.id),
          articleCode: a.code,
          articleNom: a.nom,
          categorieNom: Value(
              a.categorieId != null ? nomCategorie[a.categorieId] : null),
          stockTheorique: theorique,
        );
      }).toList();

      await db.inventoriesDao.insertLines(lignes);
      await db.inventoriesDao.updateHeaderCounters(
        inventoryId,
        nbArticles: lignes.length,
        nbSansEcart: 0,
        nbAvecEcart: 0,
        nbIntrouvables: 0,
      );

      return inventoryId;
    });
  }

  @override
  Future<InventoryImportSummary> importerComptage({
    required int inventoryId,
    required List<InventoryCountRow> rows,
  }) async {
    final inventory = await db.inventoriesDao.getInventoryById(inventoryId);
    if (inventory == null) throw Exception('Inventaire introuvable');

    final lignesExistantes =
        await db.inventoriesDao.getLinesForInventory(inventoryId);
    final parCode = <String, InventoryLine>{
      for (final l in lignesExistantes) _normaliser(l.articleCode): l,
    };

    final updates = <int, InventoryLinesCompanion>{};
    final nouvellesLignes = <InventoryLinesCompanion>[];
    final introuvables = <String>[];

    for (final row in rows) {
      final ligne = parCode[_normaliser(row.code)];
      if (ligne != null) {
        final ecart = row.stockPhysique - ligne.stockTheorique;
        updates[ligne.id] = InventoryLinesCompanion(
          stockPhysique: Value(row.stockPhysique),
          ecart: Value(ecart),
          observation: Value(row.observation),
          introuvable: const Value(false),
        );
        continue;
      }

      // Code absent des lignes d'origine de l'inventaire : soit un
      // article existant ajouté après l'export (on le rattache),
      // soit un code réellement introuvable (faute de frappe,
      // article supprimé) qui remonte dans le résumé de validation.
      final article = await db.articlesDao.getArticleByCode(row.code);
      if (article != null) {
        final theorique = await db.articlesDao
            .getStockForArticleInStore(article.id, inventory.storeId);
        nouvellesLignes.add(InventoryLinesCompanion.insert(
          inventoryId: inventoryId,
          articleId: Value(article.id),
          articleCode: article.code,
          articleNom: article.nom,
          stockTheorique: theorique,
          stockPhysique: Value(row.stockPhysique),
          ecart: Value(row.stockPhysique - theorique),
          observation: Value(row.observation),
        ));
      } else {
        introuvables.add(row.code);
        nouvellesLignes.add(InventoryLinesCompanion.insert(
          inventoryId: inventoryId,
          articleCode: row.code,
          articleNom: '(Article introuvable)',
          stockTheorique: 0,
          stockPhysique: Value(row.stockPhysique),
          ecart: Value(row.stockPhysique),
          observation: Value(row.observation),
          introuvable: const Value(true),
        ));
      }
    }

    await db.transaction(() async {
      await db.inventoriesDao.updateLinesBatch(updates);
      await db.inventoriesDao.insertLines(nouvellesLignes);
    });

    await _recalculerCompteurs(inventoryId);

    return InventoryImportSummary(
      lignesMisesAJour: updates.length,
      nouvellesLignes: nouvellesLignes.length,
      codesIntrouvables: introuvables,
    );
  }

  @override
  Future<void> corrigerLigne({
    required int lineId,
    double? stockPhysique,
    String? observation,
  }) async {
    final ligne = await db.inventoriesDao.getLineById(lineId);
    if (ligne == null) return;

    await db.inventoriesDao.updateLine(
      lineId,
      InventoryLinesCompanion(
        stockPhysique: stockPhysique != null
            ? Value(stockPhysique)
            : const Value.absent(),
        ecart: stockPhysique != null
            ? Value(stockPhysique - ligne.stockTheorique)
            : const Value.absent(),
        observation:
            observation != null ? Value(observation) : const Value.absent(),
        introuvable: const Value(false),
      ),
    );

    await _recalculerCompteurs(ligne.inventoryId);
  }

  @override
  Future<void> validerInventaire({
    required int inventoryId,
    required int userId,
  }) async {
    final inventory = await db.inventoriesDao.getInventoryById(inventoryId);
    if (inventory == null) throw Exception('Inventaire introuvable');
    if (inventory.statut != DbConstants.inventoryStatusBrouillon) {
      throw Exception('Cet inventaire a déjà été validé ou annulé');
    }

    final lignes = await db.inventoriesDao.getLinesForInventory(inventoryId);

    await db.transaction(() async {
      for (final ligne in lignes) {
        if (ligne.introuvable || ligne.articleId == null) continue;
        final ecart = ligne.ecart;
        if (ecart == null || ecart == 0) continue;

        await db.articlesDao.adjustStock(
          articleId: ligne.articleId!,
          storeId: inventory.storeId,
          delta: ecart,
        );
        await db.stockDao.createMovement(StockMovementsCompanion.insert(
          articleId: ligne.articleId!,
          storeId: inventory.storeId,
          typeMouvement: DbConstants.movementInventaire,
          quantite: ecart,
          reference: Value(inventory.numero),
          userId: userId,
        ));
      }

      await db.inventoriesDao.marquerValide(
        inventoryId,
        validatedByUserId: userId,
        dateValidation: DateTime.now(),
      );
    });
  }

  Future<void> _recalculerCompteurs(int inventoryId) async {
    final lignes = await db.inventoriesDao.getLinesForInventory(inventoryId);
    int sansEcart = 0;
    int avecEcart = 0;
    int introuvables = 0;
    for (final l in lignes) {
      if (l.introuvable) {
        introuvables++;
        continue;
      }
      if (l.stockPhysique == null) continue;
      if ((l.ecart ?? 0) == 0) {
        sansEcart++;
      } else {
        avecEcart++;
      }
    }
    await db.inventoriesDao.updateHeaderCounters(
      inventoryId,
      nbArticles: lignes.length,
      nbSansEcart: sansEcart,
      nbAvecEcart: avecEcart,
      nbIntrouvables: introuvables,
    );
  }
}
