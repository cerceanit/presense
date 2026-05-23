import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class MLService {
  static const String _lightgbmOnnxAsset =
      'assets/models/presense_lightgbm_v3_flat.onnx';
  static const int _windowSize   = 40;
  static const int _featureCount = 7;

  // ── RobustScaler params (v3 — fixed stress_index formula) ─────
  // Feature order: hr, hrv, movement, has_movement,
  //                stress_index, breathing_rate, hr_trend
  // stress_index = ((hr-60)/60*50).clamp(0,50)
  //              + ((1-hrv/100)*50).clamp(0,50)
  static const List<double> center = [
    73.8940469385,  // hr
    14.0295584539,  // hrv
     0.0000000000,  // movement
     0.0000000000,  // has_movement
    54.1503380721,  // stress_index
    15.0000000000,  // breathing_rate
     0.0000000000,  // hr_trend
  ];

  static const List<double> scale = [
    14.1812773565,  // hr
     6.6851076714,  // hrv
     1.0000000000,  // movement
     1.0000000000,  // has_movement
    12.0355565952,  // stress_index
     1.0000000000,  // breathing_rate
     1.0000000000,  // hr_trend
  ];

  static const List<double> scalerCenter = center;
  static const List<double> scalerScale  = scale;

  OnnxRuntime?  _ort;
  OrtSession?   _session;
  String?       _inputName;
  List<String>  _outputNames = [];

  // ── Load ──────────────────────────────────────────────────────
  Future<void> _ensureLoaded() async {
    if (_session != null) return;
    _ort         ??= OnnxRuntime();
    _session       = await _ort!.createSessionFromAsset(_lightgbmOnnxAsset);
    _inputName     = _session!.inputNames.first;
    _outputNames   = _session!.outputNames;
    debugPrint('ML: LightGBM v3-flat loaded');
    debugPrint('ML: inputs=${_session!.inputNames}');
    debugPrint('ML: outputs=$_outputNames');
  }

  // ── Scale ─────────────────────────────────────────────────────
  List<double> _scale(Map<String, dynamic> point) {
    final raw = [
      (point['hr']             as num).toDouble(),
      (point['hrv']            as num).toDouble(),
      (point['movement']       as num).toDouble(),
      (point['has_movement']   as num).toDouble(),
      (point['stress_index']   as num).toDouble(),
      (point['breathing_rate'] as num).toDouble(),
      (point['hr_trend']       as num).toDouble(),
    ];
    return List.generate(
      _featureCount,
      (i) => (raw[i] - center[i]) / scale[i],
    );
  }

  List<double> scaleLightGbmFeatures(Map<String, dynamic> point) =>
      _scale(point);

  // ── Predict ───────────────────────────────────────────────────
  Future<MLResult?> predict(List<Map<String, dynamic>> window) async {
    if (window.length != _windowSize) return null;

    OrtValue?              inputTensor;
    Map<String, OrtValue>? outputs;

    try {
      await _ensureLoaded();

      final scaled = _scale(window.last);
      final input  = Float32List.fromList(scaled);

      debugPrint('=== PreSense Input ===');
      debugPrint('raw:    ${_rawFeatures(window.last)}');
      debugPrint('scaled: $scaled');

      inputTensor = await OrtValue.fromList(
        input.toList(),
        [1, _featureCount],
      );

      final sw = Stopwatch()..start();
      outputs = await _runWithFallback(inputTensor);
      sw.stop();

      if (outputs == null || outputs.isEmpty) {
        debugPrint('ML: empty outputs — using neutral result');
        return _neutralResult();
      }

      debugPrint('ML: output keys=${outputs.keys.toList()}');

      final prob = await _extractProbability(outputs);

      debugPrint(
        'ML: P(stress)=${prob.toStringAsFixed(4)} '
        'risk=${(prob * 100).round()}% '
        'time=${sw.elapsedMilliseconds}ms',
      );

      return MLResult(
        meltdownRisk: prob,
        riskScore:    (prob * 100).round().clamp(0, 100),
        alert:        prob > 0.75,
        confidence:   prob,
      );

    } catch (e, st) {
      debugPrint('ML error: $e\n$st');
      return _neutralResult();
    } finally {
      try { inputTensor?.dispose(); } catch (_) {}
      if (outputs != null) {
        for (final v in outputs.values) {
          try { v.dispose(); } catch (_) {}
        }
      }
    }
  }

  // ── Run with fallback strategies ──────────────────────────────
  Future<Map<String, OrtValue>?> _runWithFallback(
      OrtValue inputTensor) async {

    // Strategy 1: run all outputs
    try {
      final out = await _session!.run({_inputName!: inputTensor});
      debugPrint('ML: strategy 1 succeeded');
      return out;
    } catch (e1) {
      debugPrint('ML: strategy 1 failed ($e1)');
    }

    // Strategy 2: reload session and retry
    try {
      _session?.close();
      _session = null;
      await _ensureLoaded();
      final out = await _session!.run({_inputName!: inputTensor});
      debugPrint('ML: strategy 2 (reload) succeeded');
      return out;
    } catch (e2) {
      debugPrint('ML: strategy 2 failed ($e2)');
    }

    return null;
  }

  // ── Extract P(class=1) ────────────────────────────────────────
  Future<double> _extractProbability(
      Map<String, OrtValue> outputs) async {

    OrtValue? probTensor;
    for (final entry in outputs.entries) {
      if (entry.key.toLowerCase().contains('prob')) {
        probTensor = entry.value;
        debugPrint('ML: using output "${entry.key}"');
        break;
      }
    }
    probTensor ??= outputs.values.last;

    try {
      final raw = await probTensor.asList();
      debugPrint('ML: prob raw=$raw');
      return _parseProb(raw).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('ML: asList() failed ($e)');
    }

    try {
      // ignore: avoid_dynamic_calls
      final val = (probTensor as dynamic).value;
      debugPrint('ML: .value=$val');
      return _parseProb(val).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('ML: .value failed ($e)');
    }

    return 0.0;
  }

  // ── Parse probability — zipmap=False produces [[p0, p1]] ──────
  double _parseProb(dynamic raw) {
    if (raw == null) return 0.0;

    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;

      // ① [[p0, p1]] — PRIMARY: zipmap=False flat tensor format
      if (first is List && first.length > 1) {
        debugPrint('ML: parsing [[p0,p1]] format');
        return (first[1] as num).toDouble();
      }

      // ② [p0, p1] — flat list directly
      if (raw.length > 1 && raw[1] is num) {
        debugPrint('ML: parsing [p0,p1] format');
        return (raw[1] as num).toDouble();
      }

      // ③ [{0: p0, 1: p1}] — old map format (fallback)
      if (first is Map) {
        debugPrint('ML: parsing map format');
        final p1 = first[1] ?? first['1'] ?? first[1.0];
        if (p1 != null) return (p1 as num).toDouble();
        if (first.length == 1) {
          return (first.values.first as num).toDouble();
        }
      }

      // ④ [p] single value
      if (raw.length == 1 && raw.first is num) {
        debugPrint('ML: parsing single value format');
        return (raw.first as num).toDouble();
      }
    }

    // ⑤ {0: p0, 1: p1} direct map
    if (raw is Map) {
      debugPrint('ML: parsing direct map format');
      final p1 = raw[1] ?? raw['1'];
      if (p1 != null) return (p1 as num).toDouble();
    }

    // ⑥ direct number
    if (raw is num) {
      debugPrint('ML: parsing direct num format');
      return raw.toDouble();
    }

    debugPrint('ML: could not parse prob from $raw');
    return 0.0;
  }

  // ── Neutral result ────────────────────────────────────────────
  MLResult _neutralResult() => const MLResult(
        meltdownRisk: 0.35,
        riskScore:    35,
        alert:        false,
        confidence:   0.0,
      );

  // ── Debug helper ──────────────────────────────────────────────
  List<double> _rawFeatures(Map<String, dynamic> point) => [
        (point['hr']             as num).toDouble(),
        (point['hrv']            as num).toDouble(),
        (point['movement']       as num).toDouble(),
        (point['has_movement']   as num).toDouble(),
        (point['stress_index']   as num).toDouble(),
        (point['breathing_rate'] as num).toDouble(),
        (point['hr_trend']       as num).toDouble(),
      ];

  void dispose() {
    _session?.close();
    _session = null;
    _ort     = null;
  }
}

// ── Result ────────────────────────────────────────────────────────
class MLResult {
  final double meltdownRisk;
  final int    riskScore;
  final bool   alert;
  final double confidence;

  double get catboostRisk => meltdownRisk;
  double get lightgbmRisk => meltdownRisk;

  const MLResult({
    required this.meltdownRisk,
    required this.riskScore,
    required this.alert,
    required this.confidence,
  });
}