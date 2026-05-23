import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/stress_provider.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/risk_circle.dart';
import '../../widgets/stress_index_gauge.dart';
import '../breathing/breathing_exercise_screen.dart';
import '../map/quiet_zone_map_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  void _handleThreshold(
    WidgetRef ref,
    BuildContext context,
    double score,
    int lastThreshold,
  ) {
    final rounded = score.round();

    if (rounded >= 75 && lastThreshold < 75) {
      HapticFeedback.heavyImpact();
      _showBanner(context, 'Going to a quiet place nearby 🗺️',
          AppColors.critical);
      ref.read(pendingScreenProvider.notifier).state = PendingScreen.map;
      ref.read(lastAlertThresholdProvider.notifier).state = 75;
    } else if (rounded >= 65 && lastThreshold < 65) {
      HapticFeedback.mediumImpact();
      _showBanner(context, "Let's do a breathing exercise", AppColors.warning);
      ref.read(pendingScreenProvider.notifier).state = PendingScreen.breathing;
      ref.read(lastAlertThresholdProvider.notifier).state = 65;
    } else if (rounded >= 55 && lastThreshold < 55) {
      HapticFeedback.lightImpact();
      _showBanner(context, 'Take a deep breath 🌿', AppColors.success);
      ref.read(lastAlertThresholdProvider.notifier).state = 55;
    } else if (rounded < 55) {
      ref.read(lastAlertThresholdProvider.notifier).state = 0;
    }
  }

  void _showBanner(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Simulation buttons ────────────────────────────────────────
  Widget _simButtons(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demo Simulation',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _simBtn(
                label: 'WATCH\n60%',
                color: const Color(0xFFE8A838),
                onTap: () {
                  ref.read(lastAlertThresholdProvider.notifier).state = 0;
                  ref.read(stressProvider.notifier).resetAlerts();
                  ref.read(pendingScreenProvider.notifier).state =
                      PendingScreen.breathing;
                },
              ),
              const SizedBox(width: 6),
              _simBtn(
                label: 'ALERT\n75%',
                color: const Color(0xFFE07B39),
                onTap: () {
                  ref.read(lastAlertThresholdProvider.notifier).state = 0;
                  ref.read(stressProvider.notifier).resetAlerts();
                  ref.read(pendingScreenProvider.notifier).state =
                      PendingScreen.map;
                },
              ),
              const SizedBox(width: 6),
              _simBtn(
                label: 'CRITICAL\n75%+',
                color: const Color(0xFFB85C5C),
                onTap: () async {
                  ref.read(lastAlertThresholdProvider.notifier).state = 0;
                  ref.read(stressProvider.notifier).resetAlerts();
                  final uri = Uri.parse('tel:+77001234567');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
              const SizedBox(width: 6),
              _simBtn(
                label: 'CALM',
                color: const Color(0xFF7A9E7E),
                onTap: () => ref.read(stressProvider.notifier).calm(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stress = ref.watch(stressProvider);
    final score  = stress.stressScore;

    ref.listen<double>(
      stressProvider.select((s) => s.stressScore),
      (prev, next) {
        if (next == prev) return;
        final lastThreshold = ref.read(lastAlertThresholdProvider);
        _handleThreshold(ref, context, next, lastThreshold);
      },
    );

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              // ── Top row — map icon ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const QuietZoneMapScreen()),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    color: AppColors.secondaryAccent,
                    tooltip: 'Quiet places map',
                  ),
                ],
              ),

              // ── Risk circle ─────────────────────────────────
              const SizedBox(height: 8),
              RiskCircle(score: score),

              // ── Stress index gauge ──────────────────────────
              const SizedBox(height: 20),
              StressIndexGauge(stressIndex: stress.stressScore),

              // ── Metric cards ────────────────────────────────
              const SizedBox(height: 24),
              Row(
                children: [
                  MetricCard(
                    icon: Icons.favorite_rounded,
                    label: 'Heart Rate',
                    value: stress.hr > 0 ? '${stress.hr.round()}' : '--',
                  ),
                  const SizedBox(width: 10),
                  MetricCard(
                    icon: Icons.monitor_heart_outlined,
                    label: 'HRV',
                    value: stress.hrv > 0 ? '${stress.hrv.round()}' : '--',
                  ),
                  const SizedBox(width: 10),
                  MetricCard(
                    icon: Icons.psychology_outlined,
                    label: 'Stress Load',
                    value: stress.stressIndex > 0
                        ? '${stress.stressIndex.round()}'
                        : '--',
                  ),
                ],
              ),

              // ── Simulation buttons ──────────────────────────
              const SizedBox(height: 20),
              _simButtons(context, ref),

              // ── I NEED HELP button ──────────────────────────
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BreathingExerciseScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text(
                    'I NEED HELP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}