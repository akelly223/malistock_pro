import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/inventory.dart';

/// Bandeau de comptage affiché avant validation (section "Validation"
/// du cahier des charges) : articles contrôlés / sans écart / avec
/// écart / introuvables.
class InventorySummaryBar extends StatelessWidget {
  final InventoryEntity inventaire;
  const InventorySummaryBar({super.key, required this.inventaire});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tuile(
              '${inventaire.nbSansEcart + inventaire.nbAvecEcart}',
              'Contrôlés',
              AppColors.secondary,
              AppColors.secondaryLight,
              Icons.fact_check_rounded),
          const SizedBox(width: 10),
          _tuile('${inventaire.nbSansEcart}', 'Sans écart', AppColors.success,
              AppColors.successLight, Icons.check_circle_rounded),
          const SizedBox(width: 10),
          _tuile('${inventaire.nbAvecEcart}', 'Avec écart', AppColors.warning,
              AppColors.warningLight, Icons.rule_rounded),
          const SizedBox(width: 10),
          _tuile(
              '${inventaire.nbIntrouvables}',
              'Introuvables',
              AppColors.danger,
              AppColors.dangerLight,
              Icons.error_outline_rounded),
        ],
      ),
    );
  }

  Widget _tuile(String valeur, String label, Color couleur, Color fond,
      IconData icone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icone, color: couleur, size: 24),
            const SizedBox(height: 8),
            Text(valeur,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: couleur)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
