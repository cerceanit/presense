import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stress_provider.dart';

const _maxPoints = 40;

class ChartHistory {
  final List<double> heartRate;
  final List<double> hrv;
  final List<double> respiratoryRate;
  final List<double> movement;
  final List<double> hrTrend;
  final int dataPointsToday;

  const ChartHistory({
    this.heartRate      = const [],
    this.hrv            = const [],
    this.respiratoryRate = const [],
    this.movement       = const [],
    this.hrTrend        = const [],
    this.dataPointsToday = 0,
  });

  ChartHistory copyWith({
    List<double>? heartRate,
    List<double>? hrv,
    List<double>? respiratoryRate,
    List<double>? movement,
    List<double>? hrTrend,
    int?          dataPointsToday,
  }) {
    return ChartHistory(
      heartRate:       heartRate       ?? this.heartRate,
      hrv:             hrv             ?? this.hrv,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      movement:        movement        ?? this.movement,
      hrTrend:         hrTrend         ?? this.hrTrend,
      dataPointsToday: dataPointsToday ?? this.dataPointsToday,
    );
  }
}

List<double> _append(List<double> list, double value) {
  final next = [...list, value];
  if (next.length > _maxPoints) next.removeAt(0);
  return next;
}

final chartHistoryProvider =
    StateNotifierProvider<ChartHistoryNotifier, ChartHistory>((ref) {
  return ChartHistoryNotifier(ref);
});

class ChartHistoryNotifier extends StateNotifier<ChartHistory> {
  ChartHistoryNotifier(this._ref) : super(const ChartHistory()) {
    // Sample immediately on startup — don't wait for calibration
    _sample();
    // Fast sampling every second to fill charts during calibration
    _fastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final notifier = _ref.read(stressProvider.notifier);
      // Only fast-sample during calibration
      if (notifier.isCalibrating) _sample();
    });
    // Normal sampling every 10 seconds always running
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final notifier = _ref.read(stressProvider.notifier);
      // Skip during calibration — fast timer handles it
      if (!notifier.isCalibrating) _sample();
    });
  }

  final Ref   _ref;
  Timer?      _timer;
  Timer?      _fastTimer;

  void _sample() {
    final reading = _ref.read(stressProvider);
    final notifier = _ref.read(stressProvider.notifier);

    // Only add meaningful data — skip if HR is 0 (band not connected yet)
    if (reading.hr <= 0) return;

    state = state.copyWith(
      heartRate:       _append(state.heartRate,       reading.hr),
      hrv:             _append(state.hrv,             reading.hrv),
      respiratoryRate: _append(state.respiratoryRate, reading.breathingRate),
      movement:        _append(state.movement,        reading.movement),
      hrTrend:         _append(state.hrTrend,         reading.hrTrend),
      dataPointsToday: state.dataPointsToday + 1,
    );
    notifier.markSync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fastTimer?.cancel();
    super.dispose();
  }
}