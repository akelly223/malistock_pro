import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/session_provider.dart';
import '../../app/providers/repository_providers.dart';
import '../../core/permissions/permissions.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/access_denied_view.dart';
import '../../core/widgets/app_button.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/services/depot_vente_reglement_pdf_service.dart';
import '../articles/providers/article_provider.dart';
import '../settings/providers/settings_provider.dart';
import 'providers/depot_vente_provider.dart';

/// Espace Dépôt-vente : centré sur une seule question — « qu'est-ce qui a
/// été vendu pour un auteur et que je ne lui ai pas encore reversé ? » —
/// voir demande utilisateur du 2026-08-17, mémoire
/// [[project_depot_vente_auteurs]]. Deux onglets seulement (Règlements /
/// Stock), aucune comptabilité (CA, bénéfice) : la dette dépôt-vente
/// réutilise le système d'achats fournisseur fantômes `DEP-...` déjà en
/// place, jamais un système parallèle.
class DepotVenteScreen extends ConsumerWidget {
  const DepotVenteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    if (!Permissions.peutVoirBenefice(utilisateur)) {
      return const AccessDeniedView(titre: 'Dépôt-vente');
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dépôt-vente'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rafraîchir',
              onPressed: () {
                ref.invalidate(depotVenteStatsProvider);
                ref.invalidate(depotVenteLignesARegulerProvider);
                ref.invalidate(depotVenteHistoriqueProvider);
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Règlements'),
            Tab(text: 'Stock'),
          ]),
        ),
        body: const TabBarView(
          children: [
            _ReglementsTab(),
            _StockTab(),
          ],
        ),
      ),
    );
  }
}

// ── Onglet Règlements ───────────────────────────────────────────────────────

class _ReglementsTab extends ConsumerWidget {
  const _ReglementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(depotVenteStatsProvider);
    final aReglerAsync = ref.watch(depotVenteLignesARegulerProvider);
    final historiqueAsync = ref.watch(depotVenteHistoriqueProvider);
    final filtreStatut = ref.watch(depotVenteFiltreStatutProvider);
    final fournisseurId = ref.watch(depotVenteFournisseurFiltreProvider);
    final fournisseursAsync = ref.watch(depotSuppliersProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(statsAsync: statsAsync, aReglerAsync: aReglerAsync),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<DepotVenteFiltreStatut>(
                segments: const [
                  ButtonSegment(
                      value: DepotVenteFiltreStatut.tous, label: Text('Tous')),
                  ButtonSegment(
                      value: DepotVenteFiltreStatut.aRegler,
                      label: Text('À régler')),
                  ButtonSegment(
                      value: DepotVenteFiltreStatut.regles,
                      label: Text('Réglés')),
                ],
                selected: {filtreStatut},
                onSelectionChanged: (s) => ref
                    .read(depotVenteFiltreStatutProvider.notifier)
                    .state = s.first,
              ),
              fournisseursAsync.when(
                data: (fournisseurs) => DropdownButton<int?>(
                  value: fournisseurId,
                  hint: const Text('Tous les auteurs'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tous les auteurs'),
                    ),
                    for (final f in fournisseurs)
                      DropdownMenuItem<int?>(value: f.id, child: Text(f.nom)),
                  ],
                  onChanged: (v) => ref
                      .read(depotVenteFournisseurFiltreProvider.notifier)
                      .state = v,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (filtreStatut != DepotVenteFiltreStatut.regles)
                  _ARegulerSection(
                      aReglerAsync: aReglerAsync, fournisseurId: fournisseurId),
                if (filtreStatut != DepotVenteFiltreStatut.aRegler) ...[
                  const SizedBox(height: 24),
                  _HistoriqueSection(
                      historiqueAsync: historiqueAsync,
                      fournisseurId: fournisseurId),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vue globale (§13) : ce qui a été vendu pour les auteurs, ce qui leur
/// est dû, et ce qui revient au commerce — jamais mélangés (§14).
class _StatsRow extends StatelessWidget {
  final AsyncValue<List<DepotVenteStatEntity>> statsAsync;
  final AsyncValue<List<DepotVenteLigneARegulerEntity>> aReglerAsync;

  const _StatsRow({required this.statsAsync, required this.aReglerAsync});

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.valueOrNull ?? const [];
    final aRegler = aReglerAsync.valueOrNull ?? const [];

    final livresVendus = stats.fold<double>(0, (s, e) => s + e.quantiteVendue);
    final caDepot = stats.fold<double>(0, (s, e) => s + e.caHt);
    final maCommission =
        stats.fold<double>(0, (s, e) => s + e.beneficeLibrairie);
    final aReverser = aRegler.fold<double>(0, (s, e) => s + e.montantDu);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      return GridView.count(
        crossAxisCount: isWide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 1.9 : 1.5,
        children: [
          StatCard(
            titre: 'Livres dépôt vendus',
            valeur: livresVendus.toStringAsFixed(0),
            icon: Icons.menu_book_rounded,
            color: AppColors.primary,
          ),
          StatCard(
            titre: 'Chiffre d\'affaires dépôt',
            valeur: CurrencyFormatter.format(caDepot),
            icon: Icons.trending_up_rounded,
            color: AppColors.secondary,
          ),
          StatCard(
            titre: 'Ma commission',
            valeur: CurrencyFormatter.format(maCommission),
            icon: Icons.savings_rounded,
            color: AppColors.success,
          ),
          StatCard(
            titre: 'À reverser',
            valeur: CurrencyFormatter.format(aReverser),
            icon: Icons.payments_rounded,
            color: aReverser > 0 ? AppColors.danger : AppColors.success,
          ),
        ],
      );
    });
  }
}

class _ARegulerSection extends StatelessWidget {
  final AsyncValue<List<DepotVenteLigneARegulerEntity>> aReglerAsync;
  final int? fournisseurId;

