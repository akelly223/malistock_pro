import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/article.dart';

class DormantArticlesList extends StatelessWidget {
  final List<ArticleEntity> articles;

  const DormantArticlesList({super.key, required this.articles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.snooze_rounded,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Articles dormants (30 j.)', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'En stock mais sans vente depuis 30 jours',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          if (articles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun article dormant', style: AppTextStyles.body),
            )
          else
            ...articles.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.nom, style: AppTextStyles.bodyBold),
                            Text(
                              'Stock : ${a.stockTotal.toStringAsFixed(0)} u.',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                            a.prixVente * a.stockTotal),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
