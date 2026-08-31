import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import 'providers/article_provider.dart';
import 'widgets/article_card.dart';

class ArticlesListScreen extends ConsumerWidget {
  const ArticlesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(filteredArticlesProvider);
    final utilisateur = ref.watch(sessionProvider);
    final peutGererCatalogue =
        Permissions.peutGererCatalogueArticles(utilisateur);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles'),
        actions: [
          if (peutGererCatalogue) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppButton(
                label: 'Importer',
                icon: Icons.upload_file_rounded,
                isOutlined: true,
                onPressed: () => context.push('/articles/import'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AppButton(
                label: 'Nouvel article',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/articles/new'),
              ),
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un article par nom ou code...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(articleSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: articlesAsync.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'Aucun article trouvé.\nAjoutez votre premier article pour commencer.',
                    );
                  }
                  return ListView.separated(
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return ArticleCard(
                        article: article,
                        onTap: () =>
                            context.push('/articles/${article.id}/edit'),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
