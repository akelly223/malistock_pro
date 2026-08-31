import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/dashboard_stats.dart';

class TopProductsList extends StatelessWidget {
  final List<ProduitVenduEntity> produits;

  const TopProductsList({super.key, required this.produits});

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
              const Icon(Icons.star_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text('Produits les plus vendus (mois)', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          if (produits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucune vente ce mois-ci', style: AppTextStyles.body),
            )
          else
            ...produits.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.articleNom, style: AppTextStyles.bodyBold),
                      ),
                      Text(
                        '${p.quantiteVendue.toStringAsFixed(0)} u. · ${CurrencyFormatter.format(p.totalVentes)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
