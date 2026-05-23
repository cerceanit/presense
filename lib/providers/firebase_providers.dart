import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';

final breathingMediaUrlProvider = StreamProvider<String?>((ref) {
  return FirebaseService.instance.breathingMediaUrlStream();
});

final customQuietZonesProvider = StreamProvider<List<CustomQuietZone>>((ref) {
  return FirebaseService.instance.quietZonesStream();
});
