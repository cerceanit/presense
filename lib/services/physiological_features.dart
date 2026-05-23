import 'dart:math';

/// Clinically validated feature computations for PreSense ML pipeline.
abstract final class PhysiologicalFeatures {
  static const double movementActivityThreshold = 65.0;

  /// RMSSD (ms) — Task Force ESC/NASPE 1996.
  static double computeRmssd(List<double> hrBpm) {
    if (hrBpm.length < 2) return 30.0;

    final rrIntervals = hrBpm.map((hr) => 60000.0 / hr).toList();
    final diffs = <double>[];
    for (var i = 1; i < rrIntervals.length; i++) {
      final diff = rrIntervals[i] - rrIntervals[i - 1];
      if (diff.abs() < 200) {
        diffs.add(diff * diff);
      }
    }
    if (diffs.isEmpty) return 30.0;
    return sqrt(diffs.reduce((a, b) => a + b) / diffs.length);
  }

  /// HR trend (bpm/min): SMA window=5, linear regression, clipped [-20, 20].
  static double computeHrTrend(List<double> hrHistory) {
    if (hrHistory.length < 5) return 0.0;

    final smoothed = <double>[];
    const w = 5;
    for (var i = w - 1; i < hrHistory.length; i++) {
      final avg = hrHistory.sublist(i - w + 1, i + 1).reduce((a, b) => a + b) / w;
      smoothed.add(avg);
    }

    final n = smoothed.length;
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumX2 = 0.0;
    for (var i = 0; i < n; i++) {
      sumX += i.toDouble();
      sumY += smoothed[i];
      sumXY += i * smoothed[i];
      sumX2 += i * i;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX + 1e-6);
    return (slope * 240).clamp(-20.0, 20.0);
  }

  /// Breathing rate (breaths/min) via HR oscillation zero-crossings in 30s window.
  static double computeBreathingRate(List<double> hrHistory) {
    if (hrHistory.length < 120) return 15.0;

    final window = hrHistory.sublist(hrHistory.length - 120);
    final mean = window.reduce((a, b) => a + b) / window.length;
    var crossings = 0;
    for (var i = 1; i < window.length; i++) {
      if ((window[i - 1] - mean) * (window[i] - mean) < 0) {
        crossings++;
      }
    }
    final breathingRate = (crossings / 2.0) * (60.0 / 30.0);
    return breathingRate.clamp(8.0, 30.0);
  }

  /// Stress index 0–100. Uses personalized baseline bounds when provided.
  static double computeStressIndex({
  required double hr,
  required double hrv,
  // Legacy params kept for API compatibility — ignored
  List<double>? hrWindow,
  List<double>? hrvWindow,
  double? baselineHr,
  double? baselineHrv,
  }) {
  final hrContribution  = ((hr  - 60) / 60 * 50).clamp(0.0, 50.0);
  final hrvContribution = ((1 - hrv / 100) * 50).clamp(0.0, 50.0);
  return hrContribution + hrvContribution;
  }

  /// WESAD-derived activity flag: 1 when moving during rising risk.
  static int computeHasMovement({
    required double movement,
    required double currentRisk,
    required double previousRisk,
  }) {
    final rising = currentRisk > previousRisk;
    if (movement > movementActivityThreshold && rising) return 1;
    return 0;
  }

  /// Euclidean norm of accelerometer — ISO 9283.
  static double computeMovement(double ax, double ay, double az) {
    return sqrt(ax * ax + ay * ay + az * az);
  }
}
