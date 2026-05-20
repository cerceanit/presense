import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stress_reading.dart';
import '../services/band_service.dart';
import '../services/ml_service.dart';

final stressProvider = StateNotifierProvider<StressNotifier, StressReading>((ref) {
  return StressNotifier();
});

class StressNotifier extends StateNotifier<StressReading> {
  final BandService _bandService = BandService();
  final MLService _mlService = MLService();
  Timer? _timer;
  int _lastHR = 0;
  double _lastMovement = 0.1;
  double _hrTrend = 0.0;
  double _breathingRate = 16.0;
  double _mlRisk = 0.0;
  List<int> _recentHR = [];
  StreamSubscription? _accelSub;
  DateTime _lastModelCall = DateTime.fromMillisecondsSinceEpoch(0);
  bool _alertTriggered = false;

  bool _isCalibrated = false;
  bool _isCalibrating = false;
  double _personalBaselineHR = 70.0;
  double _personalBaselineHRV = 50.0;
  double _personalBaselineMovement = 0.1;
  final List<double> _calibrationHR = [];
  final List<double> _calibrationHRV = [];
  final List<double> _calibrationMovement = [];

  final List<Map<String, dynamic>> _dataBuffer = [];
  final List<double> stressHistory = [];

  bool get isCalibrated => _isCalibrated;
  bool get isCalibrating => _isCalibrating;
  int get calibrationProgress => _calibrationHR.length;

  double get _displayStressScore =>
      _isCalibrated ? (_mlRisk * 100).clamp(0, 100) : 0;

  StressNotifier() : super(StressReading(
    hr: 0,
    hrv: 50,
    movement: 0.1,
    stressScore: 0,
    hrTrend: 0.0,
    breathingRate: 16.0,
    mlRisk: 0.0,
    timestamp: DateTime.now(),
  )) {
    _connectBand();
    _startPhoneSensors();
    _startSimulation();
  }

  void startCalibration() {
    _isCalibrating = true;
    _calibrationHR.clear();
    _calibrationHRV.clear();
    _calibrationMovement.clear();
    _isCalibrated = false;
    _alertTriggered = false;
    _lastModelCall = DateTime.fromMillisecondsSinceEpoch(0);
    print("Calibration started");
    _addToBuffer();
  }

  void finishCalibration() {
    if (_calibrationHR.isEmpty) {
      _personalBaselineHR = 72.0;
      _personalBaselineHRV = 50.0;
      _personalBaselineMovement = _lastMovement;
    } else {
      _personalBaselineHR =
          _calibrationHR.reduce((a, b) => a + b) / _calibrationHR.length;
      _personalBaselineHRV =
          _calibrationHRV.reduce((a, b) => a + b) / _calibrationHRV.length;
      _personalBaselineMovement =
          _calibrationMovement.reduce((a, b) => a + b) /
              _calibrationMovement.length;
    }
    _isCalibrated = true;
    _isCalibrating = false;
    _recentHR = List.generate(10, (_) => _personalBaselineHR.toInt());
    _dataBuffer.clear();
    stressHistory.clear();

    print("Calibration complete — "
        "HR: $_personalBaselineHR, "
        "HRV: $_personalBaselineHRV, "
        "Movement: $_personalBaselineMovement, "
        "ML risk: $_mlRisk");

    state = state.copyWith(
      stressScore: _displayStressScore,
      mlRisk: _mlRisk,
    );
  }

  void _collectCalibrationSample(int hr) {
    if (!_isCalibrating || _isCalibrated) return;
    _calibrationHR.add(hr.toDouble());
    _calibrationHRV.add(_calculateHRV());
    _calibrationMovement.add(_lastMovement);
    _trackHeartRate(hr);
  }

  void _trackHeartRate(int hr) {
    _recentHR.add(hr);
    if (_recentHR.length > 10) _recentHR.removeAt(0);
  }

  void _calculateTrendAndBreathing() {
    if (_recentHR.length >= 5) {
      final recent =
          _recentHR.sublist(_recentHR.length - 3).reduce((a, b) => a + b) / 3;
      final older = _recentHR.sublist(0, 3).reduce((a, b) => a + b) / 3;
      _hrTrend = recent - older;
    }
    if (_lastHR > 0) {
      _breathingRate = _lastHR * 0.25;
    }
  }

  double _formulaStressIndex(int hr) {
    final hrScore = ((hr - _personalBaselineHR) / 20 * 100).clamp(0, 100);
    final hrvScore = (100 - _calculateHRV()).clamp(0, 100);
    final movScore =
        ((_lastMovement - _personalBaselineMovement) * 15).clamp(0, 100);
    final trendScore = (_hrTrend * 10).clamp(0, 100);

    return (0.40 * hrScore +
        0.25 * hrvScore +
        0.20 * movScore +
        0.15 * trendScore);
  }

  Map<String, dynamic> _buildBufferPoint({
    double? stressIndex,
    double? hr,
    double? hrv,
    double? movement,
    double? hrTrend,
    double? breathingRate,
  }) {
    final effectiveHr =
        hr ?? (_lastHR > 0 ? _lastHR.toDouble() : _personalBaselineHR);
    return {
      'hr': effectiveHr,
      'hrv': hrv ?? _calculateHRV(),
      'movement': movement ?? _lastMovement,
      'stress_index': stressIndex ??
          (_lastHR > 0 ? _formulaStressIndex(_lastHR) : 0.0),
      'hr_trend': hrTrend ?? _hrTrend,
      'breathing_rate': breathingRate ?? _breathingRate,
    };
  }

