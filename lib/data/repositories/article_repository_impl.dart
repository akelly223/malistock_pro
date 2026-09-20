import 'package:drift/drift.dart';
import '../local/database.dart';
import '../local/tables/articles_table.dart';
import '../local/tables/categories_table.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/article_repository.dart';

class ArticleRepositoryImpl implements ArticleRepository {
  final AppDatabase db;

  ArticleRepositoryImpl(this.db);

  Future<ArticleEntity> _toEntity(Article a) async {
    String? categorieNom;
    if (a.categorieId != null) {
      final cats = await db.articlesDao.getAllCategories();
      categorieNom = cats
          .firstWhere(
            (c) => c.id == a.categorieId,
            orElse: () => Category(id: -1, nom: ''),
          )
          .nom;
      if (categorieNom != null && categorieNom.isEmpty) categorieNom = null;
    }
    return ArticleEntity(
      id: a.id,
      code: a.code,
      nom: a.nom,
      categorieId: a.categorieId,
      categorieNom: categorieNom,
      prixAchat: a.prixAchat,
      prixVente: a.prixVente,
      stockMinimum: a.stockMinimum,
      stockTotal: a.stockTotal,
      dateCreation: a.dateCreation,
      actif: a.actif,
      tauxTvaDefaut: a.tauxTvaDefaut,
      description: a.description,
    );
  }

  Future<List<ArticleEntity>> _toEntities(List<Article> list) async {
    final cats = await db.articlesDao.getAllCategories();
    final catMap = {for (final c in cats) c.id: c.nom};
    return list
        .map((a) => ArticleEntity(
              id: a.id,
              code: a.code,
              nom: a.nom,
              categorieId: a.categorieId,
              categorieNom:
                  a.categorieId != null ? catMap[a.categorieId] : null,
              prixAchat: a.prixAchat,
              prixVente: a.prixVente,
              stockMinimum: a.stockMinimum,
              stockTotal: a.stockTotal,
              dateCreation: a.dateCreation,
              actif: a.actif,
              tauxTvaDefaut: a.tauxTvaDefaut,
              description: a.description,
            ))
        .toList();
  }

  @override
  Future<List<ArticleEntity>> getAllArticles() async {
    final articles = await db.articlesDao.getAllArticles();
    return _toEntities(articles);
  }

  @override
  Future<ArticleEntity?> getArticleById(int id) async {
    final a = await db.articlesDao.getArticleById(id);
    if (a == null) return null;
    return _toEntity(a);
  }

  @override
  Future<ArticleEntity?> getArticleByCode(String code) async {
    final a = await db.articlesDao.getArticleByCode(code);
    if (a == null) return null;
    return _toEntity(a);
  }

  @override
  Future<List<ArticleEntity>> searchArticles(String query) async {
    final articles = await db.articlesDao.searchArticles(query);
    return _toEntities(articles);
  }

  @override
  Future<List<ArticleEntity>> getLowStockArticles() async {
    final articles = await db.articlesDao.getLowStockArticles();
    return _toEntities(articles);
  }

  @override
  Future<int> createArticle({
    required String code,
    required String nom,
    int? categorieId,
    required double prixAchat,
    required double prixVente,
    required double stockMinimum,
    String? description,
  }) {
    return db.articlesDao.createArticle(ArticlesCompanion.insert(
      code: code,
      nom: nom,
      categorieId: Value(categorieId),
      prixAchat: Value(prixAchat),
      prixVente: prixVente,
      stockMinimum: Value(stockMinimum),
      description: Value(description),
    ));
  }

  @override
  Future<void> updateArticle(ArticleEntity article) async {
    await db.articlesDao.updateArticle(Article(
      id: article.id,
      code: article.code,
      nom: article.nom,
      categorieId: article.categorieId,
      prixAchat: article.prixAchat,
      prixVente: article.prixVente,
      stockMinimum: article.stockMinimum,
      stockTotal: article.stockTotal,
      dateCreation: article.dateCreation,
      actif: article.actif,
      tauxTvaDefaut: 18,
      description: article.description,
    ));
  }

  @override
  Future<String> genererProchainCodeArticle() =>
      db.articlesDao.genererProchainCode();

  @override
  Future<bool> estArticleUtilise(int id) =>
      db.articlesDao.estArticleUtilise(id);

  @override
  Future<SuppressionArticleResult> supprimerOuArchiverArticle(int id) async {
    final utilise = await db.articlesDao.estArticleUtilise(id);
    if (utilise) {
      // Archivage logique : l'article disparaît des listes et des
      // recherches mais reste dans tous les documents historiques.
      await db.articlesDao.deactivateArticle(id);
      return SuppressionArticleResult.archive;
    } else {
      // Aucun document ne référence cet article : suppression physique.
      await db.articlesDao.deleteArticleDefinitivement(id);
      return SuppressionArticleResult.supprime;
    }
  }

  @override
  @Deprecated('Utiliser supprimerOuArchiverArticle à la place')
  Future<void> deleteArticle(int id) async {
    await db.articlesDao.deactivateArticle(id);
  }

  @override
  Future<double> getStockInStore(int articleId, int storeId) =>
      db.articlesDao.getStockForArticleInStore(articleId, storeId);

  @override
  Future<void> adjustStock({
    required int articleId,
    required int storeId,
    required double delta,
  }) =>
      db.articlesDao
          .adjustStock(articleId: articleId, storeId: storeId, delta: delta);

  @override
  Future<List<ArticleEntity>> getArticlesRecents(int storeId,
      {int limit = 8}) async {
    final rows = await db.customSelect(
      '''
      SELECT dl.article_id AS article_id, MAX(cd.date_creation) AS derniere_vente
      FROM document_lines dl
      JOIN commercial_documents cd ON dl.document_id = cd.id
      WHERE cd.type = 'facture' AND cd.statut != 'annule' AND cd.store_id = ?
      GROUP BY dl.article_id
      ORDER BY derniere_vente DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(storeId), Variable.withInt(limit)],
    ).get();

    final articles = <ArticleEntity>[];
    for (final row in rows) {
      final article = await getArticleById(row.data['article_id'] as int);
      if (article != null && article.actif) articles.add(article);
    }
    return articles;
  }

  @override
  Future<List<CategoryEntity>> getAllCategories() async {
    final cats = await db.articlesDao.getAllCategories();
    return cats.map((c) => CategoryEntity(id: c.id, nom: c.nom)).toList();
  }

  @override
  Future<int> createCategory(String nom) =>
      db.articlesDao.createCategory(CategoriesCompanion.insert(nom: nom));
}
