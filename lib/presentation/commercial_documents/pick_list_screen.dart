import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/stock_invalidation.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/document_action_bar.dart';
import '../../core/widgets/document_status_badge.dart';
import '../../core/widgets/document_transform_dialog.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/commercial_document.dart';
import '../../domain/entities/document_type.dart';
import 'documents_list_screen.dart' show routePrefixPourType;
import 'providers/commercial_document_providers.dart';

/// Écran de picking pour une Préparation de livraison.
///
/// Affiche chaque ligne du document comme une case à cocher.
/// La progression locale (cochée / total) guide le préparateur.
/// Une fois toutes les lignes prêtes, le bouton "Créer BL" devient
/// accessible via [DocumentActionBar].
class PickListScreen extends ConsumerStatefulWidget {
  final int documentId;

  const PickListScreen({super.key, required this.documentId});

  @override
  ConsumerState<PickListScreen> createState() => _PickListScreenState();
}

class _PickListScreenState extends ConsumerState<PickListScreen> {
  final Set<int> _lignesPretes = {};
  bool _isLoading = false;

  void _invaliderProviders() {
    ref.invalidate(preparationsLivraisonProvider);
    ref.invalidate(bonsLivraisonProvider);
    ref.invalidate(documentParIdProvider(widget.documentId));
  }

