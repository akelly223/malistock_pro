import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/entities/client.dart';

final clientsDebiteursProvider =
    FutureProvider.autoDispose<List<ClientEntity>>((ref) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getClientsDebiteurs();
});

class DebtsListScreen extends ConsumerWidget {
  const DebtsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debiteursAsync = ref.watch(clientsDebiteursProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dettes clients')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: debiteursAsync.when(
          data: (clients) {
            if (clients.isEmpty) {
              return const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: 'Aucun client débiteur. Toutes les dettes sont réglées.',
              );
            }
            final totalDettes =
                clients.fold<double>(0, (s, c) => s + c.detteTotale);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: AppColors.danger, size: 28),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total des dettes clients',
                              style: AppTextStyles.caption),
                          Text(CurrencyFormatter.format(totalDettes),
                              style: AppTextStyles.h2),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/clients/${client.id}'),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(client.nom,
                                          style: AppTextStyles.bodyBold),
                                      if (client.telephone != null)
                                        Text(client.telephone!,
                                            style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(client.detteTotale),
                                  style: AppTextStyles.bodyBold
                                      .copyWith(color: AppColors.danger),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
      ),
    );
  }
}
