import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StressChart extends StatelessWidget {
  final List<double> history;
  final Color color;

  const StressChart({
    super.key,
    required this.history,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'COLLECTING DATA...',
            style: TextStyle(
              color: const Color(0xFF333333),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: 80,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.08),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
