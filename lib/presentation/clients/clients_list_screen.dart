import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/utils/currency_formatter.dart';
import 'providers/client_provider.dart';

class ClientsListScreen extends ConsumerWidget {
  const ClientsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(filteredClientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppButton(
              label: 'Nouveau client',
              icon: Icons.person_add_alt_rounded,
              onPressed: () => context.push('/clients/new'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un client par nom ou téléphone...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(clientSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline,
                      message: 'Aucun client trouvé.\nAjoutez votre premier client.',
                    );
                  }
                  return ListView.separated(
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
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryLight,
                                  child: Text(
                                    client.nom.isNotEmpty
                                        ? client.nom[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 14),
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
                                if (client.estDebiteur)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Doit ${CurrencyFormatter.format(client.detteTotale)}',
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
