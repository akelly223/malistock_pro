import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/entities/article.dart';
import 'providers/stock_alerts_provider.dart';

class StockAlertsScreen extends ConsumerWidget {
  const StockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(stockAlertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alertes de stock')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: alertsAsync.when(
          data: (articles) {
            if (articles.isEmpty) {
              return const EmptyState(
                icon: Icons.check_circle_outline,
                message:
                    'Tous les stocks sont au-dessus du seuil minimum.\nAucune alerte pour le moment.',
              );
            }

            final ruptures =
                articles.where((a) => a.estEnRuptureTotale).length;
            final faibles = articles.length - ruptures;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (ruptures > 0)
                      Expanded(
                        child: _ResumeCard(
                          icon: Icons.error_rounded,
                          couleur: AppColors.danger,
                          fond: AppColors.dangerLight,
                          titre: 'Ruptures de stock',
                          valeur: '$ruptures article(s)',
                        ),
                      ),
                    if (ruptures > 0 && faibles > 0) const SizedBox(width: 16),
                    if (faibles > 0)
                      Expanded(
                        child: _ResumeCard(
                          icon: Icons.warning_amber_rounded,
                          couleur: AppColors.warning,
                          fond: AppColors.warningLight,
                          titre: 'Stocks faibles',
                          valeur: '$faibles article(s)',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 560) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text('Article',
                                          style: AppTextStyles.bodyBold)),
                                  Expanded(
                                      child: Text('Stock actuel',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.bodyBold)),
                                  Expanded(
                                      child: Text('Stock minimum',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.bodyBold)),
                                  const SizedBox(width: 16),
                                  const SizedBox(width: 220),
                                ],
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: articles.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final article = articles[index];
                              return _AlertRow(
                                article: article,
                                onAcheter: () {
                                  context.push('/purchases/new');
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final Color fond;
  final String titre;
  final String valeur;

  const _ResumeCard({
    required this.icon,
    required this.couleur,
    required this.fond,
    required this.titre,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: couleur, size: 26),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: AppTextStyles.caption),
              Text(valeur,
                  style: AppTextStyles.bodyBold.copyWith(color: couleur)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final ArticleEntity article;
  final VoidCallback onAcheter;

  const _AlertRow({required this.article, required this.onAcheter});

  @override
  Widget build(BuildContext context) {
    final estRupture = article.estEnRuptureTotale;
    final couleur = estRupture ? AppColors.danger : AppColors.warning;

    return LayoutBuilder(
      builder: (context, constraints) {
        // En dessous de cette largeur, le bouton "Acheter maintenant"
        // ne peut plus tenir sur la même ligne que les colonnes de
        // données sans être compressé au point de provoquer un
        // overflow : on bascule alors sur une disposition verticale.
        final estEtroit = constraints.maxWidth < 560;

        final infosArticle = Row(
          children: [
            Icon(
              estRupture ? Icons.error_rounded : Icons.warning_amber_rounded,
              color: couleur,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                article.nom,
                style: AppTextStyles.bodyBold,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        );

        final badgeStock = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${article.stockTotal.toStringAsFixed(0)} en stock',
            style: TextStyle(color: couleur, fontWeight: FontWeight.w700),
          ),
        );

        final stockMinimumLabel = Text(
          'Seuil mini : ${article.stockMinimum.toStringAsFixed(0)}',
          style: AppTextStyles.caption,
        );

        // Bouton en disposition large : largeur minimale garantie pour
        // que le texte ne soit jamais compressé, sans maximum strict
        // qui limiterait inutilement sa taille.
        final boutonLarge = ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
          child: AppButton(
            label: 'Acheter maintenant',
            icon: Icons.shopping_cart_outlined,
            isOutlined: true,
            onPressed: onAcheter,
          ),
        );

        final boutonPleineLargeur = SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Acheter maintenant',
            icon: Icons.shopping_cart_outlined,
            isOutlined: true,
            onPressed: onAcheter,
          ),
        );

        if (estEtroit) {
          // Disposition verticale sur petite largeur : plus aucun
          // risque d'overflow horizontal, chaque élément prend toute
          // la largeur disponible.
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infosArticle,
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [badgeStock, stockMinimumLabel],
                ),
                const SizedBox(height: 12),
                boutonPleineLargeur,
              ],
            ),
          );
        }

        // Disposition large : Expanded pour les colonnes de données,
        // mais le bouton n'est jamais mis dans un Expanded ni dans un
        // SizedBox plus étroit que son contenu minimal — il garde sa
        // taille naturelle, et c'est le Row global qui s'adapte.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: infosArticle),
              Expanded(child: Center(child: badgeStock)),
              Expanded(child: Center(child: stockMinimumLabel)),
              const SizedBox(width: 16),
              boutonLarge,
            ],
          ),
        );
      },
    );
  }
}
