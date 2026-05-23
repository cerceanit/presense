import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class SensorRow extends StatelessWidget {
  final int hr;
  final double hrv;
  final double movement;
  final double hrTrend;
  final double breathingRate;
  final double stress;

  const SensorRow({
    super.key,
    required this.hr,
    required this.hrv,
    required this.movement,
    required this.hrTrend,
    required this.breathingRate,
    required this.stress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _tile('HR', '$hr bpm', 'Heart Rate'),
            const SizedBox(width: 12),
            _tile('HRV', '${hrv.toInt()} ms', 'HRV'),
            const SizedBox(width: 12),
            _tile('TREND', hrTrend.toStringAsFixed(1), 'HR Trend'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _tile('MOV', movement.toStringAsFixed(1), 'Movement'),
            const SizedBox(width: 12),
            _tile('RESP', breathingRate.toStringAsFixed(1), 'Breathing'),
            const SizedBox(width: 12),
            _tile('RISK', '${stress.toInt()}%', 'Stress'),
          ],
        ),
      ],
    );
  }

  Widget _tile(String icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppColors.radius),
        ),
        child: Column(
          children: [
            Text(icon,
              style: const TextStyle(
                color: AppColors.primaryAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              )),
            const SizedBox(height: 6),
            Text(value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              )),
            Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              )),
          ],
        ),
      ),
    );
  }
}