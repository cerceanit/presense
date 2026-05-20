class Episode {
  final int? id;
  final DateTime timestamp;
  final double peakStress;
  final String trigger;

  Episode({
    this.id,
    required this.timestamp,
    required this.peakStress,
    required this.trigger,
  });
}