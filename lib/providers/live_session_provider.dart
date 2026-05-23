import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_colors.dart';
import '../services/firebase_service.dart';
import 'stress_provider.dart';

final liveSessionProvider = Provider<LiveSessionController>((ref) {
  final controller = LiveSessionController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class LiveSessionController {
  LiveSessionController(this._ref);

  final Ref _ref;
  Timer? _timer;
  Position? _lastPosition;
  int _lastCriticalNotifyScore = -1;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _publish());
    _refreshLocation();
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<void> _refreshLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (_) {}
  }

  Future<void> _publish() async {
    await _refreshLocation();
    final reading = _ref.read(stressProvider);
    final score = reading.stressScore.round();
    final stage = AppColors.riskLabel(reading.stressScore);

    await FirebaseService.instance.writeLiveSession({
      'heartRate': reading.hr.round(),
      'hrv': reading.hrv,
      'stressIndex': reading.stressScore,
      'riskScore': score,
      'alertStage': stage,
      'isMoving': reading.movement > 0.35,
      'latitude': _lastPosition?.latitude ?? 0.0,
      'longitude': _lastPosition?.longitude ?? 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (score >= 85 && _lastCriticalNotifyScore < 85) {
      _lastCriticalNotifyScore = score;
      await FirebaseService.instance.notifyParentCritical(
        riskScore: score,
        alertStage: stage,
      );
    } else if (score < 85) {
      _lastCriticalNotifyScore = -1;
    }
  }
}
