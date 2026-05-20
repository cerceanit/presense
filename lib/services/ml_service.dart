import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class MLService {
  static const String _onnxAsset = 'assets/models/presense.onnx';
  static const int _windowSize = 40;
  static const int _featureCount = 240;

  OnnxRuntime? _ort;
  OrtSession? _onnxSession;
  String? _onnxInputName;
  String? _onnxOutputName;

  Float32List _flattenWindow(List<Map<String, dynamic>> window) {
    final flat = Float32List(_featureCount);
    var idx = 0;
    for (final point in window) {
      flat[idx++] = (point['hr'] as num).toDouble();
      flat[idx++] = (point['hrv'] as num).toDouble();
      flat[idx++] = (point['movement'] as num).toDouble();
      flat[idx++] = (point['stress_index'] as num).toDouble();
      flat[idx++] = (point['hr_trend'] as num).toDouble();
      flat[idx++] = (point['breathing_rate'] as num).toDouble();
    }
    return flat;
  }

  Future<void> _ensureLoaded() async {
    if (_onnxSession != null) return;

    _ort = OnnxRuntime();
    _onnxSession = await _ort!.createSessionFromAsset(_onnxAsset);
    _onnxInputName = _onnxSession!.inputNames.first;
    _onnxOutputName = _onnxSession!.outputNames.first;
    print('ML on-device: ONNX loaded');
  }

  Future<MLResult?> predict(List<Map<String, dynamic>> window) async {
    if (window.length != _windowSize) return null;

    try {
      await _ensureLoaded();
      final sw = Stopwatch()..start();
      final risk = await _predictOnnx(_flattenWindow(window));

      sw.stop();
      debugPrint(
        'ML on-device inference ${sw.elapsedMilliseconds}ms '
        '(ONNX) risk=${risk.toStringAsFixed(3)}',
      );

      return MLResult(
        meltdownRisk: risk,
        alert: risk > 0.75,
        confidence: risk,
      );
    } catch (e) {
      debugPrint('ML on-device error: $e');
      return null;
    }
  }

  double _readScore(dynamic raw) {
    if (raw is! List || raw.isEmpty) return 0;
    final first = raw.first;
    if (first is List && first.isNotEmpty) {
      return (first.first as num).toDouble();
    }
    return (first as num).toDouble();
  }

  Future<double> _predictOnnx(Float32List input) async {
    final session = _onnxSession!;
    final inputTensor = await OrtValue.fromList(
      input.toList(),
      [1, _featureCount],
    );

    final outputs = await session.run({_onnxInputName!: inputTensor});
    final outTensor = outputs[_onnxOutputName!]!;
    final raw = await outTensor.asList();

    inputTensor.dispose();
    outTensor.dispose();

    return _readScore(raw).clamp(0.0, 1.0);
  }

  void dispose() {
    _onnxSession?.close();
    _onnxSession = null;
    _ort = null;
  }
}

class MLResult {
  final double meltdownRisk;
  final bool alert;
  final double confidence;

  MLResult({
    required this.meltdownRisk,
    required this.alert,
    required this.confidence,
  });
}
