import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/calibration/calibration_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      theme: AppTheme.dark,
      home: const CalibrationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}