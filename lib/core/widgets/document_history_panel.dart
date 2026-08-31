import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/commercial_document.dart';

/// Panneau d'audit listant le journal d'événements d'un document.
class DocumentHistoryPanel extends StatelessWidget {
  final List<DocumentHistoriqueEntity> historique;

  const DocumentHistoryPanel({super.key, required this.historique});

  static Color _couleurAction(String action) => switch (action) {
        'cree' => AppColors.primary,
        'valide' => AppColors.success,
        'transforme' => AppColors.secondary,
        'annule' => AppColors.danger,
        'paiement_ajoute' => AppColors.success,
        'comptabilise' => AppColors.primaryDark,
        _ => AppColors.textSecondary,
      };

  static IconData _iconeAction(String action) => switch (action) {
        'cree' => Icons.add_circle_outline,
        'modifie' => Icons.edit_outlined,
        'valide' => Icons.check_circle_outline,
        'transforme' => Icons.swap_horiz_rounded,
        'annule' => Icons.cancel_outlined,
        'paiement_ajoute' => Icons.payments_outlined,
        'comptabilise' => Icons.account_balance_outlined,
        _ => Icons.info_outline,
      };

  static String _libelleAction(String action) => switch (action) {
        'cree' => 'Créé',
        'modifie' => 'Modifié',
        'valide' => 'Validé',
        'transforme' => 'Transformé',
        'annule' => 'Annulé',
        'paiement_ajoute' => 'Paiement enregistré',
        'comptabilise' => 'Comptabilisé',
        _ => action,
      };

  @override
  Widget build(BuildContext context) {
    if (historique.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text('Aucun historique disponible',
              style: AppTextStyles.caption),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Historique', style: AppTextStyles.h3),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: historique.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final entry = historique[i];
              final color = _couleurAction(entry.action);
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconeAction(entry.action),
                          size: 18, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _libelleAction(entry.action),
                                style: AppTextStyles.bodyBold,
                              ),
                              if (entry.ancienStatut != null &&
                                  entry.nouveauStatut != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.ancienStatut} → ${entry.nouveauStatut}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ],
                          ),
                          if (entry.description != null) ...[
                            const SizedBox(height: 2),
                            Text(entry.description!,
                                style: AppTextStyles.caption),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormatter.formatDateTime(entry.dateAction),
                          style: AppTextStyles.caption,
                        ),
                        if (entry.userNom != null)
                          Text(
                            entry.userNom!,
                            style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
