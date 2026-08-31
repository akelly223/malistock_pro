import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/constants/db_constants.dart';
import '../../core/services/pdf_document_service.dart';
import '../../core/services/invoice_printable_mapper.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/app_settings.dart';
import '../settings/providers/settings_provider.dart';
import 'providers/invoice_provider.dart';

/// Écran de détail facture, conçu pour un commerçant malien peu
/// familier avec l'informatique : toutes les informations utiles
/// (entreprise, client, articles, statut de paiement) sont visibles
/// immédiatement, sans avoir à chercher ou faire défiler.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isGenerating = false;


  Future<void> _exporterPdf() async {
    setState(() => _isGenerating = true);
    try {
      final invoice = await ref.read(invoiceByIdProvider(widget.invoiceId).future);
      final settings = await ref.read(appSettingsProvider.future);
      if (invoice == null) return;

      final path = await PdfDocumentService.generateAndSave(
        document: invoice.toPrintableDocument(),
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

  Future<void> _imprimer() async {
    setState(() => _isGenerating = true);
    try {
      final invoice = await ref.read(invoiceByIdProvider(widget.invoiceId).future);
      final settings = await ref.read(appSettingsProvider.future);
      if (invoice == null) return;

      await PdfDocumentService.printDocument(
        document: invoice.toPrintableDocument(),
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
    final invoiceAsync = ref.watch(invoiceByIdProvider(widget.invoiceId));
    final settingsAsync = ref.watch(appSettingsProvider);
    final utilisateur = ref.watch(sessionProvider);
    final invoiceValue = invoiceAsync.valueOrNull;
    final peutModifier = invoiceValue != null &&
        Permissions.peutModifierDocument(utilisateur, invoiceValue.userId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Détail facture'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (peutModifier) ...[
                  AppButton(
                    label: 'Modifier',
                    icon: Icons.edit_outlined,
                    isOutlined: true,
                    onPressed: () =>
                        context.push('/invoices/${widget.invoiceId}/edit'),
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
      body: invoiceAsync.when(
        data: (invoice) {
          if (invoice == null) {
            return const Center(child: Text('Facture introuvable'));
          }
          return settingsAsync.when(
            data: (settings) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 740),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EnTeteEntreprise(settings: settings),
                        const SizedBox(height: 24),
                        _InfosFacture(invoice: invoice),
                        const SizedBox(height: 16),
                        _InfosClient(invoice: invoice),
                        if (invoice.dateModification != null) ...[
                          const SizedBox(height: 12),
                          _BadgeModification(invoice: invoice),
                        ],
                        const SizedBox(height: 24),
                        _TableauArticles(invoice: invoice),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _InfosImportantes(invoice: invoice)),
                            const SizedBox(width: 24),
                            _Recapitulatif(invoice: invoice),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _PaiementsEffectues(invoiceId: invoice.id),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur paramètres: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

/// Bloc en-tête : identité du commerce, affichée en haut comme sur
/// une vraie facture imprimée.
class _EnTeteEntreprise extends StatelessWidget {
  final AppSettingsEntity settings;

  const _EnTeteEntreprise({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(settings.nomEntreprise, style: AppTextStyles.h1),
              if (settings.telephone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(settings.telephone!, style: AppTextStyles.caption),
                  ],
                ),
              ],
              if (settings.adresse != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(settings.adresse!,
                          style: AppTextStyles.caption),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (settings.logoPath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(settings.logoPath!),
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          )
        else
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: AppColors.primary, size: 28),
          ),
      ],
    );
  }
}

/// Bloc numéro / date / heure / vendeur / magasin — les repères
/// administratifs du document.
class _InfosFacture extends StatelessWidget {
  final InvoiceEntity invoice;

  const _InfosFacture({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FACTURE', style: AppTextStyles.caption),
                Text(invoice.numero,
                    style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          Expanded(
            child: _LigneInfo(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              valeur: DateFormatter.formatDate(invoice.dateCreation),
            ),
          ),
          Expanded(
            child: _LigneInfo(
              icon: Icons.access_time_rounded,
              label: 'Heure',
              valeur: _formatHeure(invoice.dateCreation),
            ),
          ),
          Expanded(
            child: _LigneInfo(
              icon: Icons.badge_outlined,
              label: 'Vendeur',
              valeur: invoice.userNom ?? '—',
            ),
          ),
          Expanded(
            child: _LigneInfo(
              icon: Icons.store_outlined,
              label: 'Magasin',
              valeur: invoice.storeNom ?? '—',
            ),
          ),
        ],
      ),
    );
  }

  static String _formatHeure(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _LigneInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valeur;

  const _LigneInfo(
      {required this.icon, required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 2),
        Text(valeur,
            style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Bloc client : nom, téléphone, adresse, ou "Client comptoir" si
/// vente sans client enregistré.
class _InfosClient extends StatelessWidget {
  final InvoiceEntity invoice;

  const _InfosClient({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final clientNom = invoice.clientNom;
    final estComptoir = clientNom == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            estComptoir ? Icons.storefront_outlined : Icons.person_outline,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estComptoir ? 'Client comptoir' : clientNom,
                  style: AppTextStyles.bodyBold,
                ),
                if (!estComptoir && invoice.clientTelephone != null)
                  Text(invoice.clientTelephone!, style: AppTextStyles.caption),
                if (!estComptoir && invoice.clientAdresse != null)
                  Text(invoice.clientAdresse!, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau Désignation / Qté / PU / Total, lisible et bien espacé.
class _TableauArticles extends StatelessWidget {
  final InvoiceEntity invoice;

  const _TableauArticles({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final items = invoice.items;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Désignation',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary))),
                Expanded(
                    child: Text('Qté',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary))),
                Expanded(
                    flex: 2,
                    child: Text('P.U.',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary))),
                Expanded(
                    flex: 2,
                    child: Text('Total',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary))),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final estPaire = index % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: estPaire ? AppColors.surface : AppColors.background,
              child: Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Text(item.articleNom, style: AppTextStyles.body)),
                  Expanded(
                      child: Text(item.quantite.toStringAsFixed(0),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body)),
                  Expanded(
                      flex: 2,
                      child: Text(
                          CurrencyFormatter.formatSansDevise(item.prixUnitaire),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.body)),
                  Expanded(
                      flex: 2,
                      child: Text(CurrencyFormatter.format(item.totalLigne),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodyBold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Nombre d'articles distincts et quantité totale vendue — repère
/// rapide pour le commerçant sans qu'il ait à compter les lignes.
class _InfosImportantes extends StatelessWidget {
  final InvoiceEntity invoice;

  const _InfosImportantes({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final nbArticles = invoice.items.length;
    final quantiteTotale = invoice.quantiteTotale;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text('Résumé de la vente',
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 10),
          Text('$nbArticles article(s) différent(s)',
              style: AppTextStyles.body),
          const SizedBox(height: 4),
          Text('${quantiteTotale.toStringAsFixed(0)} unité(s) vendue(s) au total',
              style: AppTextStyles.body),
        ],
      ),
    );
  }
}

/// Sous-total / remise / total / payé / reste à payer, avec le badge
/// de statut de paiement bien visible.
class _Recapitulatif extends StatelessWidget {
  final InvoiceEntity invoice;

  const _Recapitulatif({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final resteAPayer = invoice.resteAPayer;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LigneTotal(label: 'Sous-total', valeur: invoice.totalHt),
          _LigneTotal(label: 'Remise', valeur: -invoice.remiseGlobale),
          const Divider(height: 20),
          _LigneTotal(
            label: 'TOTAL TTC',
            valeur: invoice.totalFinal,
            grand: true,
          ),
          const SizedBox(height: 10),
          _LigneTotal(label: 'Montant payé', valeur: invoice.montantPaye),
          if (resteAPayer > 0)
            _LigneTotal(
              label: 'Reste à payer',
              valeur: resteAPayer,
              couleur: AppColors.danger,
              grand: true,
            ),
          const SizedBox(height: 16),
          _BadgeStatutPaiement(statut: invoice.statutPaiement),
        ],
      ),
    );
  }
}

class _LigneTotal extends StatelessWidget {
  final String label;
  final double valeur;
  final bool grand;
  final Color? couleur;

  const _LigneTotal({
    required this.label,
    required this.valeur,
    this.grand = false,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final style = (grand ? AppTextStyles.h3 : AppTextStyles.body)
        .copyWith(color: couleur);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(CurrencyFormatter.format(valeur), style: style),
        ],
      ),
    );
  }
}

class _BadgeModification extends StatelessWidget {
  final InvoiceEntity invoice;
  const _BadgeModification({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined,
              size: 14, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'Modifiée le ${DateFormatter.formatDateTime(invoice.dateModification!)}'
            '${invoice.modifieParNom != null ? ' par ${invoice.modifieParNom}' : ''}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste des reçus émis pour cette facture. Une facture payée
/// intégralement dès la vente n'a aucun reçu (la facture suffit comme
/// preuve) : la section reste alors vide.
class _PaiementsEffectues extends ConsumerWidget {
  final int invoiceId;

  const _PaiementsEffectues({required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paiementsAsync = ref.watch(invoicePaymentsProvider(invoiceId)).whenData(
        (list) => list.where((p) => p.numeroRecu != null).toList());

    return paiementsAsync.when(
      data: (paiements) {
        if (paiements.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text('Paiements effectués', style: AppTextStyles.h3),
              ),
              const Divider(height: 1, color: AppColors.border),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paiements.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) {
                  final paiement = paiements[i];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long_outlined,
                        color: AppColors.primary),
                    title: Text(paiement.numeroRecu!,
                        style: AppTextStyles.bodyBold),
                    subtitle: Text(
                        DateFormatter.formatDate(paiement.datePaiement)),
                    trailing: Text(
                      CurrencyFormatter.format(paiement.montant),
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.success),
                    ),
                    onTap: () => context
                        .push('/receipts/v1_facture/${paiement.id}'),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Badge de statut bien visible, conforme à l'exigence de lisibilité
/// immédiate pour un commerçant peu habitué à l'informatique.
class _BadgeStatutPaiement extends StatelessWidget {
  final String statut;

  const _BadgeStatutPaiement({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color couleur;
    IconData icon;
    String label;
    switch (statut) {
      case DbConstants.invoiceStatusPaye:
        couleur = AppColors.success;
        icon = Icons.check_circle_rounded;
        label = 'PAYÉE';
        break;
      case DbConstants.invoiceStatusPartiel:
        couleur = AppColors.warning;
        icon = Icons.timelapse_rounded;
        label = 'PARTIELLEMENT PAYÉE';
        break;
      default:
        couleur = AppColors.danger;
        icon = Icons.error_rounded;
        label = 'NON PAYÉE';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
