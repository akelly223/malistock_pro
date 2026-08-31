import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/stat_cards_row.dart';
import 'widgets/sales_chart.dart';
import 'widgets/low_stock_alert_list.dart';
import 'widgets/top_products_list.dart';
import 'widgets/top_clients_list.dart';
import 'widgets/dormant_articles_list.dart';
import 'widgets/conseils_section.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final periode = ref.watch(dashboardPeriodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          final chartPoints = switch (periode.chartMode) {
            ChartMode.jours7 => stats.ventesParJour,
            ChartMode.jours30 => stats.ventesParJour30,
            ChartMode.mois12 => stats.ventesParMois12,
          };

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ── Sélecteur de période ─────────────────────────────────────
              _PeriodeSelector(
                periodeSelectionnee: periode,
                onChanged: (p) =>
                    ref.read(dashboardPeriodeProvider.notifier).state = p,
              ),
              const SizedBox(height: 20),

              // ── Section 1 : CA fixe (Aujourd'hui / Semaine / Mois / Année) ──
              VentesFixedCardsRow(stats: stats),
              const SizedBox(height: 24),

              // ── Section 2 : KPI recalculés pour la période sélectionnée ────
              StatCardsRow(stats: stats),
              const SizedBox(height: 24),

              // ── Section 3 : Documents (comptages par période) ────────────
              DocumentsStatsSection(stats: stats),
              const SizedBox(height: 24),

              // ── Section 4 : Articles ──────────────────────────────────────
              ArticlesStatsSection(stats: stats),
              const SizedBox(height: 24),

              // ── Section 5 : Clients & Fournisseurs ────────────────────────
              ClientsFournisseursStatsSection(stats: stats),
              const SizedBox(height: 24),

              // ── Section 6 : Documents V2 en attente (pipeline) ────────────
              _SectionV2(stats: stats),
              const SizedBox(height: 24),

              // ── Section 7 : Graphique évolution ──────────────────────────
              SalesChart(points: chartPoints, mode: periode.chartMode),
              const SizedBox(height: 24),

              // ── Section 8 : Conseils intelligents ────────────────────────
              if (stats.conseils.isNotEmpty) ...[
                ConseilsSection(conseils: stats.conseils),
                const SizedBox(height: 24),
              ],

              // ── Section 9 : Top articles + Top clients ────────────────────
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final topArticles = TopProductsList(
                    produits: stats.produitsLesPlusVendus);
                final topClients =
                    TopClientsList(clients: stats.topClients);
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: topArticles),
                      const SizedBox(width: 16),
                      Expanded(child: topClients),
                    ],
                  );
                }
                return Column(children: [
                  topArticles,
                  const SizedBox(height: 16),
                  topClients,
                ]);
              }),
              const SizedBox(height: 24),

              // ── Section 10 : Ruptures + Articles dormants ────────────────
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final ruptures =
                    LowStockAlertList(articles: stats.produitsEnRupture);
                final dormants =
                    DormantArticlesList(articles: stats.articlesDormants);
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ruptures),
                      const SizedBox(width: 16),
                      Expanded(child: dormants),
                    ],
                  );
                }
                return Column(children: [
                  ruptures,
                  const SizedBox(height: 16),
                  dormants,
                ]);
              }),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('Erreur de chargement', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text('$e', style: AppTextStyles.caption),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(dashboardStatsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sélecteur de période ─────────────────────────────────────────────────────

class _PeriodeSelector extends StatelessWidget {
  final DashboardPeriode periodeSelectionnee;
  final ValueChanged<DashboardPeriode> onChanged;

  const _PeriodeSelector({
    required this.periodeSelectionnee,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DashboardPeriode.values.map((p) {
          final selected = p == periodeSelectionnee;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p.libelle),
              selected: selected,
              onSelected: (_) => onChanged(p),
              selectedColor: AppColors.primary,
              labelStyle: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white : null,
                fontWeight: selected ? FontWeight.bold : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Section Documents V2 ─────────────────────────────────────────────────────

class _SectionV2 extends StatelessWidget {
  final dynamic stats;
  const _SectionV2({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pipeline en attente', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStatV2(
                label: 'Proformas en attente',
                valeur: '${stats.nombreProformasBrouillon}',
                icon: Icons.description_outlined,
                color: AppColors.secondary,
                route: '/proformas',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStatV2(
                label: 'Commandes à livrer',
                valeur: '${stats.nombreBCEnAttente}',
                icon: Icons.assignment_outlined,
                color: AppColors.warning,
                route: '/bons-commande',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatV2 extends StatelessWidget {
  final String label;
  final String valeur;
  final IconData icon;
  final Color color;
  final String route;

  const _MiniStatV2({
    required this.label,
    required this.valeur,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(route),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(valeur,
                        style: AppTextStyles.h3.copyWith(color: color)),
                    const SizedBox(height: 2),
                    Text(label, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
