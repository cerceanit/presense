import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PendingScreen { none, breathing, map }

final pendingScreenProvider = StateProvider<PendingScreen>(
  (ref) => PendingScreen.none,
);

final lastAlertThresholdProvider = StateProvider<int>((ref) => 0);
