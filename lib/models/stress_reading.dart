class StressReading {
  final double hr;
  final double hrv;
  final double movement;
  final double stressScore;
  final double hrTrend;
  final double breathingRate;
  final DateTime timestamp;
  final double mlRisk;
  final double stressIndex;        // ← new
  final int calibrationSamples;
  final int dataPointsToday;

  StressReading({
    required this.hr,
    required this.hrv,
    required this.movement,
    required this.stressScore,
    required this.hrTrend,
    required this.breathingRate,
    required this.timestamp,
    required this.mlRisk,
    this.stressIndex        = 0.0, // ← new
    this.calibrationSamples = 0,
    this.dataPointsToday    = 0,
  });

  StressReading copyWith({
    double?   hr,
    double?   hrv,
    double?   movement,
    double?   stressScore,
    double?   hrTrend,
    double?   breathingRate,
    double?   mlRisk,
    double?   stressIndex,          // ← new
    DateTime? timestamp,
    int?      calibrationSamples,
    int?      dataPointsToday,
  }) {
    return StressReading(
      hr:                 hr                 ?? this.hr,
      hrv:                hrv                ?? this.hrv,
      movement:           movement           ?? this.movement,
      stressScore:        stressScore        ?? this.stressScore,
      hrTrend:            hrTrend            ?? this.hrTrend,
      breathingRate:      breathingRate      ?? this.breathingRate,
      mlRisk:             mlRisk             ?? this.mlRisk,
      stressIndex:        stressIndex        ?? this.stressIndex, // ← new
      timestamp:          timestamp          ?? this.timestamp,
      calibrationSamples: calibrationSamples ?? this.calibrationSamples,
      dataPointsToday:    dataPointsToday    ?? this.dataPointsToday,
    );
  }
}