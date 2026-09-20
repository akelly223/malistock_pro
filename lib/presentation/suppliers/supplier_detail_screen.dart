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
import '../purchases/providers/purchase_provider.dart';
import 'suppliers_list_screen.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  final int supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
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
                label: 'Montant réglé (FCFA)',
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
      await repo.registerPaymentForSupplierDebt(
        supplierId: widget.supplierId,
        montant: montant,
        modePaiement: modePaiement,
        userId: user?.id ?? 0,
      );
      ref.invalidate(supplierByIdProvider(widget.supplierId));
      ref.invalidate(purchasesForSupplierProvider(widget.supplierId));
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
    final supplierId = widget.supplierId;
    final supplierAsync = ref.watch(supplierByIdProvider(supplierId));
    final purchasesAsync = ref.watch(purchasesForSupplierProvider(supplierId));
    final totalAchatsAsync =
        ref.watch(totalAchatsForSupplierProvider(supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail fournisseur')),
      body: supplierAsync.when(
        data: (supplier) {
          if (supplier == null) {
            return const Center(child: Text('Fournisseur introuvable'));
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
                      backgroundColor: AppColors.secondaryLight,
                      child: Text(
                        supplier.nom.isNotEmpty
                            ? supplier.nom[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.nom, style: AppTextStyles.h2),
                        if (supplier.telephone != null)
                          Text(supplier.telephone!,
                              style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: supplier.estDebiteur
                        ? AppColors.dangerLight
                        : AppColors.successLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        supplier.estDebiteur
                            ? Icons.account_balance_wallet_rounded
                            : Icons.check_circle_rounded,
                        color: supplier.estDebiteur
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
                              supplier.estDebiteur
                                  ? 'Montant dû'
                                  : 'Aucune dette',
                              style: AppTextStyles.caption,
                            ),
                            Text(
                              CurrencyFormatter.format(supplier.detteTotale),
                              style: AppTextStyles.h3,
                            ),
                          ],
                        ),
                      ),
                      if (supplier.estDebiteur)
                        AppButton(
                          label: 'Enregistrer règlement',
                          icon: Icons.payments_outlined,
                          onPressed: () =>
                              _enregistrerPaiement(supplier.detteTotale),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          color: AppColors.primary, size: 28),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total acheté', style: AppTextStyles.caption),
                          totalAchatsAsync.when(
                            data: (total) => Text(
                              CurrencyFormatter.format(total),
                              style: AppTextStyles.h3,
                            ),
                            loading: () => const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (_, __) => const Text('—'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Historique des achats', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                purchasesAsync.when(
                  data: (purchases) {
                    if (purchases.isEmpty) {
                      return const Text('Aucun achat enregistré.',
                          style: AppTextStyles.caption);
                    }
                    return Column(
                      children: purchases
                          .map((p) => Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () =>
                                      context.push('/purchases/${p.id}'),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.numero,
                                                  style:
                                                      AppTextStyles.bodyBold),
                                              Text(
                                                  DateFormatter.formatDate(
                                                      p.dateCreation),
                                                  style:
                                                      AppTextStyles.caption),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(
                                              p.totalFinal),
                                          style: AppTextStyles.bodyBold,
                                        ),
                                        const SizedBox(width: 10),
                                        _StatutBadge(
                                            statut: p.statutPaiement),
                                      ],
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
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
        label = 'Payé';
        break;
      case DbConstants.invoiceStatusPartiel:
        color = AppColors.warning;
        label = 'Partiel';
        break;
      default:
        color = AppColors.danger;
        label = 'Non payé';
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
