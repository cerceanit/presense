import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class RiskCircle extends StatelessWidget {
  final double score;

  const RiskCircle({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(score);
    final label = AppColors.riskLabel(score);
    final progress = (score / 100).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 14,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${score.round()}%',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontSize: 42,
                        ),
                  ),
                  Text(
                    'Risk',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }
}
