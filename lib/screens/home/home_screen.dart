import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/stress_provider.dart';
import 'widgets/stress_arc.dart';
import 'widgets/stress_chart.dart';
import 'widgets/sensor_row.dart';
import '../alert/alert_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<double>(
      stressProvider.select((s) => s.stressScore),
      (previous, nextScore) {
        if (nextScore >= 75) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AlertScreen()),
          );
        }
      },
    );

    final stress = ref.watch(stressProvider);
    final stressHistory = ref.watch(stressProvider.notifier).stressHistory;
    final score = stress.stressScore;

    final color = score < 40
        ? const Color(0xFF2D6A4F)
        : score < 75
        ? const Color(0xFFB5B5B5)
        : const Color(0xFFFFFFFF);

    final status = score < 40 ? 'Calm' : score < 75 ? 'Rising' : 'Alert';

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRESENSE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Neural Monitor',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(4),
                      color: color.withOpacity(0.08),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              StressArc(score: score, color: color),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  stress.stressScore > 0 ? 'MODEL ACTIVE' : 'CALIBRATING...',
                  style: TextStyle(
                    color: const Color(0xFF2D6A4F).withOpacity(0.7),
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Center(
                child: Text(
                  'ML RISK: ${(stress.mlRisk * 100).toInt()}%',
                  style: TextStyle(
                    color: stress.mlRisk > 0.75
                        ? Colors.white
                        : const Color(0xFF666666),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: stress.mlRisk > 0.75
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              StressChart(
                history: stressHistory,
                color: color,
              ),

              const SizedBox(height: 32),

              SensorRow(
                hr: stress.hr.toInt(),
                hrv: stress.hrv,
                movement: stress.movement,
                hrTrend: stress.hrTrend,
                breathingRate: stress.breathingRate,
                stress: stress.stressScore,
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(stressProvider.notifier)
                          .triggerStressSpike(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF444444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'SIMULATE',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(stressProvider.notifier).calm(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2D6A4F)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'CALM',
                        style: TextStyle(
                          color: Color(0xFF2D6A4F),
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'I NEED HELP NOW',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
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