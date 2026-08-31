import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/article.dart';

class ArticleCard extends StatelessWidget {
  final ArticleEntity article;
  final VoidCallback onTap;

  const ArticleCard({super.key, required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: article.enRupture
                      ? AppColors.dangerLight
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: article.enRupture ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.nom, style: AppTextStyles.bodyBold),
                    const SizedBox(height: 2),
                    Text(
                      '${article.code}${article.categorieNom != null ? ' · ${article.categorieNom}' : ''}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(article.prixVente),
                    style: AppTextStyles.bodyBold
                        .copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: article.enRupture
                          ? AppColors.dangerLight
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stock: ${article.stockTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: article.enRupture
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
