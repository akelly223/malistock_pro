import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/db_constants.dart';
import '../../core/services/pdf_document_service.dart';
import '../../core/services/purchase_printable_mapper.dart';
import '../settings/providers/settings_provider.dart';
import 'providers/purchase_provider.dart';

/// Écran de détail d'un achat fournisseur, avec export PDF,
/// impression directe et réimpression (action identique à
/// l'impression : un document déjà créé peut être imprimé autant de
/// fois que nécessaire, par exemple en cas de perte du premier
/// exemplaire remis au fournisseur).
class PurchaseDetailScreen extends ConsumerStatefulWidget {
  final int purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  ConsumerState<PurchaseDetailScreen> createState() =>
      _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  bool _isGenerating = false;
  bool _isReceptionEnCours = false;

  /// Réceptionne le bon de commande : le stock est augmenté et le
  /// document passe au statut "reçu". Action irréversible depuis cet
  /// écran (repasser en "commande" nécessiterait une correction
  /// manuelle du stock, comme pour toute autre modification d'achat).
  Future<void> _receptionner() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réceptionner ce bon de commande ?'),
        content: const Text(
          'Le stock du magasin de réception sera augmenté des quantités '
          'commandées et le prix d\'achat de référence des articles sera '
          'mis à jour.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Confirmer la réception',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _isReceptionEnCours = true);
    final user = ref.read(sessionProvider);
    try {
      await ref.read(purchaseRepositoryProvider).receptionnerCommande(
            purchaseId: widget.purchaseId,
            userId: user?.id ?? 0,
          );
      ref.invalidate(purchaseByIdProvider(widget.purchaseId));
      ref.invalidate(filteredPurchasesProvider);
      invalidateStockDependentProviders(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bon de commande réceptionné.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réception : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReceptionEnCours = false);
    }
  }

  Future<void> _exporterPdf() async {
    setState(() => _isGenerating = true);
    try {
      final purchase =
          await ref.read(purchaseByIdProvider(widget.purchaseId).future);
      final settings = await ref.read(appSettingsProvider.future);
      if (purchase == null) return;

      final path = await PdfDocumentService.generateAndSave(
        document: purchase.toPrintableDocument(),
        settings: settings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF enregistré : $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Imprime le document. Utilisée à la fois pour la première
  /// impression et pour la réimpression : aucune différence technique
  /// entre les deux, le document est régénéré à l'identique depuis
  /// les données enregistrées.
  Future<void> _imprimer() async {
    setState(() => _isGenerating = true);
    try {
      final purchase =
          await ref.read(purchaseByIdProvider(widget.purchaseId).future);
      final settings = await ref.read(appSettingsProvider.future);
      if (purchase == null) return;

      await PdfDocumentService.printDocument(
        document: purchase.toPrintableDocument(),
        settings: settings,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutGererAchats(utilisateur)) {
      return const AccessDeniedView(titre: 'Détail achat');
    }

    final purchaseAsync = ref.watch(purchaseByIdProvider(widget.purchaseId));
    final peutModifier = Permissions.peutGererAchats(utilisateur);
    final estCommandeEnAttente =
        purchaseAsync.valueOrNull?.estCommande ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            estCommandeEnAttente ? 'Détail bon de commande' : 'Détail achat'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (peutModifier && estCommandeEnAttente) ...[
                  AppButton(
                    label: 'Marquer reçu',
                    icon: Icons.inventory_2_outlined,
                    isLoading: _isReceptionEnCours,
                    onPressed: _receptionner,
                  ),
                  const SizedBox(width: 10),
                ],
                if (peutModifier) ...[
                  AppButton(
                    label: 'Modifier',
                    icon: Icons.edit_outlined,
                    isOutlined: true,
                    onPressed: () =>
                        context.push('/purchases/${widget.purchaseId}/edit'),
                  ),
                  const SizedBox(width: 10),
                ],
                AppButton(
                  label: 'Imprimer',
                  icon: Icons.print_outlined,
                  isOutlined: true,
                  isLoading: _isGenerating,
                  onPressed: _imprimer,
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Export PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  isLoading: _isGenerating,
                  onPressed: _exporterPdf,
                ),
              ],
            ),
          ),
        ],
      ),
      body: purchaseAsync.when(
        data: (purchase) {
          if (purchase == null) {
            return const Center(child: Text('Achat introuvable'));
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(purchase.numero, style: AppTextStyles.h1),
                              Text(
                                DateFormatter.formatDateTime(
                                    purchase.dateCreation),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                          purchase.estCommande
                              ? const _CommandeBadge()
                              : _StatutBadge(statut: purchase.statutPaiement),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        purchase.supplierNom ?? 'Fournisseur',
                        style: AppTextStyles.bodyBold,
                      ),
                      if (purchase.supplierTelephone != null)
                        Text(purchase.supplierTelephone!,
                            style: AppTextStyles.caption),
                      Text(
                        'Magasin de réception : ${purchase.storeNom ?? '—'}',
                        style: AppTextStyles.caption,
                      ),
                      if (purchase.userNom != null)
                        Text('Enregistré par : ${purchase.userNom}',
                            style: AppTextStyles.caption),
                      // Traçabilité de modification
                      if (purchase.dateModification != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined,
                                  size: 14, color: AppColors.warning),
                              const SizedBox(width: 6),
                              Text(
                                'Modifié le ${DateFormatter.formatDateTime(purchase.dateModification!)}'
                                '${purchase.modifieParNom != null ? ' par ${purchase.modifieParNom}' : ''}',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      ...purchase.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(item.articleNom,
                                      style: AppTextStyles.body),
                                ),
                                Expanded(
                                  child: Text(
                                    '${item.quantite.toStringAsFixed(0)} x ${CurrencyFormatter.formatSansDevise(item.prixAchatUnitaire)}',
                                    style: AppTextStyles.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    CurrencyFormatter.format(item.totalLigne),
                                    style: AppTextStyles.bodyBold,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 32),
                      _TotalLine(label: 'Sous-total', value: purchase.totalHt),
                      _TotalLine(
                          label: 'Remise', value: -purchase.remiseGlobale),
                      const SizedBox(height: 6),
                      _TotalLine(
                        label: 'TOTAL',
                        value: purchase.totalFinal,
                        isBold: true,
                      ),
                      const SizedBox(height: 6),
                      _TotalLine(label: 'Versé', value: purchase.montantPaye),
                      if (purchase.resteAPayer > 0)
                        _TotalLine(
                          label: 'Reste à régler',
                          value: purchase.resteAPayer,
                          color: AppColors.danger,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final Color? color;

  const _TotalLine({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = (isBold ? AppTextStyles.h3 : AppTextStyles.body)
        .copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(CurrencyFormatter.format(value), style: style),
        ],
      ),
    );
  }
}

class _CommandeBadge extends StatelessWidget {
  const _CommandeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Commande en attente',
          style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
