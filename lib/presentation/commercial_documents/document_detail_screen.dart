import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/permissions/permissions.dart';
import '../../core/services/document_printable_mapper.dart';
import '../../core/services/pdf_document_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/document_action_bar.dart';
import '../../core/widgets/document_history_panel.dart';
import '../../core/widgets/document_payment_panel.dart';
import '../../core/widgets/document_status_badge.dart';
import '../../core/widgets/document_totals_footer.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_input.dart';
import '../../domain/entities/document_type.dart';
import '../../core/widgets/document_transform_dialog.dart';
import '../settings/providers/settings_provider.dart';
import 'documents_list_screen.dart' show routePrefixPourType;
import 'providers/commercial_document_providers.dart';

/// Écran de détail d'un document commercial V2 (toutes pièces confondues).
class DocumentDetailScreen extends ConsumerStatefulWidget {
  final int documentId;
  final String routePrefix;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.routePrefix,
  });

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState
    extends ConsumerState<DocumentDetailScreen> {
  bool _isLoading = false;

  void _invaliderTout() {
    ref.invalidate(proformasProvider);
    ref.invalidate(bonsCommandeProvider);
    ref.invalidate(preparationsLivraisonProvider);
    ref.invalidate(bonsLivraisonProvider);
    ref.invalidate(bonsRetourProvider);
    ref.invalidate(avoirsProvider);
    ref.invalidate(facturesV2Provider);
    ref.invalidate(documentParIdProvider(widget.documentId));
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _valider() async {
    final user = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(commercialDocumentRepositoryProvider).valider(
            widget.documentId,
            userId: user?.id ?? 0,
            userNom: user?.nom ?? '',
          );
      _invaliderTout();
      invalidateStockDependentProviders(ref);
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

  Future<void> _annuler() async {
    final motif = await _demanderMotif();
    if (motif == null || !mounted) return;

    final user = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(commercialDocumentRepositoryProvider).annuler(
            widget.documentId,
            userId: user?.id ?? 0,
            userNom: user?.nom ?? '',
            motif: motif,
          );
      _invaliderTout();
      invalidateStockDependentProviders(ref);
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

  Future<void> _transformer(DocumentType cible, DocumentEntity doc) async {
    // Comptabiliser une facture n'est pas une transformation : c'est le
    // même document (numéro, montant payé, paiements inchangés), seul le
    // type change. On sort donc du chemin générique de transformation qui,
    // lui, crée toujours un nouveau document.
    if (cible == DocumentType.factureComptabilisee) {
      await _comptabiliser(doc);
      return;
    }

    final result = await showDocumentTransformDialog(
      context: context,
      document: doc,
      cibleForcee: cible,
    );
    if (result == null || !mounted) return;

    final user = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      final newDoc =
          await ref.read(commercialDocumentRepositoryProvider).transformer(
                sourceId: widget.documentId,
                cibleType: result.cibleType,
                userId: user?.id ?? 0,
                userNom: user?.nom ?? '',
                quantitesParLigneId: result.quantitesParLigneId,
              );
      _invaliderTout();
      if (mounted) {
        final prefix = routePrefixPourType(result.cibleType);
        context.pushReplacement('$prefix/${newDoc.id}');
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

  Future<void> _comptabiliser(DocumentEntity doc) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comptabiliser cette facture ?'),
        content: Text(
          '${doc.numero} sera marquée comptabilisée. Le client, les articles, '
          'le montant payé et le reste à payer restent identiques — seul le '
          'statut comptable change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Comptabiliser',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    final user = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(commercialDocumentRepositoryProvider).comptabiliser(
            doc.id,
            userId: user?.id ?? 0,
            userNom: user?.nom ?? '',
          );
      _invaliderTout();
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

  Future<void> _enregistrerPaiement(DocumentPaiementInput input) async {
    final user = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(commercialDocumentRepositoryProvider).enregistrerPaiement(
            widget.documentId,
            input,
            userId: user?.id ?? 0,
            userNom: user?.nom ?? '',
          );
      _invaliderTout();
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

  Future<void> _imprimer(DocumentEntity doc) async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      await PdfDocumentService.printDocument(
        document: doc.toPrintableDocument(),
        settings: settings,
      );
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

  Future<void> _exporterPdf(DocumentEntity doc) async {
    setState(() => _isLoading = true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      final path = await PdfDocumentService.generateAndSave(
        document: doc.toPrintableDocument(),
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

  Future<String?> _demanderMotif() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motif d\'annulation'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'Motif *', hintText: 'Ex: Erreur de saisie'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          AppButton(
            label: 'Confirmer',
            isDanger: true,
            onPressed: () {
              final motif = ctrl.text.trim();
              if (motif.isNotEmpty) Navigator.of(context).pop(motif);
            },
          ),
        ],
      ),
    );
  }

  bool _montrerPaiements(DocumentEntity doc) =>
      doc.type == DocumentType.facture ||
      doc.type == DocumentType.factureComptabilisee;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docAsync = ref.watch(documentParIdProvider(widget.documentId));
    final utilisateur = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: docAsync.when(
          data: (doc) => doc != null
              ? Text('${doc.type.libelle} ${doc.numero}')
              : const Text('Document'),
          loading: () => const Text('Chargement…'),
          error: (_, __) => const Text('Erreur'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: docAsync.whenOrNull(
              data: (doc) => doc != null
                  ? DocumentStatusBadge(statut: doc.statut)
                  : null,
            ),
          ),
        ],
      ),
      body: docAsync.when(
        data: (doc) {
          if (doc == null) {
            return const Center(child: Text('Document introuvable'));
          }
          return _DocumentBody(
            doc: doc,
            isLoading: _isLoading,
            routePrefix: widget.routePrefix,
            montrerPaiements: _montrerPaiements(doc),
            onValider: doc.statut == DocumentStatut.brouillon ? _valider : null,
            onEditer: doc.statut.estModifiable &&
                    Permissions.peutModifierDocument(
                        utilisateur, doc.createdById)
                ? () => context.push(
                    '${widget.routePrefix}/${widget.documentId}/edit')
                : null,
            onTransformer: doc.statut == DocumentStatut.valide
                ? (cible) => _transformer(cible, doc)
                : null,
            onAnnuler: doc.statut != DocumentStatut.annule ? _annuler : null,
            onImprimer: () => _imprimer(doc),
            onExporterPdf: () => _exporterPdf(doc),
            onAjouterPaiement: _enregistrerPaiement,
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

// ── Corps du détail ─────────────────────────────────────────────────────────

class _DocumentBody extends StatelessWidget {
  final DocumentEntity doc;
  final bool isLoading;
  final String routePrefix;
  final bool montrerPaiements;
  final VoidCallback? onValider;
  final VoidCallback? onEditer;
  final void Function(DocumentType)? onTransformer;
  final VoidCallback? onAnnuler;
  final VoidCallback? onImprimer;
  final VoidCallback? onExporterPdf;
  final void Function(DocumentPaiementInput) onAjouterPaiement;

  const _DocumentBody({
    required this.doc,
    required this.isLoading,
    required this.routePrefix,
    required this.montrerPaiements,
    required this.onAjouterPaiement,
    this.onValider,
    this.onEditer,
    this.onTransformer,
    this.onAnnuler,
    this.onImprimer,
    this.onExporterPdf,
  });

  double get _brutHt => doc.remiseGlobalePct > 0 && doc.remiseGlobalePct < 100
      ? doc.totalHt / (1.0 - doc.remiseGlobalePct / 100.0)
      : doc.totalHt;

  double get _tvaGlobalePct =>
      doc.lignes.isNotEmpty && doc.totalTva > 0
          ? doc.lignes.first.tauxTva
          : 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfosHeader(doc: doc),
                const SizedBox(height: 24),
                _LignesTable(doc: doc),
                const SizedBox(height: 24),
                DocumentTotalsFooter(
                  totalHtBrut: _brutHt,
                  totalHt: doc.totalHt,
                  totalTva: doc.totalTva,
                  totalTtc: doc.totalTtc,
                  remiseGlobalePct: doc.remiseGlobalePct,
                  tvaGlobalePct: _tvaGlobalePct,
                  appliquerTva: doc.totalTva > 0,
                  montantPaye: montrerPaiements ? doc.montantPaye : null,
                  statutPaiement:
                      montrerPaiements ? doc.statutPaiement : null,
                ),
                if (montrerPaiements) ...[
                  const SizedBox(height: 24),
                  DocumentPaymentPanel(
                    document: doc,
                    peutPayer: doc.statut == DocumentStatut.valide &&
                        !doc.estPaye,
                    isLoading: isLoading,
                    onAjouterPaiement: onAjouterPaiement,
                  ),
                ],
                const SizedBox(height: 24),
                DocumentHistoryPanel(historique: const []),
              ],
            ),
          ),
        ),
        DocumentActionBar(
          document: doc,
          isLoading: isLoading,
          onEditer: onEditer,
          onValider: onValider,
          onTransformer: onTransformer,
          onImprimer: onImprimer,
          onExporterPdf: onExporterPdf,
          onAnnuler: onAnnuler,
        ),
      ],
    );
  }
}

// ── En-tête informations ─────────────────────────────────────────────────────

class _InfosHeader extends StatelessWidget {
  final DocumentEntity doc;
  const _InfosHeader({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Champ(
                  label: 'Numéro',
                  valeur: doc.numero,
                  icon: Icons.tag_rounded,
                ),
              ),
              Expanded(
                child: _Champ(
                  label: 'Date',
                  valeur: DateFormatter.formatDate(doc.dateDocument),
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              Expanded(
                child: _Champ(
                  label: 'Magasin',
                  valeur: doc.storeNom ?? '—',
                  icon: Icons.store_outlined,
                ),
              ),
              if (doc.dateEcheance != null)
                Expanded(
                  child: _Champ(
                    label: 'Échéance',
                    valeur: DateFormatter.formatDate(doc.dateEcheance!),
                    icon: Icons.event_outlined,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  doc.clientId != null
                      ? Icons.person_outline
                      : Icons.storefront_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  doc.clientNom ?? 'Client comptoir',
                  style: AppTextStyles.bodyBold,
                ),
              ],
            ),
          ),
          if (doc.referenceExterne != null) ...[
            const SizedBox(height: 10),
            _Champ(
              label: 'Référence externe',
              valeur: doc.referenceExterne!,
              icon: Icons.label_outline,
            ),
          ],
          if (doc.notes != null) ...[
            const SizedBox(height: 10),
            _Champ(
              label: 'Notes',
              valeur: doc.notes!,
              icon: Icons.notes_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  final String label;
  final String valeur;
  final IconData icon;

  const _Champ(
      {required this.label, required this.valeur, required this.icon});

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
        Text(
          valeur,
          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Tableau des lignes (lecture seule) ───────────────────────────────────────

class _LignesTable extends StatelessWidget {
  final DocumentEntity doc;
  const _LignesTable({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // En-tête
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 4,
                    child: _ColHeader('Désignation')),
                const SizedBox(
                    width: 60, child: _ColHeader('Qté', right: true)),
                const SizedBox(
                    width: 110, child: _ColHeader('Prix HT', right: true)),
                const SizedBox(
                    width: 70, child: _ColHeader('TVA', right: true)),
                const SizedBox(
                    width: 90,
                    child: _ColHeader('Total HT', right: true)),
                const SizedBox(
                    width: 90,
                    child: _ColHeader('Total TTC', right: true)),
              ],
            ),
          ),
          if (doc.lignes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Aucune ligne')),
            )
          else
            ...doc.lignes.asMap().entries.map((e) {
              final i = e.key;
              final l = e.value;
              return Container(
                color: i.isEven ? AppColors.surface : AppColors.background,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.articleNom,
                              style: AppTextStyles.body),
                          Text(l.articleCode,
                              style: AppTextStyles.caption),
                          if (l.remiseLignePct > 0)
                            Text(
                              'Remise ligne: ${l.remiseLignePct.toStringAsFixed(1)}%',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.warning),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        l.quantite.toStringAsFixed(
                            l.quantite == l.quantite.truncate() ? 0 : 2),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.body,
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        CurrencyFormatter.formatSansDevise(l.prixUnitaireHt),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.body,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${l.tauxTva.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        CurrencyFormatter.formatSansDevise(l.totalHt),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.body,
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        CurrencyFormatter.formatSansDevise(l.totalTtc),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyBold,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final bool right;
  const _ColHeader(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
    );
  }
}
