import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/currency_formatter.dart';
import 'document_payment_panel.dart' show documentPaymentModes;

/// Bloc de paiement affiché à la création d'une vente comptoir (facture
/// V2 créée directement, hors chaîne documentaire) : le commerçant saisit
/// le montant reçu en même temps que les articles, sans étape séparée.
///
/// Le montant payé est pré-rempli avec le total TTC (cas le plus
/// fréquent : le client paie tout). Le reste à payer se recalcule en
/// direct et devient une dette automatique si un client est sélectionné.
class SalePaymentSection extends StatefulWidget {
  final double totalTtc;
  final bool clientSelectionne;
  final double montantPaye;
  final String modePaiement;
  final ValueChanged<double> onMontantChanged;
  final ValueChanged<String> onModeChanged;

  const SalePaymentSection({
    super.key,
    required this.totalTtc,
    required this.clientSelectionne,
    required this.montantPaye,
    required this.modePaiement,
    required this.onMontantChanged,
    required this.onModeChanged,
  });

  @override
  State<SalePaymentSection> createState() => _SalePaymentSectionState();
}

class _SalePaymentSectionState extends State<SalePaymentSection> {
  late final TextEditingController _montantCtrl;

  @override
  void initState() {
    super.initState();
    _montantCtrl =
        TextEditingController(text: widget.montantPaye.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(SalePaymentSection old) {
    super.didUpdateWidget(old);
    // Si le total change (article ajouté/retiré) alors que le commerçant
    // n'a pas encore touché au montant payé, on le garde synchronisé sur
    // le total — dès qu'il modifie le champ à la main, ce recalage
    // automatique s'arrête (le montant saisi devient prioritaire tant que
    // le widget n'est pas reconstruit avec une nouvelle valeur explicite).
    final saisieActuelle = double.tryParse(_montantCtrl.text) ?? 0;
    if (saisieActuelle != widget.montantPaye) {
      _montantCtrl.text = widget.montantPaye.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resteAPayer = widget.totalTtc - widget.montantPaye;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Paiement', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _montantCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Montant payé',
                    prefixText: 'FCFA ',
                  ),
                  onChanged: (v) =>
                      widget.onMontantChanged(double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: widget.modePaiement,
                  decoration: const InputDecoration(labelText: 'Mode de paiement'),
                  items: documentPaymentModes
                      .map((m) => DropdownMenuItem(
                            value: m.$1,
                            child: Text(m.$2),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) widget.onModeChanged(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reste à payer', style: AppTextStyles.bodyBold),
              Text(
                CurrencyFormatter.format(resteAPayer < 0 ? 0 : resteAPayer),
                style: AppTextStyles.h3.copyWith(
                  color: resteAPayer > 0.01
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ),
            ],
          ),
          if (resteAPayer > 0.01 && !widget.clientSelectionne) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Astuce : pour suivre une dette, sélectionnez un client avant de valider.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
