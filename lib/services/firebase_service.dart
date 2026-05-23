import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  DatabaseReference? _root;

  bool get isReady => _initialized && _root != null;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (Firebase.apps.isEmpty) return;
      _root = FirebaseDatabase.instance.ref();
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      _initialized = false;
    }
  }

  Future<String> childId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('child_id') ?? 'demo_child';
  }

  Stream<String?> breathingMediaUrlStream() async* {
    if (!isReady) {
      yield null;
      return;
    }
    final id = await childId();
    final ref = _root!.child('breathing').child(id).child('mediaUrl');
    yield* ref.onValue.map((event) {
      final v = event.snapshot.value;
      if (v is String && v.isNotEmpty) return v;
      return null;
    });
  }

  Stream<List<CustomQuietZone>> quietZonesStream() async* {
    if (!isReady) {
      yield [];
      return;
    }
    final id = await childId();
    final ref = _root!.child('quietZones').child(id);
    yield* ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return <CustomQuietZone>[];
      return data.entries.map((e) {
        final m = e.value;
        if (m is! Map) return null;
        return CustomQuietZone(
          id: e.key.toString(),
          name: m['name']?.toString() ?? 'Quiet zone',
          lat: (m['latitude'] as num?)?.toDouble() ?? 0,
          lng: (m['longitude'] as num?)?.toDouble() ?? 0,
        );
      }).whereType<CustomQuietZone>().toList();
    });
  }

  Future<void> writeLiveSession(Map<String, dynamic> payload) async {
    if (!isReady) return;
    try {
      final id = await childId();
      await _root!.child('sessions').child(id).child('live').set(payload);
    } catch (e) {
      debugPrint('Live session write failed: $e');
    }
  }

  Future<void> notifyParentCritical({
    required int riskScore,
    required String alertStage,
  }) async {
    if (!isReady) return;
    try {
      final id = await childId();
      await _root!.child('sessions').child(id).child('alerts').push().set({
        'riskScore': riskScore,
        'alertStage': alertStage,
        'message': 'Child needs support — critical stress level',
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Parent alert write failed: $e');
    }
  }
}

class CustomQuietZone {
  final String id;
  final String name;
  final double lat;
  final double lng;

  const CustomQuietZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });
}
