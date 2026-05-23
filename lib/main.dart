import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/calibration/calibration_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseService.instance.initialize();
  } catch (_) {
    // Firebase optional until project credentials are configured.
  }

  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
  await Permission.locationWhenInUse.request();
  await Permission.microphone.request();

  runApp(const ProviderScope(child: PreSenseApp()));
}

class PreSenseApp extends StatelessWidget {
  const PreSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PreSense',
      theme: AppTheme.light,
      home: const CalibrationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
