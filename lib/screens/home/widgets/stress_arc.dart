import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StressArc extends StatelessWidget {
  final double score;
  final Color color;

  const StressArc({super.key, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: 180,
              sectionsSpace: 0,
              centerSpaceRadius: 80,
              sections: [
                PieChartSectionData(
                  value: score,
                  color: color,
                  radius: 20,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: 100 - score,
                  color: color.withValues(alpha: 0.1),
                  radius: 20,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Stress Load',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