  const _ARegulerSection(
      {required this.aReglerAsync, required this.fournisseurId});

  @override
  Widget build(BuildContext context) {
    return aReglerAsync.when(
      data: (lignes) {
        final filtrees = fournisseurId == null
            ? lignes
            : lignes.where((l) => l.supplierId == fournisseurId).toList();

        if (filtrees.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: EmptyState(
              icon: Icons.check_circle_outline_rounded,
              message: 'Rien à régler pour le moment.',
            ),
          );
        }

        final parAuteur = <int, List<DepotVenteLigneARegulerEntity>>{};
        for (final l in filtrees) {
          parAuteur.putIfAbsent(l.supplierId, () => []).add(l);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('À régler', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            for (final entry in parAuteur.entries) ...[
              _AuteurARegulerCard(lignes: entry.value),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Text('Erreur : $e'),
    );
  }
}

class _AuteurARegulerCard extends ConsumerStatefulWidget {
  final List<DepotVenteLigneARegulerEntity> lignes;

  const _AuteurARegulerCard({required this.lignes});

  @override
  ConsumerState<_AuteurARegulerCard> createState() =>
      _AuteurARegulerCardState();
}

class _AuteurARegulerCardState extends ConsumerState<_AuteurARegulerCard> {
  bool _enCours = false;

  Future<void> _reglerAuteur() async {
    final ligne0 = widget.lignes.first;
    final totalLivres =
        widget.lignes.fold<double>(0, (s, l) => s + l.quantiteVendue);
    final totalDu = widget.lignes.fold<double>(0, (s, l) => s + l.montantDu);
    final totalVente =
        widget.lignes.fold<double>(0, (s, l) => s + l.venteTotale);
    final totalCommission = totalVente - totalDu;

    final saisie = await showDialog<({double montant, String? note})>(
      context: context,
      builder: (context) => _ReglementDialog(
        supplierNom: ligne0.supplierNom,
        totalLivres: totalLivres,
        totalVente: totalVente,
        totalCommission: totalCommission,
        totalDu: totalDu,
      ),
    );
    if (saisie == null || !mounted) return;

    setState(() => _enCours = true);
    try {
      final utilisateur = ref.read(sessionProvider);
      final repo = ref.read(depotVenteRepositoryProvider);
      final reglement = await repo.reglerFournisseur(
        supplierId: ligne0.supplierId,
        montant: saisie.montant,
        note: saisie.note,
        userId: utilisateur?.id,
      );
      ref.invalidate(depotVenteLignesARegulerProvider);
      ref.invalidate(depotVenteHistoriqueProvider);
      if (mounted) {
        await _proposerRecu(reglement);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _proposerRecu(DepotVenteReglementEntity reglement) async {
    final creerPdf = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${reglement.supplierNom} réglé'),
        content: Text(
          reglement.statut == DepotVenteReglementStatut.regle
              ? '${CurrencyFormatter.format(reglement.montantPaye)} versés. '
                  'Le compte de cet auteur est soldé.'
              : '${CurrencyFormatter.format(reglement.montantPaye)} versés '
                  'sur ${CurrencyFormatter.format(reglement.montantDu)} dus. '
                  'Reste à payer : ${CurrencyFormatter.format(reglement.resteAPayer)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Créer le reçu PDF'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (creerPdf == true && mounted) {
      await _imprimerRecu(context, ref, reglement);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lignes = widget.lignes;
    final totalLivres = lignes.fold<double>(0, (s, l) => s + l.quantiteVendue);
    final totalDu = lignes.fold<double>(0, (s, l) => s + l.montantDu);
    final totalVente = lignes.fold<double>(0, (s, l) => s + l.venteTotale);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(lignes.first.supplierNom, style: AppTextStyles.h3),
              ),
              const _StatutBadge(statut: null),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 3, child: Text('Livre', style: AppTextStyles.caption)),
              Expanded(
                flex: 1,
                child: Text('Qté', textAlign: TextAlign.right, style: AppTextStyles.caption),
              ),
              Expanded(
                flex: 2,
                child: Text('Vente', textAlign: TextAlign.right, style: AppTextStyles.caption),
              ),
              Expanded(
                flex: 2,
                child: Text('Part auteur', textAlign: TextAlign.right, style: AppTextStyles.caption),
              ),
            ],
          ),
          const Divider(height: 12),
          for (final l in lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(l.articleNom)),
                  Expanded(
                    flex: 1,
                    child: Text(
                      l.quantiteVendue.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(l.venteTotale),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(l.montantDu),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyBold,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Text(
                'TOTAL : ${totalLivres.toStringAsFixed(0)} livre(s) — '
                'vente ${CurrencyFormatter.format(totalVente)} — '
                'à reverser ${CurrencyFormatter.format(totalDu)}',
                style: AppTextStyles.bodyBold,
              ),
              AppButton(
                label: 'Marquer comme réglé',
                icon: Icons.check_circle_outline,
                isLoading: _enCours,
                onPressed: _reglerAuteur,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog de règlement (§6, §10) : résumé vente/commission/part auteur,
/// montant réglé modifiable (partiel ou total) et note optionnelle (§7).
class _ReglementDialog extends StatefulWidget {
  final String supplierNom;
  final double totalLivres;
  final double totalVente;
  final double totalCommission;
  final double totalDu;

  const _ReglementDialog({
    required this.supplierNom,
    required this.totalLivres,
    required this.totalVente,
    required this.totalCommission,
    required this.totalDu,
  });

  @override
  State<_ReglementDialog> createState() => _ReglementDialogState();
}

class _ReglementDialogState extends State<_ReglementDialog> {
  late final TextEditingController _montantController;
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _montantController =
        TextEditingController(text: widget.totalDu.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _montantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Régler ${widget.supplierNom}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${widget.totalLivres.toStringAsFixed(0)} livre(s) vendu(s)'),
              const SizedBox(height: 8),
              _resumeLigne('Total ventes', widget.totalVente),
              _resumeLigne('Ma commission', widget.totalCommission),
              _resumeLigne('Montant dû (part auteur)', widget.totalDu,
                  accent: true),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montantController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant réglé',
                  helperText: 'Modifiable pour un règlement partiel',
                ),
                validator: (v) {
                  final montant = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (montant == null || montant <= 0) {
                    return 'Montant invalide';
                  }
                  if (montant > widget.totalDu + 0.01) {
                    return 'Ne peut pas dépasser le montant dû';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  hintText: 'Ex : Règlement effectué chez l\'auteur le ...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final montant =
                double.parse(_montantController.text.replaceAll(',', '.'));
            final note = _noteController.text.trim();
            Navigator.of(context).pop((
              montant: montant,
              note: note.isEmpty ? null : note,
            ));
          },
          child: const Text('Confirmer le règlement'),
        ),
      ],
    );
  }

  Widget _resumeLigne(String libelle, double valeur, {bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(libelle,
              style: accent ? AppTextStyles.bodyBold : AppTextStyles.body),
          Text(CurrencyFormatter.format(valeur),
              style: accent ? AppTextStyles.bodyBold : AppTextStyles.body),
        ],
      ),
    );
  }
}

/// Régénère/imprime le reçu PDF (§11) d'un règlement — utilisable juste
/// après le règlement ou depuis l'historique (« Réimprimer »).
Future<void> _imprimerRecu(
    BuildContext context, WidgetRef ref, DepotVenteReglementEntity reglement) async {
  try {
    final settings = await ref.read(appSettingsProvider.future);
    await DepotVenteReglementPdfService.print(
        reglement: reglement, settings: settings);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }
}

class _HistoriqueSection extends StatelessWidget {
  final AsyncValue<List<DepotVenteReglementEntity>> historiqueAsync;
  final int? fournisseurId;

  const _HistoriqueSection(
      {required this.historiqueAsync, required this.fournisseurId});

  @override
  Widget build(BuildContext context) {
    return historiqueAsync.when(
      data: (reglements) {
        final filtres = fournisseurId == null
            ? reglements
            : reglements.where((r) => r.supplierId == fournisseurId).toList();

        if (filtres.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: EmptyState(
              icon: Icons.history_rounded,
              message: 'Aucun règlement enregistré pour le moment.',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            for (final r in filtres) ...[
              _HistoriqueTile(reglement: r),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Text('Erreur : $e'),
    );
  }
}

class _HistoriqueTile extends ConsumerWidget {
  final DepotVenteReglementEntity reglement;

  const _HistoriqueTile({required this.reglement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormatter.formatDateTime(reglement.dateHeure),
                        style: AppTextStyles.caption),
                    Text(reglement.supplierNom, style: AppTextStyles.bodyBold),
                    Text(
                        '${reglement.quantiteLivres.toStringAsFixed(0)} livre(s) — '
                        'payé ${CurrencyFormatter.format(reglement.montantPaye)}'
                        '${reglement.resteAPayer > 0.01 ? ' — reste ${CurrencyFormatter.format(reglement.resteAPayer)}' : ''}',
                        style: AppTextStyles.caption),
                    if (reglement.note != null && reglement.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('« ${reglement.note} »',
                            style: AppTextStyles.caption
                                .copyWith(fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(reglement.montantPaye),
                      style: AppTextStyles.bodyBold),
                  const SizedBox(height: 6),
                  _StatutBadge(statut: reglement.statut),
                ],
              ),
            ],
          ),
          if (reglement.lignes.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Réimprimer le reçu'),
                onPressed: () => _imprimerRecu(context, ref, reglement),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final DepotVenteReglementStatut? statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String texte;
    switch (statut) {
      case DepotVenteReglementStatut.regle:
        color = AppColors.success;
        texte = '🟢 RÉGLÉ';
        break;
      case DepotVenteReglementStatut.partiel:
        color = AppColors.secondary;
        texte = '🟡 PARTIELLEMENT RÉGLÉ';
        break;
      case null:
        color = AppColors.danger;
        texte = '🔴 NON RÉGLÉ';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texte,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

// ── Onglet Stock ─────────────────────────────────────────────────────────

class _StockTab extends ConsumerWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(depotVenteStatsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: statsAsync.when(
        data: (stats) {
          if (stats.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'Aucun titre en dépôt-vente pour le moment.\n'
                  "Ajoutez un fournisseur dépôt-vente puis liez-le à un article "
                  'depuis sa fiche.',
            );
          }
          final tries = [...stats]..sort((a, b) => a.nom.compareTo(b.nom));
          return ListView.separated(
            itemCount: tries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _StockTile(stat: tries[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  final DepotVenteStatEntity stat;

  const _StockTile({required this.stat});

  @override
  Widget build(BuildContext context) {
    final restant = stat.stockTotal;
    final enRupture = restant <= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.nom, style: AppTextStyles.bodyBold),
                Text(stat.supplierNom, style: AppTextStyles.caption),
              ],
            ),
          ),
          Expanded(
            child: _Chiffre(
                libelle: 'Stock', valeur: stat.stockTotal.toStringAsFixed(0)),
          ),
          Expanded(
            child: _Chiffre(
                libelle: 'Vendus', valeur: stat.quantiteVendue.toStringAsFixed(0)),
          ),
          Expanded(
            child: _Chiffre(libelle: 'Restant', valeur: restant.toStringAsFixed(0)),
          ),
          if (enRupture)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🔴 RUPTURE',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  final String libelle;
  final String valeur;

  const _Chiffre({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(libelle, style: AppTextStyles.caption),
        Text(valeur, style: AppTextStyles.bodyBold),
      ],
    );
  }
}
