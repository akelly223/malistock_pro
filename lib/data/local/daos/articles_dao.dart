import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/articles_table.dart';
import '../tables/categories_table.dart';

part 'articles_dao.g.dart';

@DriftAccessor(tables: [Articles, ArticleStocks, Categories])
class ArticlesDao extends DatabaseAccessor<AppDatabase>
    with _$ArticlesDaoMixin {
  ArticlesDao(super.db);

  Future<List<Article>> getAllArticles() =>
      (select(articles)..where((a) => a.actif.equals(true))).get();

  Future<Article?> getArticleById(int id) =>
      (select(articles)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<Article?> getArticleByCode(String code) =>
      (select(articles)..where((a) => a.code.equals(code)))
          .getSingleOrNull();

  /// Suggestion automatique lors de la saisie : recherche LIKE sur le
  /// nom ou le code, limitée à 5 résultats pour rester rapide et
  /// pertinent (ex: "ri" -> "Riz local", "Riz parfumé", "Riz Gambiaka").
  Future<List<Article>> searchArticles(String query) {
    final likeQuery = '%$query%';
    return (select(articles)
          ..where((a) =>
              a.actif.equals(true) &
              (a.nom.like(likeQuery) | a.code.like(likeQuery)))
          ..limit(5))
        .get();
  }

  /// Articles dont le stock total est inférieur ou égal au seuil minimum.
  Future<List<Article>> getLowStockArticles() => (select(articles)
        ..where((a) =>
            a.actif.equals(true) & a.stockTotal.isSmallerOrEqual(a.stockMinimum)))
      .get();

  Future<int> createArticle(ArticlesCompanion article) =>
      into(articles).insert(article);

  /// Compte les articles existants pour proposer un numéro de code
  /// suivant ; vérifie ensuite qu'il n'est pas déjà pris (cas d'un
  /// code modifié manuellement ou d'un article supprimé) avant de le
  /// retourner.
  Future<String> genererProchainCode() async {
    final count = await (selectOnly(articles)..addColumns([articles.id.count()]))
        .map((row) => row.read(articles.id.count()) ?? 0)
        .getSingle();
    var n = count + 1;
    while (true) {
      final code = 'ART-${n.toString().padLeft(4, '0')}';
      final existant = await getArticleByCode(code);
      if (existant == null) return code;
      n++;
    }
  }

  Future<bool> updateArticle(Article article) =>
      update(articles).replace(article);

  /// Suppression douce : on désactive plutôt que supprimer, afin de
  /// conserver l'historique des factures/devis liés.
  Future<int> deactivateArticle(int id) => (update(articles)
        ..where((a) => a.id.equals(id)))
      .write(const ArticlesCompanion(actif: Value(false)));

  /// Suppression physique définitive, uniquement si l'article n'est
  /// référencé dans aucun document (facture, achat, devis, mouvement
  /// de stock). Ne jamais appeler sans avoir vérifié au préalable
  /// avec [estArticleUtilise].
  Future<void> deleteArticleDefinitivement(int id) async {
    await transaction(() async {
      // Supprime d'abord les lignes de stock associées (pas de FK
      // CASCADE configurée sur article_stocks, donc suppression manuelle).
      await (delete(articleStocks)
            ..where((s) => s.articleId.equals(id)))
          .go();
      await (delete(articles)..where((a) => a.id.equals(id))).go();
    });
  }

  /// Vérifie si un article est référencé dans au moins un document
  /// commercial (facture, achat, devis, mouvement de stock, transfert
  /// de stock). Retourne true dès la première référence trouvée sans
  /// parcourir toutes les tables inutilement.
  Future<bool> estArticleUtilise(int articleId) async {
    final db = attachedDatabase;

    // Lignes de facture.
    final enFacture = await (db.customSelect(
      'SELECT 1 FROM invoice_items WHERE article_id = ? LIMIT 1',
      variables: [Variable.withInt(articleId)],
    )).getSingleOrNull();
    if (enFacture != null) return true;

    // Lignes d'achat.
    final enAchat = await (db.customSelect(
      'SELECT 1 FROM purchase_items WHERE article_id = ? LIMIT 1',
      variables: [Variable.withInt(articleId)],
    )).getSingleOrNull();
    if (enAchat != null) return true;

    // Lignes de devis.
    final enDevis = await (db.customSelect(
      'SELECT 1 FROM quote_items WHERE article_id = ? LIMIT 1',
      variables: [Variable.withInt(articleId)],
    )).getSingleOrNull();
    if (enDevis != null) return true;

    // Mouvements de stock (entrées/sorties manuelles).
    final enMouvement = await (db.customSelect(
      'SELECT 1 FROM stock_movements WHERE article_id = ? LIMIT 1',
      variables: [Variable.withInt(articleId)],
    )).getSingleOrNull();
    if (enMouvement != null) return true;

    // Transferts entre magasins.
    final enTransfert = await (db.customSelect(
      'SELECT 1 FROM stock_transfers WHERE article_id = ? LIMIT 1',
      variables: [Variable.withInt(articleId)],
    )).getSingleOrNull();
    if (enTransfert != null) return true;

    return false;
  }

  // ---- Gestion du stock par magasin ----

  Future<double> getStockForArticleInStore(int articleId, int storeId) async {
    final row = await (select(articleStocks)
          ..where((s) =>
              s.articleId.equals(articleId) & s.storeId.equals(storeId)))
        .getSingleOrNull();
    return row?.quantite ?? 0;
  }

  Future<List<ArticleStock>> getStockRowsForArticle(int articleId) =>
      (select(articleStocks)
            ..where((s) => s.articleId.equals(articleId)))
          .get();

  /// Toutes les lignes de stock d'un magasin, en un seul aller-retour.
  /// Utilisé par le module Inventaire pour capturer le stock théorique
  /// de tout un catalogue sans exécuter une requête par article.
  Future<List<ArticleStock>> getStockRowsForStore(int storeId) =>
      (select(articleStocks)..where((s) => s.storeId.equals(storeId))).get();

  /// Ajuste le stock d'un article dans un magasin (delta positif ou
  /// négatif) puis recalcule le stock total dénormalisé de l'article.
  Future<void> adjustStock({
    required int articleId,
    required int storeId,
    required double delta,
  }) async {
    await transaction(() async {
      final existing = await (select(articleStocks)
            ..where((s) =>
                s.articleId.equals(articleId) & s.storeId.equals(storeId)))
          .getSingleOrNull();

      if (existing == null) {
        await into(articleStocks).insert(ArticleStocksCompanion.insert(
          articleId: articleId,
          storeId: storeId,
          quantite: Value(delta),
        ));
      } else {
        final nouvelleQuantite = existing.quantite + delta;
        await (update(articleStocks)
              ..where((s) => s.id.equals(existing.id)))
            .write(ArticleStocksCompanion(
          quantite: Value(nouvelleQuantite),
        ));
      }

      await _recalculerStockTotal(articleId);
    });
  }

  Future<void> _recalculerStockTotal(int articleId) async {
    final rows = await getStockRowsForArticle(articleId);
    final total = rows.fold<double>(0, (sum, r) => sum + r.quantite);
    await (update(articles)..where((a) => a.id.equals(articleId)))
        .write(ArticlesCompanion(stockTotal: Value(total)));
  }

  // ---- Catégories ----

  Future<List<Category>> getAllCategories() => select(categories).get();

  Future<int> createCategory(CategoriesCompanion category) =>
      into(categories).insert(category);
}
