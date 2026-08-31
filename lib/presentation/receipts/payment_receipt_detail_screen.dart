import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/services/pdf_document_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../domain/entities/payment_receipt.dart';
import '../settings/providers/settings_provider.dart';

final paymentReceiptByIdProvider = FutureProvider.autoDispose
    .family<PaymentReceiptEntity?, (String, int)>((ref, key) async {
  final (source, paymentId) = key;
  final repo = ref.watch(receiptRepositoryProvider);
  return repo.getReceiptById(source, paymentId);
});

/// Détail d'un reçu de paiement : tous les champs demandés (numéro,
/// date/heure, type, tiers, facture concernée, montants, mode, agent),
/// avec impression et export PDF.
class PaymentReceiptDetailScreen extends ConsumerStatefulWidget {
  final String source;
  final int paymentId;

  const PaymentReceiptDetailScreen({
    super.key,
    required this.source,
    required this.paymentId,
  });

  @override
  ConsumerState<PaymentReceiptDetailScreen> createState() =>
      _PaymentReceiptDetailScreenState();
}

class _PaymentReceiptDetailScreenState
    extends ConsumerState<PaymentReceiptDetailScreen> {
  bool _isLoading = false;

  Future<void> _imprimer(PaymentReceiptEntity recu) async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      await PdfDocumentService.printReceipt(receipt: recu, settings: settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exporterPdf(PaymentReceiptEntity recu) async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      final path = await PdfDocumentService.generateAndSaveReceipt(
        receipt: recu,
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
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recuAsync = ref.watch(
        paymentReceiptByIdProvider((widget.source, widget.paymentId)));

    return Scaffold(
      appBar: AppBar(title: const Text('Reçu de paiement')),
      body: recuAsync.when(
        data: (recu) {
          if (recu == null) {
            return const Center(child: Text('Reçu introuvable'));
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _RecuBody(recu: recu),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'Imprimer',
                      icon: Icons.print_outlined,
                      isOutlined: true,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _imprimer(recu),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: 'Export PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _exporterPdf(recu),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _RecuBody extends StatelessWidget {
  final PaymentReceiptEntity recu;
  const _RecuBody({required this.recu});

  @override
  Widget build(BuildContext context) {
    final libelleTiers = recu.typePaiement == 'achat' ? 'Fournisseur' : 'Client';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(recu.numeroRecu, style: AppTextStyles.h2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormatter.formatDate(recu.datePaiement),
                      style: AppTextStyles.body),
                  Text(_formatHeure(recu.datePaiement),
                      style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          _Champ(label: libelleTiers, valeur: recu.tiersNom),
          _Champ(label: 'Facture concernée', valeur: recu.numeroDocument),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          _Champ(
              label: 'Montant total de la facture',
              valeur: CurrencyFormatter.format(recu.montantTotalDocument)),
          _Champ(
              label: 'Montant payé avant ce règlement',
              valeur: CurrencyFormatter.format(recu.montantPayeAvant)),
          _Champ(
              label: 'Montant reçu aujourd\'hui',
              valeur: CurrencyFormatter.format(recu.montantRecu),
              gras: true),
          _Champ(
              label: 'Nouveau reste à payer',
              valeur: CurrencyFormatter.format(
                  recu.nouveauReste < 0 ? 0 : recu.nouveauReste),
              gras: true,
              couleur: recu.factureSoldee ? AppColors.success : AppColors.danger),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          _Champ(label: 'Mode de paiement', valeur: _libelleMode(recu.modePaiement)),
          _Champ(label: 'Enregistré par', valeur: recu.utilisateur ?? '—'),
          if (recu.factureSoldee) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'STATUT : FACTURE SOLDÉE',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.success),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatHeure(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _libelleMode(String mode) => switch (mode) {
        'especes' => 'Espèces',
        'cheque' => 'Chèque',
        'virement' => 'Virement',
        'mobile_money' => 'Mobile Money',
        'carte' => 'Carte bancaire',
        'avoir' => 'Avoir',
        'orange_money' => 'Orange Money',
        'moov_money' => 'Moov Money',
        _ => mode,
      };
}

class _Champ extends StatelessWidget {
  final String label;
  final String valeur;
  final bool gras;
  final Color? couleur;

  const _Champ({
    required this.label,
    required this.valeur,
    this.gras = false,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(
            valeur,
            style: (gras ? AppTextStyles.bodyBold : AppTextStyles.body)
                .copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}
