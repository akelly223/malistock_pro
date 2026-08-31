import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import '../../domain/entities/remise_globale.dart';

/// Bloc récapitulatif Sous-total / Remise / Total, partagé entre
/// Achats, Devis et Ventes pour un affichage strictement identique.
/// Affiche le détail de la remise quand elle est en pourcentage, ex:
/// "Remise : 20% (20 000 FCFA)".
class DiscountSummary extends StatelessWidget {
  final double sousTotal;
  final RemiseGlobale remise;

  const DiscountSummary({
    super.key,
    required this.sousTotal,
    required this.remise,
  });

  @override
  Widget build(BuildContext context) {
    final montantRemise = remise.montantPour(sousTotal);
    final total = sousTotal - montantRemise;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Ligne(label: 'Sous-total', valeur: CurrencyFormatter.format(sousTotal)),
        _Ligne(
          label: 'Remise',
          valeur: remise.type == RemiseType.pourcentage && remise.valeur > 0
              ? '${remise.valeur.clamp(0, 100).toStringAsFixed(0)}% (${CurrencyFormatter.format(montantRemise)})'
              : CurrencyFormatter.format(-montantRemise),
        ),
        const SizedBox(height: 8),
        _Ligne(
          label: 'TOTAL',
          valeur: CurrencyFormatter.format(total),
          isBold: true,
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  final String label;
  final String valeur;
  final bool isBold;

  const _Ligne({
    required this.label,
    required this.valeur,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? AppTextStyles.h3
        : AppTextStyles.body.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Flexible(
            child: Text(
              valeur,
              style: style,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
