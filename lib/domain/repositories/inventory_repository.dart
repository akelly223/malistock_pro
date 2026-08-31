import '../entities/inventory.dart';

abstract class InventoryRepository {
  Future<List<InventoryEntity>> getAllInventories();

  Future<InventoryEntity?> getInventoryById(int id);

  Future<List<InventoryLineEntity>> getLines(int inventoryId);

  /// Crée un inventaire brouillon : capture le stock théorique de
  /// tous les articles actifs du magasin choisi (filtrés par
  /// catégorie si fournie) et retourne l'id créé.
  Future<int> creerInventaire({
    required int storeId,
    int? categorieId,
    required int userId,
  });

  /// Rapproche les lignes lues dans le fichier réimporté avec les
  /// lignes de l'inventaire par code article, calcule les écarts.
  Future<InventoryImportSummary> importerComptage({
    required int inventoryId,
    required List<InventoryCountRow> rows,
  });

  /// Correction manuelle d'une seule ligne (saisie directe à l'écran,
  /// en complément de l'import de fichier).
  Future<void> corrigerLigne({
    required int lineId,
    double? stockPhysique,
    String? observation,
  });

  /// Verrouille l'inventaire, met à jour le stock des articles en
  /// écart et enregistre un mouvement de stock "inventaire" par
  /// article corrigé (historique).
  Future<void> validerInventaire({
    required int inventoryId,
    required int userId,
  });
}
