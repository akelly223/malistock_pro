import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/providers/session_provider.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/dashboard_stats.dart';
import '../providers/dashboard_provider.dart';

/// Cartes CA fixes (Aujourd'hui / Semaine / Mois / Année), toujours
/// affichées quelle que soit la période sélectionnée dans le
/// sélecteur du tableau de bord.
class VentesFixedCardsRow extends StatelessWidget {
  final DashboardStatsEntity stats;

  const VentesFixedCardsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      final cards = [
        StatCard(
          titre: 'CA — Aujourd\'hui',
          valeur: CurrencyFormatter.format(stats.ventesJour),
          icon: Icons.today_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          titre: 'CA — Cette semaine',
          valeur: CurrencyFormatter.format(stats.ventesSemaine),
          icon: Icons.calendar_view_week_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          titre: 'CA — Ce mois',
          valeur: CurrencyFormatter.format(stats.ventesMois),
          icon: Icons.calendar_month_rounded,
          color: AppColors.primary,
          sousTitre: stats.variationMois != null
              ? _texteVariation(stats.variationMois!)
              : null,
          couleurSousTitre: stats.variationMois != null
              ? (stats.variationMois! >= 0 ? AppColors.success : AppColors.danger)
              : null,
        ),
        StatCard(
          titre: 'CA — Cette année',
          valeur: CurrencyFormatter.format(stats.ventesAnnee),
          icon: Icons.calendar_today_rounded,
          color: AppColors.primary,
        ),
      ];
      return GridView.count(
        crossAxisCount: isWide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 1.7 : 1.4,
        children: cards,
      );
    });
  }

  String _texteVariation(double variation) {
    final sign = variation >= 0 ? '+' : '';
    return '$sign${variation.toStringAsFixed(1)}% vs mois précédent';
  }
}

/// Cartes recalculées à chaque changement de période (bénéfice, achats,
/// dettes, ruptures) — le libellé de chaque carte reflète la période
/// sélectionnée dans le sélecteur en haut du tableau de bord.
class StatCardsRow extends ConsumerWidget {
  final DashboardStatsEntity stats;

  const StatCardsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    final peutVoirBenefice = Permissions.peutVoirBenefice(utilisateur);
    final periode = ref.watch(dashboardPeriodeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final cards = [
          StatCard(
            titre: 'CA — ${periode.libelle}',
            valeur: CurrencyFormatter.format(stats.caPeriodeSelectionnee),
            icon: Icons.point_of_sale_rounded,
            color: AppColors.primary,
          ),
          if (peutVoirBenefice && stats.beneficePeriodeSelectionnee != null)
            StatCard(
              titre: 'Bénéfice — ${periode.libelle}',
              valeur:
                  CurrencyFormatter.format(stats.beneficePeriodeSelectionnee!),
              icon: Icons.trending_up_rounded,
              color: AppColors.success,
            ),
          StatCard(
            titre: 'Achats — ${periode.libelle}',
            valeur: CurrencyFormatter.format(stats.achatsPeriodeSelectionnee),
            icon: Icons.shopping_cart_outlined,
            color: AppColors.warning,
            sousTitre: '${stats.nombreAchatsPeriode} achat(s)',
          ),
          StatCard(
            titre: 'Dettes clients',
            valeur: CurrencyFormatter.format(stats.totalDettesClients),
            icon: Icons.account_balance_wallet_outlined,
            color: stats.totalDettesClients > 0
                ? AppColors.danger
                : AppColors.success,
            sousTitre: stats.nombreClientsAvecDette > 0
                ? '${stats.nombreClientsAvecDette} client(s)'
                : null,
            couleurSousTitre: AppColors.danger,
          ),
          StatCard(
            titre: 'Ruptures de stock',
            valeur: stats.nombreRuptures.toString(),
            icon: Icons.warning_amber_rounded,
            color: stats.nombreRuptures == 0
                ? AppColors.success
                : AppColors.danger,
          ),
          StatCard(
            titre: 'Alertes stock bas',
            valeur: stats.nombreAlertes.toString(),
            icon: Icons.notifications_active_outlined,
            color: stats.nombreAlertes == 0
                ? AppColors.success
                : AppColors.warning,
          ),
        ];

        return GridView.count(
          crossAxisCount: isWide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 1.7 : 1.4,
          children: cards,
        );
      },
    );
  }
}

