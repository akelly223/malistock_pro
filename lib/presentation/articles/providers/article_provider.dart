import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/article.dart';
import '../../../domain/entities/category.dart';

final articlesListProvider =
    FutureProvider.autoDispose<List<ArticleEntity>>((ref) async {
  final repo = ref.watch(articleRepositoryProvider);
  return repo.getAllArticles();
});

final categoriesListProvider =
    FutureProvider.autoDispose<List<CategoryEntity>>((ref) async {
  final repo = ref.watch(articleRepositoryProvider);
  return repo.getAllCategories();
});

/// Recherche en direct pour la barre de recherche de la liste.
final articleSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredArticlesProvider =
    FutureProvider.autoDispose<List<ArticleEntity>>((ref) async {
  final query = ref.watch(articleSearchQueryProvider);
  final repo = ref.watch(articleRepositoryProvider);
  if (query.trim().isEmpty) {
    return repo.getAllArticles();
  }
  return repo.searchArticles(query.trim());
});

/// Suggestions pour l'autocomplete du formulaire article (limité à 5
/// résultats, voir cahier des charges : "ri" -> "Riz local", etc.)
final articleSuggestionsProvider =
    FutureProvider.autoDispose.family<List<ArticleEntity>, String>(
  (ref, query) async {
    if (query.trim().length < 2) return [];
    final repo = ref.watch(articleRepositoryProvider);
    return repo.searchArticles(query.trim());
  },
);

/// Articles récemment vendus dans le magasin sélectionné, pour affichage
/// en raccourcis rapides à la saisie d'une vente.
final articlesRecentsProvider =
    FutureProvider.autoDispose.family<List<ArticleEntity>, int>(
  (ref, storeId) async {
    final repo = ref.watch(articleRepositoryProvider);
    return repo.getArticlesRecents(storeId);
  },
);
