import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/stress_provider.dart';
import 'widgets/breathing_guide.dart';
import 'widgets/parent_media_player.dart';

class BreathingExerciseScreen extends ConsumerWidget {
  const BreathingExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stress = ref.watch(stressProvider);
    final score = stress.stressScore;
    final mediaAsync = ref.watch(breathingMediaUrlProvider);
    final calming = score < 60;

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Let's Breathe Together 🌿"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.riskColor(score).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${score.round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.riskColor(score),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mediaAsync.when(
              data: (url) {
                if (url != null && url.isNotEmpty) {
                  return ParentMediaPlayer(mediaUrl: url);
                }
                return _mediaPlaceholder(context);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => _mediaPlaceholder(context),
            ),
            const SizedBox(height: 32),
            const Center(child: BreathingGuide()),
            const SizedBox(height: 24),
            if (calming)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(color: AppColors.success),
                ),
                child: Text(
                  "Great job! You're calming down 🌿",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Your parent will add a breathing guide here 💛',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