  void _addToBuffer({
    double? stressIndex,
    double? hr,
    double? hrv,
    double? movement,
    double? hrTrend,
    double? breathingRate,
    bool forceModel = false,
  }) {
    if (!_isCalibrating && !_isCalibrated) return;

    _dataBuffer.add(_buildBufferPoint(
      stressIndex: stressIndex,
      hr: hr,
      hrv: hrv,
      movement: movement,
      hrTrend: hrTrend,
      breathingRate: breathingRate,
    ));

    if (_dataBuffer.length > 40) _dataBuffer.removeAt(0);
    _maybeRequestModel(force: forceModel);
  }

  void _maybeRequestModel({bool force = false}) {
    if (_dataBuffer.length < 40) return;
    if (!force &&
        DateTime.now().difference(_lastModelCall).inSeconds < 3) return;
    _lastModelCall = DateTime.now();
    unawaited(_sendToModel());
  }

  Future<void> _sendToModel() async {
    if (_dataBuffer.length < 40) return;

    final bufferSnapshot = List<Map<String, dynamic>>.from(_dataBuffer);
    final result = await _mlService.predict(bufferSnapshot);
    if (result == null) return;

    print("ML Risk: ${result.meltdownRisk} | Alert: ${result.alert}");
    _mlRisk = result.meltdownRisk;

    state = state.copyWith(
      mlRisk: _mlRisk,
      stressScore: _isCalibrated ? _displayStressScore : state.stressScore,
    );
  }

  Future<void> _autoCallCaregiver() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final number = prefs.getString('caregiver_number') ?? '';
      if (number.isEmpty) {
        print("No caregiver number saved");
        return;
      }
      print("Auto-calling caregiver: $number");
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      print("Auto-call error: $e");
    }
  }

  void _onHeartRate(int hr) {
    if (hr <= 0) return;
    _stopSimulation();
    _lastHR = hr;
    _collectCalibrationSample(hr);
    if (!_isCalibrating) _trackHeartRate(hr);
    _calculateTrendAndBreathing();
    if (_isCalibrating || _isCalibrated) _addToBuffer();
    _publishSensorState(hr: hr.toDouble());
  }

  void _stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  void _publishSensorState({double? hr}) {
    final displayHr = hr ?? (_lastHR > 0 ? _lastHR.toDouble() : state.hr);
    stressHistory.add(_displayStressScore);
    if (stressHistory.length > 60) stressHistory.removeAt(0);
    state = StressReading(
      hr: displayHr,
      hrv: _calculateHRV(),
      movement: _lastMovement,
      stressScore: _displayStressScore,
      hrTrend: _hrTrend,
      breathingRate: _breathingRate,
      mlRisk: _mlRisk,
      timestamp: DateTime.now(),
    );
  }

  void _connectBand() {
    _bandService.onHRUpdate = _onHeartRate;
    _bandService.scanAndConnect();
  }

  void _startPhoneSensors() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((event) {
      _lastMovement = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      state = state.copyWith(movement: _lastMovement);
    });
  }

  double _calculateHRV() {
    if (_recentHR.length < 2) return 50.0;
    final rrIntervals =
        _recentHR.map((hr) => 60000 / hr.toDouble()).toList();
    var sum = 0.0;
    for (var i = 1; i < rrIntervals.length; i++) {
      sum += pow(rrIntervals[i] - rrIntervals[i - 1], 2);
    }
    return sqrt(sum / (rrIntervals.length - 1)).clamp(20, 100);
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_lastHR > 0) {
        _stopSimulation();
        return;
      }
      if (!_isCalibrating && !_isCalibrated) return;

      final simHR = _personalBaselineHR + (Random().nextDouble() * 6 - 3);
      _trackHeartRate(simHR.toInt());
      _calculateTrendAndBreathing();
      _breathingRate = simHR * 0.25;

      if (_isCalibrating) _collectCalibrationSample(simHR.toInt());
      if (_isCalibrating || _isCalibrated) _addToBuffer(hr: simHR);

      _publishSensorState(hr: simHR);
    });
  }

  void _injectElevatedBuffer({required bool elevated}) {
    final hr = (_lastHR > 0 ? _lastHR : _personalBaselineHR.round()) +
        (elevated ? 18 : -8);
    final stressIndex = elevated ? 92.0 : 12.0;
    final trend = _hrTrend + (elevated ? 8.0 : -4.0);
    final breathing = (hr * 0.25).clamp(12.0, 32.0);

    while (_dataBuffer.length < 40) {
      _dataBuffer.add(_buildBufferPoint());
    }

    for (var i = 0; i < 8; i++) {
      _dataBuffer.removeAt(0);
      _dataBuffer.add(_buildBufferPoint(
        stressIndex: stressIndex,
        hr: hr.toDouble(),
        hrTrend: trend,
        breathingRate: breathing,
        movement: elevated ? _lastMovement * 1.5 : _lastMovement * 0.5,
      ));
    }
  }

  void triggerStressSpike() {
    _injectElevatedBuffer(elevated: true);
    _lastModelCall = DateTime.fromMillisecondsSinceEpoch(0);
    unawaited(_sendToModel());
  }

  void calm() {
    _alertTriggered = false;
    _injectElevatedBuffer(elevated: false);
    _lastModelCall = DateTime.fromMillisecondsSinceEpoch(0);
    unawaited(_sendToModel());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accelSub?.cancel();
    _bandService.disconnect();
    _mlService.dispose();
    super.dispose();
  }
}