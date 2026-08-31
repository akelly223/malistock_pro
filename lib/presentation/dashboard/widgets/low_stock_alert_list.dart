import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/article.dart';

class LowStockAlertList extends StatelessWidget {
  final List<ArticleEntity> articles;

  const LowStockAlertList({super.key, required this.articles});

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
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text('Alertes de stock', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          if (articles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text('Aucune alerte de stock', style: AppTextStyles.body),
                ],
              ),
            )
          else
            ...articles.take(5).map((a) {
              final estRupture = a.estEnRuptureTotale;
              final couleur = estRupture ? AppColors.danger : AppColors.warning;
              final fond = estRupture
                  ? AppColors.dangerLight
                  : AppColors.warningLight;
              final prefixe = estRupture ? '🚨 Rupture' : '⚠️ Stock faible';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$prefixe : ${a.nom}',
                          style: AppTextStyles.bodyBold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: fond,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${a.stockTotal.toStringAsFixed(0)} restant(s)',
                        style: TextStyle(
                          color: couleur,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (articles.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/alerts'),
              child: const Text('Voir toutes les alertes →'),
            ),
          ],
        ],
      ),
    );
  }
}
