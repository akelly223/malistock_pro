import '../entities/dashboard_stats.dart';

enum DashboardPeriode { jour, semaine, mois, trimestre, semestre, annee }

abstract class DashboardRepository {
  Future<DashboardStatsEntity> getStats(DashboardPeriode periode);
}
