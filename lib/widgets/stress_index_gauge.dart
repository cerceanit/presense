import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StressIndexGauge extends StatelessWidget {
  final double stressIndex;

  const StressIndexGauge({super.key, required this.stressIndex});

  Color _barColor() {
    if (stressIndex < 40) return AppColors.success;
    if (stressIndex < 60) return AppColors.warning;
    if (stressIndex < 80) return AppColors.alert;
    return AppColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    final value = stressIndex.clamp(0.0, 100.0);
    final fillFraction = value / 100.0;
    final tickStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stress Index',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              '${value.toInt()}/100',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth = constraints.maxWidth * fillFraction;
            return Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 20,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: _barColor(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Low', style: tickStyle),
            Text('Moderate', style: tickStyle),
            Text('High', style: tickStyle),
          ],
        ),
      ],
    );
  }
}
