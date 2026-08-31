import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/inventories_table.dart';

part 'inventories_dao.g.dart';

/// Accès aux tables du module Inventaire. Reste volontairement limité
/// aux opérations sur ses propres tables — l'orchestration avec
/// Articles/Stock/DocumentCounters se fait dans
/// InventoryRepositoryImpl, comme StockRepositoryImpl le fait déjà
/// pour les transferts de stock.
@DriftAccessor(tables: [Inventories, InventoryLines])
class InventoriesDao extends DatabaseAccessor<AppDatabase>
    with _$InventoriesDaoMixin {
  InventoriesDao(super.db);

  Future<List<Inventory>> getAllInventories() => (select(inventories)
        ..orderBy([(i) => OrderingTerm.desc(i.dateCreation)]))
      .get();

  Future<Inventory?> getInventoryById(int id) =>
      (select(inventories)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<List<InventoryLine>> getLinesForInventory(int inventoryId) =>
      (select(inventoryLines)
            ..where((l) => l.inventoryId.equals(inventoryId))
            ..orderBy([(l) => OrderingTerm.asc(l.articleNom)]))
          .get();

  Future<InventoryLine?> getLineById(int id) =>
      (select(inventoryLines)..where((l) => l.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertInventory(InventoriesCompanion header) =>
      into(inventories).insert(header);

  /// Insertion en masse — un seul batch, essentiel pour ne pas
  /// ralentir la création d'un inventaire sur un catalogue de
  /// plusieurs dizaines de milliers d'articles.
  Future<void> insertLines(List<InventoryLinesCompanion> lines) async {
    if (lines.isEmpty) return;
    await batch((b) => b.insertAll(inventoryLines, lines));
  }

  Future<void> updateLine(int lineId, InventoryLinesCompanion companion) =>
      (update(inventoryLines)..where((l) => l.id.equals(lineId)))
          .write(companion);

  /// Mise à jour en masse (import) — un seul batch de UPDATE
  /// paramétrés plutôt qu'un aller-retour par ligne.
  Future<void> updateLinesBatch(
      Map<int, InventoryLinesCompanion> companionsByLineId) async {
    if (companionsByLineId.isEmpty) return;
    await batch((b) {
      companionsByLineId.forEach((lineId, companion) {
        b.update(inventoryLines, companion,
            where: (tbl) => tbl.id.equals(lineId));
      });
    });
  }

  Future<void> updateHeaderCounters(
    int inventoryId, {
    required int nbArticles,
    required int nbSansEcart,
    required int nbAvecEcart,
    required int nbIntrouvables,
  }) =>
      (update(inventories)..where((i) => i.id.equals(inventoryId))).write(
        InventoriesCompanion(
          nbArticles: Value(nbArticles),
          nbSansEcart: Value(nbSansEcart),
          nbAvecEcart: Value(nbAvecEcart),
          nbIntrouvables: Value(nbIntrouvables),
        ),
      );

  Future<void> marquerValide(
    int inventoryId, {
    required int validatedByUserId,
    required DateTime dateValidation,
  }) =>
      (update(inventories)..where((i) => i.id.equals(inventoryId))).write(
        InventoriesCompanion(
          statut: const Value('valide'),
          validatedByUserId: Value(validatedByUserId),
          dateValidation: Value(dateValidation),
        ),
      );
}
