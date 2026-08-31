import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/quote.dart';

final quotesListProvider =
    FutureProvider.autoDispose<List<QuoteEntity>>((ref) async {
  final repo = ref.watch(quoteRepositoryProvider);
  return repo.getAllQuotes();
});

class QuotesListScreen extends ConsumerWidget {
  const QuotesListScreen({super.key});

  Future<void> _convertirEnFacture(
      BuildContext context, WidgetRef ref, QuoteEntity quote) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transformer en facture ?'),
        content: Text(
            'Le devis ${quote.numero} sera transformé en facture sans ressaisie des articles.'),
        actions: [
          TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Annuler')),
          AppButton(
              label: 'Transformer', onPressed: () => context.pop(true)),
        ],
      ),
    );

    if (confirme == true) {
      final user = ref.read(sessionProvider);
      final repo = ref.read(quoteRepositoryProvider);
      final invoiceId = await repo.convertToInvoice(quote.id,
          userId: user?.id ?? 0);
      ref.invalidate(quotesListProvider);
      if (context.mounted) {
        context.push('/invoices/$invoiceId');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devis'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouveau devis',
              icon: Icons.add_rounded,
              onPressed: () => context.push('/quotes/new'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: quotesAsync.when(
          data: (quotes) {
            if (quotes.isEmpty) {
              return const EmptyState(
                icon: Icons.description_outlined,
                message: 'Aucun devis pour l\'instant.',
              );
            }
            return ListView.separated(
              itemCount: quotes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: quote.estConverti
                        ? null
                        : () => context.push('/quotes/${quote.id}/edit'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(quote.numero,
                                    style: AppTextStyles.bodyBold),
                                Text(
                                  '${quote.clientNom ?? 'Sans client'} · ${DateFormatter.formatDate(quote.dateCreation)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(CurrencyFormatter.format(quote.totalFinal),
                              style: AppTextStyles.bodyBold),
                          const SizedBox(width: 16),
                          if (quote.estConverti)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Converti',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Modifier le devis',
                              onPressed: () =>
                                  context.push('/quotes/${quote.id}/edit'),
                            ),
                            AppButton(
                              label: 'Transformer en facture',
                              isOutlined: true,
                              onPressed: () =>
                                  _convertirEnFacture(context, ref, quote),
                            ),
                          ],
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
