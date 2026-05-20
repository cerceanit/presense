import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BandService {
  BluetoothDevice? _device;
  Function(int hr)? onHRUpdate;
  bool _hrFound = false;
  bool _servicesDiscovered = false;
  bool _isConnecting = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  static const String bandMac = "90:EF:4A:18:FB:BD";
  static const Duration _gattDelay = Duration(milliseconds: 500);

  Future<void> scanAndConnect() async {
    if (_isConnecting) {
      print("Already connecting — skipping");
      return;
    }

    if (_device != null) {
      final currentState = await _device!.connectionState.first;
      if (currentState == BluetoothConnectionState.connected) {
        print("Already connected — skipping");
        return;
      }
    }

    _isConnecting = true;
    print("Connecting directly to Band 9 by MAC...");
    _device = BluetoothDevice.fromId(bandMac);
    await _connectToDevice(_device!);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      print("Connecting to ${device.remoteId}...");

      await _connectionSub?.cancel();
      _connectionSub = null;

      _connectionSub = device.connectionState.listen((state) async {
        print("BLE state: $state");

        if (state == BluetoothConnectionState.connected &&
            !_servicesDiscovered) {
          _isConnecting = false;
          _servicesDiscovered = true;
          print("Connected — discovering services");
          try {
            await device.requestConnectionPriority(
              connectionPriorityRequest: ConnectionPriority.balanced,
            );
          } catch (e) {
            print("Connection priority request failed: $e");
          }
          await _discoverServices();
        }

        if (state == BluetoothConnectionState.disconnected) {
          _servicesDiscovered = false;
          _hrFound = false;
          _isConnecting = false;
          print("Disconnected — reconnecting in 5s...");
          Future.delayed(const Duration(seconds: 5), () {
            scanAndConnect();
          });
        }
      });

      await device.connect(
        autoConnect: false,
        mtu: null,
      );
    } catch (e) {
      _isConnecting = false;
      print("Connection error: $e");
      Future.delayed(const Duration(seconds: 5), () {
        scanAndConnect();
      });
    }
  }

  void _handleNotification(String uuid, List<int> value) {
    final lowerUuid = uuid.toLowerCase();

    if (lowerUuid.contains("005e")) return;
    if (value.isEmpty) return;
    if (value[0] == 0xA5) return;

    if (lowerUuid.contains("2a37")) {
      if (value.length >= 2 && value[1] >= 45 && value[1] <= 180) {
        _emitHeartRate(value[1], source: "2a37", uuid: lowerUuid);
      }
      return;
    }

    if (_hrFound) return;

    for (var i = 0; i < value.length; i++) {
      if (value[i] >= 45 && value[i] <= 180) {
        _emitHeartRate(
          value[i],
          source: "fallback",
          uuid: lowerUuid,
          byteIndex: i,
        );
        return;
      }
    }
  }

  void _emitHeartRate(
    int hr, {
    required String source,
    required String uuid,
    int? byteIndex,
  }) {
    if (source == "2a37") {
      print(">>> HR 2a37: $hr");
    } else {
      print(">>> HR fallback: $hr from $uuid byte[$byteIndex]");
    }
    onHRUpdate?.call(hr);
    _hrFound = true;
  }

  Future<void> _subscribeCharacteristic(
    BluetoothCharacteristic c,
    String uuid,
  ) async {
    await Future.delayed(_gattDelay);

    try {
      await c.setNotifyValue(true);
      print("Subscribed to $uuid");
      c.onValueReceived.listen((value) {
        print("  NOTIFY $uuid: $value");
        _handleNotification(uuid, value);
      });
    } catch (e) {
      print("Subscribe failed $uuid: $e — retrying in 1s");
      await Future.delayed(const Duration(seconds: 1));
      try {
        await c.setNotifyValue(true);
        print("Subscribed to $uuid (retry)");
        c.onValueReceived.listen((value) {
          print("  NOTIFY $uuid: $value");
          _handleNotification(uuid, value);
        });
      } catch (e2) {
        print("Subscribe retry failed $uuid: $e2");
      }
    }
  }

  Future<void> _discoverServices() async {
    try {
      final services = await _device!.discoverServices();
      print("Discovered ${services.length} services");

      final skipUuids = ['005e', '2a4d', '2a05'];

      final notifyCharacteristics = <BluetoothCharacteristic>[];
      for (final service in services) {
        for (final c in service.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          final skip = skipUuids.any((s) => uuid.contains(s));
          if (!skip && (c.properties.notify || c.properties.indicate)) {
            notifyCharacteristics.add(c);
          }
        }
      }

      print("Subscribing to ${notifyCharacteristics.length} characteristics");

      for (final c in notifyCharacteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        await _subscribeCharacteristic(c, uuid);
      }
    } catch (e) {
      print("Service discovery error: $e");
      _servicesDiscovered = false;
    }
  }

  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _servicesDiscovered = false;
    _hrFound = false;
    _isConnecting = false;
    _device?.disconnect();
  }
}