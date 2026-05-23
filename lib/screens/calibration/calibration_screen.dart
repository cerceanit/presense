import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../providers/stress_provider.dart';
import '../shell/main_shell.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  static const int _totalSeconds = 180;

  late StreamSubscription<dynamic> _timerSub;
  int _secondsLeft = _totalSeconds;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stressProvider.notifier).startCalibration();
    });

    _timerSub = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _done = true;
        }
      });

      if (_secondsLeft == 0) {
        ref.read(stressProvider.notifier).finishCalibration();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timerSub.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final min = _secondsLeft ~/ 60;
    final sec = _secondsLeft % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  void _skip() {
    ref.read(stressProvider.notifier).finishCalibration();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stress = ref.watch(stressProvider);
    final sampleCount = stress.calibrationSamples;
    final progress = 1 - (_secondsLeft / _totalSeconds);

    final titleStyle = GoogleFonts.nunito(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );
    final subtitleStyle = GoogleFonts.nunito(
      fontSize: 16,
      color: AppColors.textSecondary,
    );

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text('Calibrating PreSense', style: titleStyle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Stay still and breathe normally',
                style: subtitleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryAccent,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _done ? 'Done' : _timeLabel,
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!_done) ...[
                          const SizedBox(height: 4),
                          Text(
                            'seconds remaining',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Samples collected: $sampleCount',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      label: 'Heart Rate',
                      value: stress.hr > 0 ? '${stress.hr.round()} bpm' : '--',
                      icon: Icons.favorite_rounded,
                      iconColor: AppColors.critical,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoCard(
                      label: 'Samples',
                      value: '$sampleCount',
                      icon: Icons.analytics_outlined,
                      iconColor: AppColors.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoCard(
                      label: 'Status',
                      value: _done ? 'Done ✓' : 'Collecting...',
                      icon: Icons.sensors_rounded,
                      iconColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'PreSense is learning your baseline patterns',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 16),
              if (!_done)
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip calibration',
                    style: GoogleFonts.nunito(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