  Future<void> _valider() async {
    final session = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(commercialDocumentRepositoryProvider).valider(
            widget.documentId,
            userId: session?.id ?? 0,
            userNom: session?.nom ?? '',
          );
      _invaliderProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _annuler() async {
    final motifCtrl = TextEditingController();
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler cette préparation ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cette action est irréversible.'),
            const SizedBox(height: 16),
            TextField(
              controller: motifCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif (optionnel)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    final motif = motifCtrl.text.trim();
    motifCtrl.dispose();
    if (confirmer != true || !mounted) return;
    final session = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(commercialDocumentRepositoryProvider).annuler(
            widget.documentId,
            userId: session?.id ?? 0,
            userNom: session?.nom ?? '',
            motif: motif.isNotEmpty ? motif : 'Annulation',
          );
      _invaliderProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _transformer(DocumentType cible, DocumentEntity doc) async {
    final result = await showDocumentTransformDialog(
      context: context,
      document: doc,
      cibleForcee: cible,
    );
    if (result == null || !mounted) return;
    final session = ref.read(sessionProvider);
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(commercialDocumentRepositoryProvider);
      final newDoc = await repo.transformer(
        sourceId: widget.documentId,
        cibleType: result.cibleType,
        userId: session?.id ?? 0,
        userNom: session?.nom ?? '',
        quantitesParLigneId: result.quantitesParLigneId,
      );
      _invaliderProviders();
      invalidateStockDependentProviders(ref);
      if (mounted) {
        final prefix = routePrefixPourType(result.cibleType);
        context.pushReplacement('$prefix/${newDoc.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docAsync = ref.watch(documentParIdProvider(widget.documentId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: docAsync.when(
        data: (doc) {
          if (doc == null) {
            return const Center(child: Text('Document introuvable'));
          }

          final total = doc.lignes.length;
          final nbPretes = _lignesPretes.length;
          final progression = total > 0 ? nbPretes / total : 0.0;
          final toutPretes = nbPretes == total && total > 0;

          return Column(
            children: [
              // ── En-tête ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
                color: AppColors.surface,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Préparation ${doc.numero}',
                                  style: AppTextStyles.h2),
                              const SizedBox(width: 12),
                              DocumentStatusBadge(statut: doc.statut),
                            ],
                          ),
                          if (doc.clientNom != null)
                            Text(doc.clientNom!,
                                style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    // Badge progression
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: toutPretes
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            toutPretes
                                ? Icons.check_circle_rounded
                                : Icons.inventory_outlined,
                            size: 18,
                            color: toutPretes
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$nbPretes / $total préparé(s)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: toutPretes
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Barre de progression ──────────────────────────────────
              LinearProgressIndicator(
                value: progression,
                backgroundColor: AppColors.border,
                color:
                    toutPretes ? AppColors.success : AppColors.primary,
                minHeight: 4,
              ),

              // ── Corps : pick list + panneau latéral ───────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Liste des lignes à préparer
                    Expanded(
                      flex: 3,
                      child: doc.lignes.isEmpty
                          ? const Center(
                              child: Text('Aucune ligne dans ce document'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: doc.lignes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final ligne = doc.lignes[i];
                                return _PickLigneTile(
                                  ligne: ligne,
                                  estPreparee:
                                      _lignesPretes.contains(ligne.id),
                                  onToggle: () => setState(() {
                                    if (_lignesPretes.contains(ligne.id)) {
                                      _lignesPretes.remove(ligne.id);
                                    } else {
                                      _lignesPretes.add(ligne.id);
                                    }
                                  }),
                                );
                              },
                            ),
                    ),

                    // Panneau latéral : infos + raccourcis
                    Container(
                      width: 260,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                            left: BorderSide(color: AppColors.border)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Détails', style: AppTextStyles.h3),
                            const SizedBox(height: 16),
                            _InfoLigne(
                              Icons.calendar_today_outlined,
                              'Date',
                              DateFormatter.formatDate(doc.dateDocument),
                            ),
                            if (doc.storeNom != null)
                              _InfoLigne(
                                Icons.store_outlined,
                                'Magasin',
                                doc.storeNom!,
                              ),
                            if (doc.referenceExterne != null)
                              _InfoLigne(
                                Icons.tag_outlined,
                                'Référence',
                                doc.referenceExterne!,
                              ),
                            if (doc.notes != null)
                              _InfoLigne(
                                Icons.notes_outlined,
                                'Notes',
                                doc.notes!,
                              ),
                            const SizedBox(height: 20),
                            Text('Résumé', style: AppTextStyles.h3),
                            const SizedBox(height: 8),
                            Text(
                              '${doc.lignes.length} référence(s)',
                              style: AppTextStyles.caption,
                            ),
                            Text(
                              '${doc.lignes.fold<double>(0, (s, l) => s + l.quantite).toStringAsFixed(0)} unité(s) au total',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 24),
                            if (!toutPretes)
                              AppButton(
                                label: 'Tout marquer prêt',
                                icon: Icons.done_all_rounded,
                                isOutlined: true,
                                onPressed: () => setState(() {
                                  _lignesPretes.addAll(
                                      doc.lignes.map((l) => l.id));
                                }),
                              )
                            else
                              AppButton(
                                label: 'Tout décocher',
                                icon: Icons.remove_done_rounded,
                                isOutlined: true,
                                onPressed: () =>
                                    setState(() => _lignesPretes.clear()),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Barre d'actions ────────────────────────────────────────
              DocumentActionBar(
                document: doc,
                isLoading: _isLoading,
                onValider: doc.statut == DocumentStatut.brouillon
                    ? _valider
                    : null,
                onTransformer: doc.statut == DocumentStatut.valide
                    ? (cible) => _transformer(cible, doc)
                    : null,
                onAnnuler: doc.estAnnule ? null : _annuler,
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

// ── Tuile d'une ligne à préparer ──────────────────────────────────────────────

class _PickLigneTile extends StatelessWidget {
  final DocumentLigneEntity ligne;
  final bool estPreparee;
  final VoidCallback onToggle;

  const _PickLigneTile({
    required this.ligne,
    required this.estPreparee,
    required this.onToggle,
  });

  String get _qteStr {
    final q = ligne.quantite;
    return q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: estPreparee
            ? AppColors.success.withValues(alpha: 0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estPreparee ? AppColors.success : AppColors.border,
          width: estPreparee ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Case à cocher animée
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: estPreparee
                        ? AppColors.success
                        : Colors.transparent,
                    border: Border.all(
                      color: estPreparee
                          ? AppColors.success
                          : AppColors.textSecondary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: estPreparee
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 14),

                // Badge code article
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ligne.articleCode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nom article
                Expanded(
                  child: Text(
                    ligne.articleNom,
                    style: AppTextStyles.bodyBold.copyWith(
                      decoration: estPreparee
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: estPreparee
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),

                // Quantité à préparer
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: estPreparee
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '× $_qteStr',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: estPreparee
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ligne d'info latérale ─────────────────────────────────────────────────────

class _InfoLigne extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valeur;

  const _InfoLigne(this.icon, this.label, this.valeur);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 1),
                Text(valeur, style: AppTextStyles.bodyBold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
