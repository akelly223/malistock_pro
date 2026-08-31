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
import '../../core/services/pdf_document_service.dart';
import '../../core/services/purchase_printable_mapper.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/permissions/permissions.dart';
import '../../app/providers/session_provider.dart';
import '../settings/providers/settings_provider.dart';
import 'providers/purchase_provider.dart';

class PurchasesListScreen extends ConsumerStatefulWidget {
  const PurchasesListScreen({super.key});

  @override
  ConsumerState<PurchasesListScreen> createState() =>
      _PurchasesListScreenState();
}

class _PurchasesListScreenState extends ConsumerState<PurchasesListScreen> {
  int? _purchaseIdEnCoursImpression;

  /// Réimprime un achat directement depuis la liste, sans ouvrir
  /// l'écran de détail — pratique pour un fournisseur qui réclame
  /// une copie alors que le commerçant est déjà sur cette page.
  Future<void> _reimprimer(int purchaseId) async {
    setState(() => _purchaseIdEnCoursImpression = purchaseId);
    try {
      final repo = await ref.read(purchaseByIdProvider(purchaseId).future);
      final settings = await ref.read(appSettingsProvider.future);
      if (repo == null) return;

      await PdfDocumentService.printDocument(
        document: repo.toPrintableDocument(),
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _purchaseIdEnCoursImpression = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutGererAchats(utilisateur)) {
      return const AccessDeniedView(titre: 'Achats fournisseurs');
    }

    final purchasesAsync = ref.watch(filteredPurchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats fournisseurs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                AppButton(
                  label: 'Bon de commande',
                  icon: Icons.assignment_outlined,
                  isOutlined: true,
                  onPressed: () =>
                      context.push('/purchases/new?type=commande'),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Nouvel achat',
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: () => context.push('/purchases/new'),
                ),
              ],
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
                hintText: 'Rechercher un achat par numéro...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(purchaseSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: purchasesAsync.when(
                data: (purchases) {
                  if (purchases.isEmpty) {
                    return const EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      message:
                          'Aucun achat enregistré.\nCréez votre premier achat fournisseur.',
                    );
                  }
                  return ListView.separated(
                    itemCount: purchases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final purchase = purchases[index];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              context.push('/purchases/${purchase.id}'),
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
                                    color: AppColors.secondaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                      purchase.estCommande
                                          ? Icons.assignment_outlined
                                          : Icons.local_shipping_rounded,
                                      color: AppColors.secondary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(purchase.numero,
                                          style: AppTextStyles.bodyBold),
                                      Text(
                                        '${purchase.supplierNom ?? 'Fournisseur'} · ${DateFormatter.formatDate(purchase.dateCreation)}',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(purchase.totalFinal),
                                  style: AppTextStyles.bodyBold,
                                ),
                                const SizedBox(width: 12),
                                purchase.estCommande
                                    ? const _CommandeBadge()
                                    : _StatutBadge(
                                        statut: purchase.statutPaiement),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: _purchaseIdEnCoursImpression ==
                                          purchase.id
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.print_outlined),
                                  tooltip: 'Réimprimer',
                                  onPressed: _purchaseIdEnCoursImpression !=
                                          null
                                      ? null
                                      : () => _reimprimer(purchase.id),
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

class _CommandeBadge extends StatelessWidget {
  const _CommandeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Commande',
          style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 12)),
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
