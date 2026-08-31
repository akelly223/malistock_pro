import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/dashboard_stats.dart';
import '../providers/dashboard_provider.dart';

class SalesChart extends StatelessWidget {
  final List<PointVenteEntity> points;
  final ChartMode mode;

  const SalesChart({super.key, required this.points, this.mode = ChartMode.jours7});

  String get _titre => switch (mode) {
        ChartMode.jours7 => 'Ventes des 7 derniers jours',
        ChartMode.jours30 => 'Ventes des 30 derniers jours',
        ChartMode.mois12 => 'Ventes des 12 derniers mois',
      };

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Aucune donnée de vente')),
      );
    }

    final maxY = points.map((p) => p.total).fold<double>(0, (a, b) => a > b ? a : b);
    final maxYAjuste = maxY == 0 ? 1000 : maxY * 1.2;

    // Spacing pour beaucoup de barres : afficher 1 label sur N
    final step = switch (mode) {
      ChartMode.jours7 => 1,
      ChartMode.jours30 => 5,
      ChartMode.mois12 => 1,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_titre, style: AppTextStyles.h3),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxYAjuste.toDouble(),
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        CurrencyFormatter.format(rod.toY),
                        AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (step > 1 && index % step != 0) {
                          return const SizedBox.shrink();
                        }
                        final label = mode == ChartMode.mois12
                            ? DateFormatter.formatMonthShort(points[index].date)
                            : DateFormatter.formatDayMonth(points[index].date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: AppTextStyles.caption),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: points.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final estDernier = index == points.length - 1;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: point.total,
                        color: estDernier
                            ? AppColors.secondary
                            : AppColors.primary,
                        width: mode == ChartMode.jours7 ? 28 : 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
