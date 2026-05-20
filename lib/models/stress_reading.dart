class StressReading {
  final double hr;
  final double hrv;
  final double movement;
  final double stressScore;
  final double hrTrend;
  final double breathingRate;
  final DateTime timestamp;
  final double mlRisk;

  StressReading({
    required this.hr,
    required this.hrv,
    required this.movement,
    required this.stressScore,
    required this.hrTrend,
    required this.breathingRate,
    required this.timestamp,
    required this.mlRisk,
  });

  StressReading copyWith({
    double? hr,
    double? hrv,
    double? movement,
    double? stressScore,
    double? hrTrend,
    double? breathingRate,
    double? mlRisk,
    DateTime? timestamp,
  }) {
    return StressReading(
      hr: hr ?? this.hr,
      hrv: hrv ?? this.hrv,
      movement: movement ?? this.movement,
      stressScore: stressScore ?? this.stressScore,
      hrTrend: hrTrend ?? this.hrTrend,
      breathingRate: breathingRate ?? this.breathingRate,
      mlRisk: mlRisk ?? this.mlRisk,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}