import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/payment_receipt.dart';

final paymentReceiptsProvider =
    FutureProvider.autoDispose<List<PaymentReceiptEntity>>((ref) async {
  final repo = ref.watch(receiptRepositoryProvider);
  return repo.getAllReceipts();
});

/// Historique de tous les paiements enregistrés (ventes et achats,
/// V1 et V2), le plus récent d'abord. Chaque ligne mène au reçu complet
/// (voir/imprimer/exporter).
class PaymentReceiptsListScreen extends ConsumerWidget {
  const PaymentReceiptsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recusAsync = ref.watch(paymentReceiptsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des paiements')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: recusAsync.when(
          data: (recus) {
            if (recus.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Aucun paiement enregistré pour l\'instant.',
              );
            }
            return ListView.separated(
              itemCount: recus.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final recu = recus[index];
                return _RecuCard(
                  recu: recu,
                  onTap: () => context
                      .push('/receipts/${recu.source}/${recu.paymentId}'),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
        ),
      ),
    );
  }
}

class _RecuCard extends StatelessWidget {
  final PaymentReceiptEntity recu;
  final VoidCallback onTap;

  const _RecuCard({required this.recu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estAchat = recu.typePaiement == 'achat';
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: estAchat ? AppColors.warningLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  estAchat ? Icons.shopping_cart_outlined : Icons.point_of_sale_rounded,
                  color: estAchat ? AppColors.warning : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recu.numeroRecu, style: AppTextStyles.bodyBold),
                    Text(
                      '${recu.tiersNom} · Facture ${recu.numeroDocument} · '
                      '${DateFormatter.formatDate(recu.datePaiement)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(recu.montantRecu),
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.success),
                  ),
                  if (recu.factureSoldee)
                    Text('Soldée',
                        style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
