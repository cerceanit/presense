import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BandService {
  BluetoothDevice? _device;
  Function(int hr)? onHRUpdate;
  bool _hrFound            = false;
  bool _servicesDiscovered = false;
  bool _isConnecting       = false;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  Timer? _continuousHRTimer;
  List<BluetoothService> _cachedServices = [];

  // Public getters for connection state monitoring
  BluetoothDevice? get device => _device;
  Stream<BluetoothConnectionState>? get deviceConnectionState => _device?.connectionState;

  static const String   bandMac    = 'D8:80:3C:D3:A8:75';
  static const Duration _gattDelay = Duration(milliseconds: 500);

  Future<void> scanAndConnect() async {
    if (_isConnecting) {
      debugPrint('Already connecting — skipping');
      return;
    }
    if (_device != null) {
      final currentState = await _device!.connectionState.first;
      if (currentState == BluetoothConnectionState.connected) {
        debugPrint('Already connected — skipping');
        return;
      }
    }
    _isConnecting = true;
    debugPrint('Connecting directly to Amazfit T-rex 3 by MAC...');
    _device = BluetoothDevice.fromId(bandMac);
    await _connectToDevice(_device!);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('Connecting to ${device.remoteId}...');
      await _connectionSub?.cancel();
      _connectionSub = null;

      _connectionSub = device.connectionState.listen((state) async {
        debugPrint('BLE state: $state');

        if (state == BluetoothConnectionState.connected &&
            !_servicesDiscovered) {
          _isConnecting       = true;
          _servicesDiscovered = true;
          debugPrint('Connected — discovering services');
          try {
            await device.requestConnectionPriority(
              connectionPriorityRequest: ConnectionPriority.balanced,
            );
          } catch (e) {
            debugPrint('Connection priority request failed: $e');
          }
          await _discoverServices();
          _isConnecting = false;
        }

        if (state == BluetoothConnectionState.disconnected) {
          _continuousHRTimer?.cancel();
          _continuousHRTimer  = null;
          _servicesDiscovered = false;
          _hrFound            = false;
          _isConnecting       = false;
          _cachedServices     = [];
          debugPrint('Disconnected — reconnecting in 5s...');
          Future.delayed(const Duration(seconds: 5), () {
            scanAndConnect();
          });
        }
      });

      await device.connect(autoConnect: false, mtu: null);
    } catch (e) {
      _isConnecting = false;
      debugPrint('Connection error: $e');
      Future.delayed(const Duration(seconds: 5), () {
        scanAndConnect();
      });
    }
  }

  // ── HR parsing — flags-aware UINT8/UINT16 ─────────────────────
  int _parseHrFromGatt(List<int> value) {
    if (value.isEmpty) return 0;
    final flags    = value[0];
    final isUint16 = (flags & 0x01) == 1;
    if (value.length < 2) return 0;
    if (isUint16) {
      if (value.length < 3) return 0;
      return value[1] | (value[2] << 8);
    }
    return value[1];
  }

  // ── Notification handler ──────────────────────────────────────
  void _handleNotification(String uuid, List<int> value) {
    final lower = uuid.toLowerCase();

    if (lower.contains('005e')) return;
    if (value.isEmpty)          return;
    if (value[0] == 0xA5)       return;

    debugPrint('  NOTIFY ${lower.substring(0, lower.length.clamp(0, 8))}: '
        'len=${value.length} data=$value');

    if (lower.contains('2a37')) {
      final hr = _parseHrFromGatt(value);
      if (hr >= 45 && hr <= 180) {
        _emitHeartRate(hr, source: '2a37', uuid: lower);
      }
      return;
    }

    if (lower.contains('aa03')) {
      _parseXiaomiAA03(value, lower);
      return;
    }

    if (lower.contains('c551')) {
      _parseXiaomiC551(value, lower);
      return;
    }

    if (lower.contains('e49a')) {
      _parseXiaomiE49A(value, lower);
      return;
    }

    if (_hrFound) return;
    for (var i = 0; i < value.length; i++) {
      if (value[i] >= 45 && value[i] <= 180) {
        _emitHeartRate(value[i],
            source: 'fallback', uuid: lower, byteIndex: i);
        return;
      }
    }
  }

  // ── Xiaomi aa03 parser ────────────────────────────────────────
  void _parseXiaomiAA03(List<int> value, String uuid) {
    debugPrint('aa03 raw: $value');
    if (value.length < 2) return;

    if (value[0] == 0x06) {
      final hr = value[1];
      if (hr >= 45 && hr <= 180) {
        _emitHeartRate(hr, source: 'aa03[0x06]', uuid: uuid, byteIndex: 1);
        return;
      }
    }

    if (value[0] == 0x00) {
      final hr = value[1];
      if (hr >= 45 && hr <= 180) {
        _emitHeartRate(hr, source: 'aa03[0x00]', uuid: uuid, byteIndex: 1);
        return;
      }
    }

    for (var i = 0; i < value.length; i++) {
      if (value[i] >= 45 && value[i] <= 180) {
        _emitHeartRate(value[i],
            source: 'aa03[scan]', uuid: uuid, byteIndex: i);
        return;
      }
    }
  }

  void _parseXiaomiC551(List<int> value, String uuid) {
    debugPrint('c551 raw: $value');
    if (value.length < 2) return;
    for (var i = 0; i < value.length; i++) {
      if (value[i] >= 45 && value[i] <= 180) {
        _emitHeartRate(value[i], source: 'c551', uuid: uuid, byteIndex: i);
        return;
      }
    }
  }

  void _parseXiaomiE49A(List<int> value, String uuid) {
    debugPrint('e49a raw: $value');
    if (value.length < 2) return;
    for (var i = 0; i < value.length; i++) {
      if (value[i] >= 45 && value[i] <= 180) {
        _emitHeartRate(value[i], source: 'e49a', uuid: uuid, byteIndex: i);
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
    debugPrint('>>> HR $source: $hr'
        '${byteIndex != null ? " byte[$byteIndex]" : ""}');
    onHRUpdate?.call(hr);
    _hrFound = true;
  }

  // ── Enable continuous HR ──────────────────────────────────────
  Future<void> _enableContinuousHR(BluetoothDevice device) async {
    if (!device.isConnected) {
      debugPrint('Skipping continuous HR — device not connected');
      return;
    }

    final services = _cachedServices.isNotEmpty
        ? _cachedServices
        : await device.discoverServices();

    // ── Step 1: aa01/aa02 — stop then start sequence ──────────
    BluetoothCharacteristic? aa02;
    for (final svc in services) {
      if (!svc.uuid.toString().toLowerCase().contains('aa01')) continue;
      for (final c in svc.characteristics) {
        if (c.uuid.toString().toLowerCase().contains('aa02') &&
            (c.properties.write || c.properties.writeWithoutResponse)) {
          aa02 = c;
          break;
        }
      }
      if (aa02 != null) break;
    }

    if (aa02 != null) {
      debugPrint('Found aa02 — sending stop/start sequence');
      // Stop any existing measurement
      try {
        await aa02.write([0x15, 0x02, 0x00], withoutResponse: true);
        debugPrint('aa02: stop sent');
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('aa02 stop failed: $e');
      }
      // Start continuous HR
      try {
        await aa02.write([0x15, 0x02, 0x01], withoutResponse: true);
        debugPrint('aa02: start continuous HR sent');
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('aa02 start failed: $e');
      }
      // Try alternate commands
      for (final cmd in [
        [0x15, 0x01, 0x01],
        [0x01, 0x03, 0x19],
        [0x02, 0x01, 0x00],
        [0x15, 0x02, 0x00, 0x01],
      ]) {
        try {
          await aa02.write(cmd, withoutResponse: true);
          debugPrint('aa02 alt cmd sent: $cmd');
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('aa02 alt cmd failed $cmd: $e');
        }
      }
    } else {
      debugPrint('aa02 not found');
    }

    // ── Step 2: e49a25e0 — also try extended service ──────────
    for (final svc in services) {
      if (!svc.uuid.toString().toLowerCase().contains('e49a25f8')) continue;
      for (final c in svc.characteristics) {
        if (c.uuid.toString().toLowerCase().contains('e49a25e0') &&
            c.properties.writeWithoutResponse) {
          try {
            await c.write([0x15, 0x02, 0x01], withoutResponse: true);
            debugPrint('e49a25e0: start HR cmd sent');
            await Future.delayed(const Duration(milliseconds: 300));
            await c.write([0x15, 0x01, 0x01], withoutResponse: true);
            debugPrint('e49a25e0: alt cmd sent');
          } catch (e) {
            debugPrint('e49a25e0 write failed: $e');
          }
        }
      }
    }

    // ── Step 3: fe95/005f fallback ────────────────────────────
    for (final svc in services) {
      if (!svc.uuid.toString().toLowerCase().contains('fe95')) continue;
      for (final c in svc.characteristics) {
        if (c.uuid.toString().toLowerCase().contains('005f') &&
            c.properties.writeWithoutResponse) {
          try {
            await c.write([0x15, 0x02, 0x01], withoutResponse: true);
            debugPrint('005f HR cmd sent');
          } catch (e) {
            debugPrint('005f write failed: $e');
          }
        }
      }
    }

    debugPrint('Continuous HR enable sequence complete');
  }

  Future<void> _enableContinuousHRAfterSubscribe() async {
    if (_device == null) return;
    await Future.delayed(const Duration(seconds: 2));
    await _enableContinuousHR(_device!);
    _startContinuousHRKeepAlive(_device!);
  }

  void _startContinuousHRKeepAlive(BluetoothDevice device) {
    _continuousHRTimer?.cancel();
    _continuousHRTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) async {
        if (device.isConnected) {
          await _enableContinuousHR(device);
        } else {
          debugPrint('Keep-alive skipped — device not connected');
        }
      },
    );
  }

  Future<void> _subscribeCharacteristic(
    BluetoothCharacteristic c,
    String uuid,
  ) async {
    await Future.delayed(_gattDelay);
    try {
      await c.setNotifyValue(true);
      debugPrint('Subscribed to $uuid');
      c.onValueReceived.listen((value) => _handleNotification(uuid, value));
    } catch (e) {
      debugPrint('Subscribe failed $uuid: $e — retrying in 1s');
      await Future.delayed(const Duration(seconds: 1));
      try {
        await c.setNotifyValue(true);
        debugPrint('Subscribed to $uuid (retry)');
        c.onValueReceived
            .listen((value) => _handleNotification(uuid, value));
      } catch (e2) {
        debugPrint('Subscribe retry failed $uuid: $e2');
      }
    }
  }

  Future<void> _discoverServices() async {
    try {
      final services = await _device!.discoverServices();
      _cachedServices = services;
      debugPrint('Discovered ${services.length} services');

      for (final svc in services) {
        debugPrint('Service: ${svc.uuid}');
        for (final c in svc.characteristics) {
          debugPrint('  Char: ${c.uuid} '
              'notify=${c.properties.notify} '
              'write=${c.properties.write} '
              'writeNoResp=${c.properties.writeWithoutResponse}');
        }
      }

      const skipUuids = ['005e', '2a4d', '2a05'];
      final notifyChars = <BluetoothCharacteristic>[];

      for (final svc in services) {
        for (final c in svc.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          final skip = skipUuids.any((s) => uuid.contains(s));
          if (!skip && (c.properties.notify || c.properties.indicate)) {
            notifyChars.add(c);
          }
        }
      }

      debugPrint('Subscribing to ${notifyChars.length} characteristics');
      for (final c in notifyChars) {
        await _subscribeCharacteristic(
            c, c.uuid.toString().toLowerCase());
      }

      await _enableContinuousHRAfterSubscribe();
    } catch (e) {
      debugPrint('Service discovery error: $e');
      _servicesDiscovered = false;
    }
  }

  void disconnect() {
    _continuousHRTimer?.cancel();
    _continuousHRTimer  = null;
    _connectionSub?.cancel();
    _connectionSub      = null;
    _servicesDiscovered = false;
    _hrFound            = false;
    _isConnecting       = false;
    _cachedServices     = [];
    _device?.disconnect();
  }
}