import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../domain/entities/dashboard_stats.dart';
import '../../../domain/repositories/dashboard_repository.dart';

export '../../../domain/repositories/dashboard_repository.dart'
    show DashboardPeriode;

extension DashboardPeriodeExt on DashboardPeriode {
  String get libelle => switch (this) {
        DashboardPeriode.jour => 'Aujourd\'hui',
        DashboardPeriode.semaine => 'Cette semaine',
        DashboardPeriode.mois => 'Ce mois',
        DashboardPeriode.trimestre => 'Ce trimestre',
        DashboardPeriode.semestre => 'Ce semestre',
        DashboardPeriode.annee => 'Cette année',
      };

  /// Quel jeu de données utiliser pour le graphique d'évolution.
  ChartMode get chartMode => switch (this) {
        DashboardPeriode.jour || DashboardPeriode.semaine => ChartMode.jours7,
        DashboardPeriode.mois => ChartMode.jours30,
        _ => ChartMode.mois12,
      };
}

enum ChartMode { jours7, jours30, mois12 }

final dashboardPeriodeProvider =
    StateProvider<DashboardPeriode>((ref) => DashboardPeriode.mois);

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStatsEntity>(
  (ref) async {
    final repo = ref.watch(dashboardRepositoryProvider);
    final periode = ref.watch(dashboardPeriodeProvider);
    return repo.getStats(periode);
  },
);
