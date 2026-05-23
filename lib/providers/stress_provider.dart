import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stress_reading.dart';
import '../services/band_service.dart';
import '../services/ml_service.dart';
import '../services/physiological_features.dart';

final stressProvider = StateNotifierProvider<StressNotifier, StressReading>(
  (ref) => StressNotifier(),
);

class StressNotifier extends StateNotifier<StressReading> {
  final BandService _bandService = BandService();
  final MLService   _mlService   = MLService();
  Timer? _timer;
  Timer? _debugTimer;

  int    _lastHR              = 0;
  double _lastMovement        = 0.1;
  double _hrTrend             = 0.0;
  double _breathingRate       = 15.0;
  double _mlRisk              = 0.0;
  double _previousMlRisk      = 0.0;
  bool   _hasTriggeredEmergency = false;
  bool   _isSimulating          = false; // gate bypass flag

  final List<double>  _hrHistory  = [];
  StreamSubscription? _accelSub;
  DateTime  _lastModelCall  = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _dataPointsDay;

  bool   _isCalibrated             = false;
  bool   _isCalibrating            = false;
  double _personalBaselineHR       = 78.0;
  double _personalBaselineHRV      = 22.0;
  double _personalBaselineMovement = 0.08;

  final List<double> _calibrationHR       = [];
  final List<double> _calibrationHRV      = [];
  final List<double> _calibrationMovement = [];

  String _guardianPhone = _defaultGuardianPhone;
  static const String _prefGuardianPhone    = 'guardian_phone';
  static const String _defaultGuardianPhone = '+77071033644';

  int _consecutiveHighRiskCount = 0;
  static const int _requiredConsecutive = 3;

  bool _bleConnected = false;
  DateTime? _lastBleHeartRate;

  final List<Map<String, dynamic>> _dataBuffer   = [];
  final List<double>               stressHistory = [];

  bool      get isCalibrated        => _isCalibrated;
  bool      get isCalibrating       => _isCalibrating;
  int       get calibrationProgress => _calibrationHR.length;
  DateTime? lastSyncTime;

  double get currentStressIndex {
    final hr = _lastHR > 0 ? _lastHR.toDouble() : _personalBaselineHR;
    return _computeStressIndex(hr);
  }

  void markSync()      => lastSyncTime = DateTime.now();
  void reconnectBand() => _bandService.scanAndConnect();

  static const double _asdCorrectionFactor = 1.2;

  double get _displayStressScore {
    if (!_isCalibrated) return 0;
    return (_mlRisk * _asdCorrectionFactor * 100).clamp(0, 100);
  }

  static const _prefBaselineHr  = 'baseline_hr';
  static const _prefBaselineHrv = 'baseline_hrv';