/// Section "Documents" : comptages recalculés pour la période
/// sélectionnée.
class DocumentsStatsSection extends ConsumerWidget {
  final DashboardStatsEntity stats;

  const DocumentsStatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(dashboardPeriodeProvider);
    return _StatsSection(
      titre: 'Documents — ${periode.libelle}',
      cards: [
        _MiniStat(
          label: 'Ventes',
          valeur: '${stats.nombreVentesPeriode}',
          icon: Icons.point_of_sale_outlined,
          color: AppColors.primary,
        ),
        _MiniStat(
          label: 'Achats',
          valeur: '${stats.nombreAchatsPeriode}',
          icon: Icons.shopping_cart_outlined,
          color: AppColors.warning,
        ),
        _MiniStat(
          label: 'Devis',
          valeur: '${stats.nombreDevisPeriode}',
          icon: Icons.request_quote_outlined,
          color: AppColors.secondary,
        ),
        _MiniStat(
          label: 'Factures',
          valeur: '${stats.nombreFacturesPeriode}',
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
        ),
        _MiniStat(
          label: 'Proformas',
          valeur: '${stats.nombreProformasPeriode}',
          icon: Icons.description_outlined,
          color: AppColors.secondary,
        ),
      ],
    );
  }
}

/// Section "Articles" : cumulatif, indépendant de la période.
class ArticlesStatsSection extends ConsumerWidget {
  final DashboardStatsEntity stats;

  const ArticlesStatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(sessionProvider);
    // Dérivée du prix d'achat (stock × prix_achat) : un employé ne doit
    // jamais pouvoir la déduire, même indirectement.
    final peutVoirValeurStock = Permissions.peutVoirPrixAchat(utilisateur);
    return _StatsSection(
      titre: 'Articles',
      cards: [
        _MiniStat(
          label: 'Nombre d\'articles',
          valeur: '${stats.nombreArticles}',
          icon: Icons.inventory_2_outlined,
          color: AppColors.primary,
        ),
        if (peutVoirValeurStock)
          _MiniStat(
            label: 'Valeur du stock',
            valeur: CurrencyFormatter.format(stats.valeurStock),
            icon: Icons.savings_outlined,
            color: AppColors.success,
          ),
        _MiniStat(
          label: 'Ruptures',
          valeur: '${stats.nombreRuptures}',
          icon: Icons.error_outline_rounded,
          color: stats.nombreRuptures == 0
              ? AppColors.success
              : AppColors.danger,
        ),
        _MiniStat(
          label: 'Alertes',
          valeur: '${stats.nombreAlertes}',
          icon: Icons.warning_amber_rounded,
          color: stats.nombreAlertes == 0
              ? AppColors.success
              : AppColors.warning,
        ),
      ],
    );
  }
}

/// Section "Clients" / "Fournisseurs".
class ClientsFournisseursStatsSection extends ConsumerWidget {
  final DashboardStatsEntity stats;

  const ClientsFournisseursStatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(dashboardPeriodeProvider);
    return _StatsSection(
      titre: 'Clients & Fournisseurs',
      cards: [
        _MiniStat(
          label: 'Clients',
          valeur: '${stats.nombreClients}',
          icon: Icons.people_outline_rounded,
          color: AppColors.primary,
        ),
        _MiniStat(
          label: 'Nouveaux clients — ${periode.libelle}',
          valeur: '${stats.nouveauxClientsPeriode}',
          icon: Icons.person_add_alt_1_outlined,
          color: AppColors.success,
        ),
        _MiniStat(
          label: 'Fournisseurs',
          valeur: '${stats.nombreFournisseurs}',
          icon: Icons.local_shipping_outlined,
          color: AppColors.secondary,
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final String titre;
  final List<_MiniStat> cards;

  const _StatsSection({required this.titre, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return GridView.count(
            crossAxisCount: isWide ? cards.length.clamp(1, 5) : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.6 : 1.8,
            children: cards,
          );
        }),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String valeur;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.valeur,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valeur,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
