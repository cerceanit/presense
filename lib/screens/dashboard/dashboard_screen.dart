import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../providers/chart_history_provider.dart';
import '../../providers/stress_provider.dart';
import '../../widgets/feature_chart_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stress = ref.watch(stressProvider);
    final history = ref.watch(chartHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Your Body Right Now'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FeatureChartCard(
            title: 'Heart Rate',
            currentValue: '${stress.hr.round()}',
            unit: ' bpm',
            history: history.heartRate,
          ),
          FeatureChartCard(
            title: 'HRV',
            currentValue: '${stress.hrv.round()}',
            unit: ' ms',
            history: history.hrv,
          ),
          FeatureChartCard(
            title: 'Respiratory Rate',
            currentValue: stress.breathingRate.toStringAsFixed(1),
            unit: ' /min',
            history: history.respiratoryRate,
          ),
          FeatureChartCard(
            title: 'Movement',
            currentValue: stress.movement.toStringAsFixed(2),
            unit: '',
            history: history.movement,
          ),
          FeatureChartCard(
            title: 'HR Trend',
            currentValue: stress.hrTrend.toStringAsFixed(1),
            unit: '',
            history: history.hrTrend,
          ),
        ],
      ),
    );
  }
}
