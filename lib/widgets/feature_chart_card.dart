import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class FeatureChartCard extends StatelessWidget {
  final String title;
  final String currentValue;
  final List<double> history;
  final String unit;

  const FeatureChartCard({
    super.key,
    required this.title,
    required this.currentValue,
    required this.history,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    // Filter zero/invalid values before plotting
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      if (history[i] != 0) {
        spots.add(FlSpot(i.toDouble(), history[i]));
      }
    }

    final values = spots.map((s) => s.y).toList();
    final minY   = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY   = values.isEmpty
        ? 10.0
        : values.reduce((a, b) => a > b ? a : b) * 1.1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              Text(
                '$currentValue$unit',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryAccent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'Collecting data…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: spots.first.x,
                      maxX: spots.last.x,
                      minY: minY,
                      maxY: maxY == minY ? minY + 1 : maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.border.withValues(alpha: 0.6),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.primaryAccent,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryAccent
                                .withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}