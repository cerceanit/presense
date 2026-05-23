import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

class BreathingGuide extends StatefulWidget {
  const BreathingGuide({super.key});

  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _phaseLabel = 'Breathe in...';
  Timer? _cycleTimer;
  int _phaseIndex = 0;

  static const _phases = [
    _Phase('Breathe in...', Duration(seconds: 4), 0.45, 0.95, true),
    _Phase('Hold...', Duration(seconds: 2), 0.95, 0.95, false),
    _Phase('Breathe out...', Duration(seconds: 6), 0.95, 0.4, false),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _runPhase(0);
  }

  void _runPhase(int index) {
    _phaseIndex = index % _phases.length;
    final phase = _phases[_phaseIndex];
    setState(() => _phaseLabel = phase.label);

    _controller.duration = phase.duration;
    if (phase.animateSize) {
      _controller
        ..reset()
        ..forward();
    } else if (phase.label == 'Hold...') {
      _controller.value = 1.0;
      _pulseHold();
    } else {
      _controller
        ..reset()
        ..forward();
    }

    _cycleTimer?.cancel();
    _cycleTimer = Timer(phase.duration, () => _runPhase(_phaseIndex + 1));
  }

  void _pulseHold() {
    _controller.repeat(reverse: true, period: const Duration(milliseconds: 800));
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _controller.stop();
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phases[_phaseIndex];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final size =
            phase.minSize + (phase.maxSize - phase.minSize) * t;
        final color = Color.lerp(
          AppColors.primaryAccent,
          AppColors.secondaryBackground,
          1 - size,
        )!;

        return Column(
          children: [
            Container(
              width: 220 * size,
              height: 220 * size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.35),
                border: Border.all(color: AppColors.primaryAccent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _phaseLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _Phase {
  final String label;
  final Duration duration;
  final double minSize;
  final double maxSize;
  final bool animateSize;

  const _Phase(
    this.label,
    this.duration,
    this.minSize,
    this.maxSize,
    this.animateSize,
  );
}
