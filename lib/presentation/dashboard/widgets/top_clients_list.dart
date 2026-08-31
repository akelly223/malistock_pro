import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/dashboard_stats.dart';

class TopClientsList extends StatelessWidget {
  final List<TopClientEntity> clients;

  const TopClientsList({super.key, required this.clients});

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
              const Icon(Icons.people_alt_outlined,
                  color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text('Top clients du mois', style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 16),
          if (clients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun client ce mois-ci', style: AppTextStyles.body),
            )
          else
            ...clients.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.clientNom, style: AppTextStyles.bodyBold),
                            Text(
                              '${c.nombreFactures} facture(s)',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(c.totalAchats),
                            style: AppTextStyles.bodyBold
                                .copyWith(color: AppColors.primary),
                          ),
                          if (c.detteTotale > 0)
                            Text(
                              'Dette : ${CurrencyFormatter.format(c.detteTotale)}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.danger),
                            ),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