  // ── Constructor ───────────────────────────────────────────────
  StressNotifier()
      : super(StressReading(
          hr:            0,
          hrv:           50,
          movement:      0.1,
          stressScore:   0,
          hrTrend:       0.0,
          breathingRate: 15.0,
          mlRisk:        0.0,
          stressIndex:   0.0,
          timestamp:     DateTime.now(),
        )) {
    _connectBand();
    _startPhoneSensors();
    _startSimulation();
    unawaited(_loadBaselinesFromPrefs());
    _debugTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isCalibrated) _printFeatureDebug();
    });
  }

  // ── Prefs ─────────────────────────────────────────────────────
  Future<void> _loadBaselinesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hr    = prefs.getDouble(_prefBaselineHr);
      final hrv   = prefs.getDouble(_prefBaselineHrv);
      final phone = prefs.getString(_prefGuardianPhone);
      if (hr    != null) _personalBaselineHR  = hr;
      if (hrv   != null) _personalBaselineHRV = hrv;
      if (phone != null) _guardianPhone       = phone;
      if (hr != null && hrv != null) {
        _isCalibrated = true;
        debugPrint('Loaded baselines — HR: $hr, HRV: $hrv');
      }
    } catch (e) {
      debugPrint('Failed to load baselines: $e');
    }
  }

  Future<void> _saveBaselinesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefBaselineHr,  _personalBaselineHR);
      await prefs.setDouble(_prefBaselineHrv, _personalBaselineHRV);
    } catch (e) {
      debugPrint('Failed to save baselines: $e');
    }
  }

  // ── Emergency call ────────────────────────────────────────────
  Future<void> _triggerEmergencyCall() async {
    try {
      final uri = Uri.parse('tel:$_guardianPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint('Emergency call triggered to $_guardianPhone');
      } else {
        debugPrint('Cannot launch phone call — uri: $uri');
      }
    } catch (e) {
      debugPrint('Emergency call error: $e');
    }
  }

  Future<void> triggerEmergencyCall() => _triggerEmergencyCall();

  // ── Calibration ───────────────────────────────────────────────
  void startCalibration() {
    _isCalibrating            = true;
    _isCalibrated             = false;
    _lastModelCall            = DateTime.fromMillisecondsSinceEpoch(0);
    _previousMlRisk           = 0.0;
    _consecutiveHighRiskCount = 0;
    _hasTriggeredEmergency    = false;
    _isSimulating             = false;
    _calibrationHR.clear();
    _calibrationHRV.clear();
    _calibrationMovement.clear();
    _dataBuffer.clear();
    state = state.copyWith(calibrationSamples: 0);
    debugPrint('Calibration started');
  }

  void finishCalibration() {
    if (_calibrationHR.isEmpty) {
      _personalBaselineHR       = 72.0;
      _personalBaselineHRV      = 50.0;
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

    _isCalibrated  = true;
    _isCalibrating = false;
    unawaited(_saveBaselinesToPrefs());

    _hrHistory.clear();
    _hrHistory.addAll(List.generate(10, (_) => _personalBaselineHR));
    _dataBuffer.clear();

    debugPrint(
      'Calibration complete — '
      'HR: $_personalBaselineHR, '
      'HRV: $_personalBaselineHRV, '
      'Movement: $_personalBaselineMovement',
    );

    state = state.copyWith(
      stressScore: _displayStressScore,
      mlRisk:      _mlRisk,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_dataBuffer.length < 40) {
        final last = _buildBufferPoint();
        while (_dataBuffer.length < 40) {
          _dataBuffer.add(Map<String, dynamic>.from(last));
        }
      }
      _lastModelCall = DateTime.fromMillisecondsSinceEpoch(0);
      unawaited(_sendToModel());
    });
  }

  void _collectCalibrationSample(int hr) {
    if (!_isCalibrating || _isCalibrated) return;
    _calibrationHR.add(hr.toDouble());
    _calibrationHRV.add(_currentHrv());
    _calibrationMovement.add(_lastMovement);
    _trackHeartRate(hr);
    state = state.copyWith(
      hr:        hr.toDouble(),
      hrv:       _currentHrv(),
      timestamp: DateTime.now(),
    );
  }

  // ── Data points counter ───────────────────────────────────────
  void _resetDataPointsIfNewDay() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_dataPointsDay == null || _dataPointsDay != today) {
      _dataPointsDay = today;
      state = state.copyWith(dataPointsToday: 0);
    }
  }

  void _incrementDataPointsToday() {
    _resetDataPointsIfNewDay();
    state = state.copyWith(dataPointsToday: state.dataPointsToday + 1);
  }

  // ── Physiological helpers ─────────────────────────────────────
  void _trackHeartRate(num hr) {
    _hrHistory.add(hr.toDouble());
    if (_hrHistory.length > 120) _hrHistory.removeAt(0);
  }

  void _updatePhysiologicalFeatures() {
    _hrTrend       = PhysiologicalFeatures.computeHrTrend(_hrHistory);
    _breathingRate = PhysiologicalFeatures.computeBreathingRate(_hrHistory);
  }

  double _currentHrv() =>
      PhysiologicalFeatures.computeRmssd(_hrHistory);

  double _computeStressIndex(double hr) =>
      PhysiologicalFeatures.computeStressIndex(hr: hr, hrv: _currentHrv());

  int _computeHasMovement({double? projectedRisk}) =>
      PhysiologicalFeatures.computeHasMovement(
        movement:     _lastMovement,
        currentRisk:  projectedRisk ?? _mlRisk,
        previousRisk: _previousMlRisk,
      );

  // ── Buffer ────────────────────────────────────────────────────
  Map<String, dynamic> _buildBufferPoint({
    double? stressIndex,
    double? hr,
    double? hrv,
    double? movement,
    double? hrTrend,
    double? breathingRate,
    int?    hasMovement,
    double? projectedRisk,
  }) {
    final effectiveHr  =
        hr ?? (_lastHR > 0 ? _lastHR.toDouble() : _personalBaselineHR);
    final effectiveHrv = hrv ?? _currentHrv();
    final effectiveSI  = stressIndex ?? _computeStressIndex(effectiveHr);

    return {
      'hr':             effectiveHr,
      'hrv':            effectiveHrv,
      'movement':       movement      ?? _lastMovement,
      'stress_index':   effectiveSI,
      'hr_trend':       hrTrend       ?? _hrTrend,
      'breathing_rate': breathingRate ?? _breathingRate,
      'has_movement':   hasMovement   ??
          _computeHasMovement(projectedRisk: projectedRisk),
    };
  }

  void _addToBuffer({
    double? stressIndex,
    double? hr,
    double? hrv,
    double? movement,
    double? hrTrend,
    double? breathingRate,
    bool    forceModel = false,
  }) {
    if (!_isCalibrating && !_isCalibrated) return;

    _dataBuffer.add(_buildBufferPoint(
      stressIndex:   stressIndex,
      hr:            hr,
      hrv:           hrv,
      movement:      movement,
      hrTrend:       hrTrend,
      breathingRate: breathingRate,
    ));

    if (_dataBuffer.length > 40) _dataBuffer.removeAt(0);

    if (_isCalibrating) {
      state = state.copyWith(calibrationSamples: _dataBuffer.length);
    }

    _maybeRequestModel(force: forceModel);
  }

  void _maybeRequestModel({bool force = false}) {
    if (_dataBuffer.length < 40) return;
    final secondsSinceLast =
        DateTime.now().difference(_lastModelCall).inSeconds;
    if (!force && secondsSinceLast < 3) return;
    _lastModelCall = DateTime.now();
    unawaited(_sendToModel());
  }

  // ── ML inference ──────────────────────────────────────────────
  Future<void> _sendToModel() async {
    if (_dataBuffer.length < 40) return;

    // ── Baseline deviation gate ───────────────────────────────
    // Bypassed during demo simulations (_isSimulating = true)
    if (!_isSimulating) {
      final currentHr   = _lastHR > 0 ? _lastHR.toDouble() : _personalBaselineHR;
      final hrDeviation = currentHr - _personalBaselineHR;
      if (hrDeviation.abs() < 5 && _mlRisk < 0.55) {
        debugPrint(
          'Gate filter: HR deviation ${hrDeviation.toStringAsFixed(1)} bpm '
          'from baseline — too small, skipping inference',
        );
        return;
      }
    }
    _isSimulating = false; // reset after one pass
    // ─────────────────────────────────────────────────────────

    final snapshot = List<Map<String, dynamic>>.from(_dataBuffer);
    debugPrint('Sending to model: window size=${snapshot.length}');

    final result = await _mlService.predict(snapshot);
    if (result == null) return;

    final newRisk     = result.meltdownRisk;
    final hasMovement = PhysiologicalFeatures.computeHasMovement(
      movement:     _lastMovement,
      currentRisk:  newRisk,
      previousRisk: _previousMlRisk,
    );

    if (hasMovement == 1 && newRisk > _mlRisk) {
      _consecutiveHighRiskCount = 0;
      debugPrint('Alert suppressed — physical movement ($_lastMovement)');
    } else if (newRisk >= 0.60) {
      _consecutiveHighRiskCount =
          (_consecutiveHighRiskCount + 1).clamp(0, _requiredConsecutive);
      if (_consecutiveHighRiskCount >= _requiredConsecutive) {
        _mlRisk = newRisk;
        debugPrint(
          'Alert confirmed after $_consecutiveHighRiskCount '
          'consecutive readings',
        );
      } else {
        debugPrint(
          'Alert debounced — '
          '$_consecutiveHighRiskCount/$_requiredConsecutive '
          '(need ${_requiredConsecutive - _consecutiveHighRiskCount} more)',
        );
      }
    } else {
      _consecutiveHighRiskCount = 0;
      _mlRisk = newRisk;
    }
    _previousMlRisk = newRisk;

    debugPrint(
      'ML Risk: $_mlRisk '
      '(CatBoost=${result.catboostRisk.toStringAsFixed(3)}, '
      'LightGBM=${result.lightgbmRisk.toStringAsFixed(3)}) | '
      'Alert: ${result.alert}',
    );

    _incrementDataPointsToday();

    state = state.copyWith(
      mlRisk:      _mlRisk,
      stressScore: _isCalibrated ? _displayStressScore : state.stressScore,
      stressIndex: currentStressIndex,
    );

    debugPrint(
      'Risk display: raw=${(_mlRisk * 100).round()}% '
      'corrected=${_displayStressScore.round()}% '
      '(factor=1.2x)',
    );

    if (_mlRisk >= 0.71 && !_hasTriggeredEmergency) {
      _hasTriggeredEmergency = true;
      unawaited(_triggerEmergencyCall());
    }
  }

  // ── Debug print ───────────────────────────────────────────────
  void _printFeatureDebug() {
    final hr          = _lastHR > 0 ? _lastHR.toDouble() : _personalBaselineHR;
    final hrv         = _currentHrv();
    final stressIndex = _computeStressIndex(hr);
    final hasMovement = _computeHasMovement();
    final riskScore   = _displayStressScore;

    final point  = _buildBufferPoint(
      hr:          hr,
      hrv:         hrv,
      movement:    _lastMovement,
      stressIndex: stressIndex,
      hasMovement: hasMovement,
    );
    final scaled = _mlService.scaleLightGbmFeatures(point);

    debugPrint('=== PreSense Features ===');
    debugPrint('HR:             $hr bpm');
    debugPrint('HRV (RMSSD):    $hrv ms');
    debugPrint('Movement:       $_lastMovement');
    debugPrint('has_movement:   $hasMovement');
    debugPrint('Stress Index:   $stressIndex');
    debugPrint('Breathing Rate: $_breathingRate br/min');
    debugPrint('HR Trend:       $_hrTrend bpm/min');
    debugPrint('Risk Score:     ${riskScore.round()} %');
    debugPrint('--- Scaled (LightGBM) ---');
    debugPrint('HR:             ${scaled[0].toStringAsFixed(4)}');
    debugPrint('HRV:            ${scaled[1].toStringAsFixed(4)}');
    debugPrint('Movement:       ${scaled[2].toStringAsFixed(4)}');
    debugPrint('has_movement:   ${scaled[3].toStringAsFixed(4)}');
    debugPrint('Stress Index:   ${scaled[4].toStringAsFixed(4)}');
    debugPrint('Breathing Rate: ${scaled[5].toStringAsFixed(4)}');
    debugPrint('HR Trend:       ${scaled[6].toStringAsFixed(4)}');
    debugPrint('========================');
  }

  // ── BLE callbacks ─────────────────────────────────────────────
  void _onHeartRate(int hr) {
    if (hr <= 0) return;
    debugPrint(
      'HR received: $hr | buffer: ${_dataBuffer.length} | '
      'calibrated: $_isCalibrated',
    );

    _lastBleHeartRate = DateTime.now();
    _timer?.cancel();
    _timer = null;
    _lastHR = hr;

    if (_isCalibrated && _dataBuffer.isNotEmpty) {
      final hasStaleData = _dataBuffer
          .any((p) => (p['hr'] as num).toDouble() == _personalBaselineHR);
      if (hasStaleData) {
        debugPrint('Flushing stale baseline buffer on first real HR');
        _dataBuffer.clear();
      }
    }

    _collectCalibrationSample(hr);
    if (!_isCalibrating) _trackHeartRate(hr);
    _updatePhysiologicalFeatures();
    if (_isCalibrating || _isCalibrated) _addToBuffer();
    if (_isCalibrating || _isCalibrated) _incrementDataPointsToday();
    _publishSensorState(hr: hr.toDouble());
  }

  void _publishSensorState({double? hr}) {
    final displayHr    = hr ?? (_lastHR > 0 ? _lastHR.toDouble() : state.hr);
    final si           = _computeStressIndex(displayHr);
    final historyValue = _isCalibrating ? si : _displayStressScore;
    stressHistory.add(historyValue);
    if (stressHistory.length > 60) stressHistory.removeAt(0);

    state = state.copyWith(
      hr:            displayHr,
      hrv:           _currentHrv(),
      movement:      _lastMovement,
      stressScore:   _displayStressScore,
      hrTrend:       _hrTrend,
      breathingRate: _breathingRate,
      mlRisk:        _mlRisk,
      stressIndex:   si,
      timestamp:     DateTime.now(),
    );
  }

  // ── Band & sensors ────────────────────────────────────────────
  void _connectBand() {
    _bandService.onHRUpdate = _onHeartRate;

    final deviceStream = _bandService.deviceConnectionState;
    if (deviceStream != null) {
      deviceStream.listen((state) {
        _bleConnected = (state == BluetoothConnectionState.connected);
        debugPrint('BLE connection state: $state → _bleConnected=$_bleConnected');
        if (!_bleConnected) {
          _lastBleHeartRate = null;
        }
      });
    }

    _bandService.scanAndConnect();
  }

  void _startPhoneSensors() {
    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((event) {
      _lastMovement = PhysiologicalFeatures.computeMovement(
        event.x, event.y, event.z,
      );
      state = state.copyWith(movement: _lastMovement);
    });
  }

  // ── Simulation ────────────────────────────────────────────────
  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_bleConnected) {
        final secSinceBle = _lastBleHeartRate == null
            ? 999
            : DateTime.now().difference(_lastBleHeartRate!).inSeconds;
        if (secSinceBle < 5) {
          debugPrint(
              'Simulation paused: BLE active ($_lastHR bpm, ${secSinceBle}s ago)');
          _timer?.cancel();
          _timer = null;
          return;
        }
      }

      if (!_isCalibrating && !_isCalibrated) return;

      final simHR = _personalBaselineHR + (Random().nextDouble() * 6 - 3);
      debugPrint('Current HR: ${simHR.round()} bpm (baseline=$_personalBaselineHR)');
      _trackHeartRate(simHR);
      _updatePhysiologicalFeatures();
      if (_isCalibrating) _collectCalibrationSample(simHR.round());
      if (_isCalibrating || _isCalibrated) _addToBuffer(hr: simHR);
      _publishSensorState(hr: simHR);
    });
  }

  // ── Demo simulation helpers ───────────────────────────────────
  void _fillBuffer({
    required double stressIndex,
    required double hr,
    required double hrTrend,
    required double breathingRate,
    required double movement,
    int count = 40,
  }) {
    while (_dataBuffer.length < 40) {
      _dataBuffer.add(_buildBufferPoint());
    }
    for (var i = 0; i < count; i++) {
      if (_dataBuffer.length >= 40) _dataBuffer.removeAt(0);
      _dataBuffer.add(_buildBufferPoint(
        stressIndex:   stressIndex,
        hr:            hr,
        hrTrend:       hrTrend,
        breathingRate: breathingRate,
        movement:      movement,
      ));
    }
  }

  void _resetForSimulation() {
    _consecutiveHighRiskCount = _requiredConsecutive;
    _mlRisk                   = 0.0;
    _previousMlRisk           = 0.0;
    _lastModelCall            = DateTime.fromMillisecondsSinceEpoch(0);
    _hasTriggeredEmergency    = false;
    _isSimulating             = true; // bypass gate for this inference
  }

  void simulateWatch() {
    _fillBuffer(
      stressIndex:   55.0,
      hr:            _personalBaselineHR + 8,
      hrTrend:       2.0,
      breathingRate: 17.0,
      movement:      0.05,
      count:         10,
    );
    _resetForSimulation();
    unawaited(_sendToModel());
  }

  void simulateAlert() {
    _fillBuffer(
      stressIndex:   72.0,
      hr:            _personalBaselineHR + 14,
      hrTrend:       5.0,
      breathingRate: 20.0,
      movement:      0.05,
      count:         20,
    );
    _resetForSimulation();
    unawaited(_sendToModel());
  }

  void simulateCritical() {
    _fillBuffer(
      stressIndex:   92.0,
      hr:            _personalBaselineHR + 22,
      hrTrend:       8.0,
      breathingRate: 24.0,
      movement:      0.05,
      count:         40,
    );
    _resetForSimulation();
    unawaited(_sendToModel());
  }

  void triggerStressSpike() => simulateCritical();

  void calm() {
    _fillBuffer(
      stressIndex:   15.0,
      hr:            _personalBaselineHR - 5,
      hrTrend:       -2.0,
      breathingRate: 13.0,
      movement:      0.1,
      count:         40,
    );
    _consecutiveHighRiskCount = 0;
    _mlRisk                   = 0.0;
    _previousMlRisk           = 0.0;
    _lastModelCall            = DateTime.fromMillisecondsSinceEpoch(0);
    _hasTriggeredEmergency    = false;
    _isSimulating             = true; // bypass gate so calm registers immediately
    unawaited(_sendToModel());
  }

  void resetAlerts() {
    _consecutiveHighRiskCount = 0;
    _mlRisk                   = 0.0;
    _previousMlRisk           = 0.0;
    _lastModelCall            = DateTime.fromMillisecondsSinceEpoch(0);
    _hasTriggeredEmergency    = false;
    _isSimulating             = false;
    debugPrint('Alert state reset');
  }

  // ── Dispose ───────────────────────────────────────────────────
  @override
  void dispose() {
    _timer?.cancel();
    _debugTimer?.cancel();
    _accelSub?.cancel();
    _bandService.disconnect();
    _mlService.dispose();
    super.dispose();
  }
}