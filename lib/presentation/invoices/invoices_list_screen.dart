import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/db_constants.dart';
import '../../core/permissions/permissions.dart';
import '../../app/providers/session_provider.dart';
import 'providers/invoice_provider.dart';

class InvoicesListScreen extends ConsumerWidget {
  const InvoicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    // Un employé ne voit que ses propres ventes (V1) — même règle que
    // pour les documents V2, voir documents_list_screen.dart.
    final invoicesAsync = ref.watch(invoicesListProvider).whenData((list) =>
        (utilisateur?.estAdmin ?? false)
            ? list
            : list
                .where((i) =>
                    Permissions.peutModifierDocument(utilisateur, i.userId))
                .toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factures'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouvelle vente',
              icon: Icons.add_shopping_cart_rounded,
              onPressed: () => context.push('/invoices/new'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: invoicesAsync.when(
          data: (invoices) {
            if (invoices.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Aucune facture pour l\'instant.\nCréez votre première vente.',
              );
            }
            return ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/invoices/${invoice.id}'),
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
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invoice.numero,
                                    style: AppTextStyles.bodyBold),
                                Text(
                                  '${invoice.clientNom ?? 'Client comptoir'} · ${DateFormatter.formatDate(invoice.dateCreation)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(invoice.totalFinal),
                            style: AppTextStyles.bodyBold,
                          ),
                          const SizedBox(width: 12),
                          _StatutBadge(statut: invoice.statutPaiement),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final String statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (statut) {
      case DbConstants.invoiceStatusPaye:
        color = AppColors.success;
        label = 'Payée';
        break;
      case DbConstants.invoiceStatusPartiel:
        color = AppColors.warning;
        label = 'Partiel';
        break;
      default:
        color = AppColors.danger;
        label = 'Impayée';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
