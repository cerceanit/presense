import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/band_service.dart';

class BandStatus {
  final bool connected;
  final int? rssi;
  final DateTime? lastSync;

  const BandStatus({
    required this.connected,
    this.rssi,
    this.lastSync,
  });

  static const disconnected = BandStatus(connected: false);
}

final bandStatusProvider = StreamProvider<BandStatus>((ref) async* {
  final device = BluetoothDevice.fromId(BandService.bandMac);
  await for (final state in device.connectionState) {
    final connected = state == BluetoothConnectionState.connected;
    int? rssi;
    if (connected) {
      try {
        rssi = await device.readRssi();
      } catch (_) {
        rssi = null;
      }
    }
    yield BandStatus(
      connected: connected,
      rssi: rssi,
      lastSync: connected ? DateTime.now() : null,
    );
  }
});
