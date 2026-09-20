import '../entities/article.dart';
import '../entities/category.dart';

/// Résultat d'une tentative de suppression d'article, permettant à
/// l'UI d'afficher le bon message selon ce qui a réellement eu lieu.
enum SuppressionArticleResult {
  /// L'article n'était dans aucun document : supprimé physiquement.
  supprime,

  /// L'article était dans au moins un document : archivé (actif=false)
  /// plutôt que supprimé, pour préserver l'historique.
  archive,
}

abstract class ArticleRepository {
  Future<List<ArticleEntity>> getAllArticles();
  Future<ArticleEntity?> getArticleById(int id);
  Future<ArticleEntity?> getArticleByCode(String code);
  Future<List<ArticleEntity>> searchArticles(String query);
  Future<List<ArticleEntity>> getLowStockArticles();

  /// Articles les plus récemment vendus dans ce magasin (ventes V2), du
  /// plus récent au plus ancien. Sert à afficher des raccourcis rapides
  /// à la saisie d'une vente. Liste vide si aucune vente pour ce magasin.
  Future<List<ArticleEntity>> getArticlesRecents(int storeId, {int limit = 8});
  Future<int> createArticle({
    required String code,
    required String nom,
    int? categorieId,
    required double prixAchat,
    required double prixVente,
    required double stockMinimum,
    String? description,
  });
  Future<void> updateArticle(ArticleEntity article);

  /// Propose le prochain code article disponible (ex: ART-0001), en
  /// évitant tout code déjà utilisé. Sert à pré-remplir la création
  /// rapide sans que l'utilisateur ait à en inventer un.
  Future<String> genererProchainCodeArticle();

  /// Supprime ou archive un article selon qu'il est utilisé dans des
  /// documents existants. Retourne le résultat de l'opération.
  Future<SuppressionArticleResult> supprimerOuArchiverArticle(int id);

  /// Vérifie uniquement si l'article est utilisé (pour afficher une
  /// prévisualisation dans la boîte de confirmation avant action).
  Future<bool> estArticleUtilise(int id);
  Future<double> getStockInStore(int articleId, int storeId);
  Future<void> adjustStock({
    required int articleId,
    required int storeId,
    required double delta,
  });
  Future<List<CategoryEntity>> getAllCategories();
  Future<int> createCategory(String nom);
}
