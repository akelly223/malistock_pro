import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/db_constants.dart';
import 'providers/client_provider.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  final int clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientDetailScreen> createState() =>
      _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  Future<void> _enregistrerPaiement(double detteTotale) async {
    final montantController = TextEditingController();
    String modePaiement = DbConstants.paymentEspeces;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Enregistrer un règlement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dette actuelle : ${CurrencyFormatter.format(detteTotale)}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Montant reçu (FCFA)',
                controller: montantController,
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Mode de paiement',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: modePaiement,
                items: const [
                  DropdownMenuItem(
                      value: DbConstants.paymentEspeces, child: Text('Espèces')),
                  DropdownMenuItem(
                      value: DbConstants.paymentOrangeMoney,
                      child: Text('Orange Money')),
                  DropdownMenuItem(
                      value: DbConstants.paymentMoovMoney,
                      child: Text('Moov Money')),
                  DropdownMenuItem(
                      value: DbConstants.paymentVirement,
                      child: Text('Virement')),
                  DropdownMenuItem(
                      value: DbConstants.paymentCheque, child: Text('Chèque')),
                ],
                onChanged: (v) => setStateDialog(() => modePaiement = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Annuler')),
            AppButton(
              label: 'Confirmer',
              onPressed: () => context.pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirme == true) {
      final montant = double.tryParse(montantController.text) ?? 0;
      if (montant <= 0) return;
      final user = ref.read(sessionProvider);
      final repo = ref.read(paymentRepositoryProvider);
      await repo.registerPaymentForClientDebt(
        clientId: widget.clientId,
        montant: montant,
        modePaiement: modePaiement,
        userId: user?.id ?? 0,
      );
      ref.invalidate(clientByIdProvider(widget.clientId));
      ref.invalidate(clientHistoriquePaiementsProvider(widget.clientId));
      ref.invalidate(filteredClientsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Règlement enregistré, reçu généré.'),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () => context.push('/receipts'),
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientByIdProvider(widget.clientId));
    final historiqueAsync =
        ref.watch(clientHistoriqueAchatsProvider(widget.clientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/clients/${widget.clientId}/edit'),
          ),
        ],
      ),
      body: clientAsync.when(
        data: (client) {
          if (client == null) {
            return const Center(child: Text('Client introuvable'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        client.nom.isNotEmpty
                            ? client.nom[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.nom, style: AppTextStyles.h2),
                        if (client.telephone != null)
                          Text(client.telephone!, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: client.estDebiteur
                        ? AppColors.dangerLight
                        : AppColors.successLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        client.estDebiteur
                            ? Icons.account_balance_wallet_rounded
                            : Icons.check_circle_rounded,
                        color: client.estDebiteur
                            ? AppColors.danger
                            : AppColors.success,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client.estDebiteur
                                  ? 'Montant dû'
                                  : 'Aucune dette',
                              style: AppTextStyles.caption,
                            ),
                            Text(
                              CurrencyFormatter.format(client.detteTotale),
                              style: AppTextStyles.h3,
                            ),
                          ],
                        ),
                      ),
                      if (client.estDebiteur)
                        AppButton(
                          label: 'Enregistrer règlement',
                          icon: Icons.payments_outlined,
                          onPressed: () =>
                              _enregistrerPaiement(client.detteTotale),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Historique des achats', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                historiqueAsync.when(
                  data: (factures) {
                    if (factures.isEmpty) {
                      return Text('Aucun achat enregistré.',
                          style: AppTextStyles.caption);
                    }
                    return Column(
                      children: factures
                          .map((f) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(f.numero,
                                              style: AppTextStyles.bodyBold),
                                          Text(
                                              DateFormatter.formatDate(
                                                  f.dateCreation),
                                              style: AppTextStyles.caption),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(f.totalFinal),
                                      style: AppTextStyles.bodyBold,
                                    ),
                                    const SizedBox(width: 10),
                                    _StatutBadge(statut: f.statutPaiement),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => Text('Erreur: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
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
