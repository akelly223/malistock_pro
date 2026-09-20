import 'package:drift/drift.dart';
import 'categories_table.dart';
import 'stores_table.dart';

/// Table des articles (produits vendus).
///
/// Le champ [stockTotal] est une valeur dénormalisée recalculée
/// automatiquement (somme des stocks par magasin) pour un affichage
/// rapide dans les listes, sans recalcul à chaque frame.
class Articles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get code => text().withLength(min: 1, max: 50).unique()();

  TextColumn get nom => text().withLength(min: 1, max: 150)();

  IntColumn get categorieId =>
      integer().nullable().references(Categories, #id)();

  RealColumn get prixAchat => real().withDefault(const Constant(0))();

  RealColumn get prixVente => real()();

  /// Stock minimum déclenchant une alerte de rupture.
  RealColumn get stockMinimum => real().withDefault(const Constant(0))();

  /// Stock total dénormalisé (somme article_stock), recalculé à chaque
  /// mouvement de stock.
  RealColumn get stockTotal => real().withDefault(const Constant(0))();

  DateTimeColumn get dateCreation =>
      dateTime().withDefault(currentDateAndTime)();

  BoolColumn get actif => boolean().withDefault(const Constant(true))();

  /// Taux TVA par défaut pré-rempli lors de la saisie d'une ligne (0.0 ou 18.0).
  RealColumn get tauxTvaDefaut => real().withDefault(const Constant(18))();

  /// Description libre optionnelle (notes, détails produit...).
  TextColumn get description => text().nullable()();
}

/// Table de répartition du stock par magasin.
///
/// Permet de gérer plusieurs magasins / dépôts pour un même article
/// (modules Magasins + Transferts de stock).
class ArticleStocks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get articleId => integer().references(Articles, #id)();

  IntColumn get storeId => integer().references(Stores, #id)();

  RealColumn get quantite => real().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {articleId, storeId},
      ];
}
