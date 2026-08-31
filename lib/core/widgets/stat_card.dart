import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Carte affichant une statistique clé du dashboard (ventes, bénéfice,
/// nombre de factures...). Grande zone, icône colorée, lisible de loin.
class StatCard extends StatelessWidget {
  final String titre;
  final String valeur;
  final IconData icon;
  final Color color;
  final String? sousTitre;
  final Color? couleurSousTitre;

  const StatCard({
    super.key,
    required this.titre,
    required this.valeur,
    required this.icon,
    this.color = AppColors.primary,
    this.sousTitre,
    this.couleurSousTitre,
  });

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titre,
                  style: AppTextStyles.caption,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(valeur, style: AppTextStyles.statValue),
          if (sousTitre != null) ...[
            const SizedBox(height: 4),
            Text(
              sousTitre!,
              style: AppTextStyles.caption.copyWith(color: couleurSousTitre),
            ),
          ],
        ],
      ),
    );
  }
}
