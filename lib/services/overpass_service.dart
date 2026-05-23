import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum PoiType { library, park, cafe, pharmacy }

class QuietPoi {
  final String id;
  final String name;
  final PoiType type;
  final LatLng position;

  const QuietPoi({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
  });

  String get emoji {
    switch (type) {
      case PoiType.library:
        return '📚';
      case PoiType.park:
        return '🌳';
      case PoiType.cafe:
        return '☕';
      case PoiType.pharmacy:
        return '💊';
    }
  }

  String get typeLabel {
    switch (type) {
      case PoiType.library:
        return 'Library';
      case PoiType.park:
        return 'Park';
      case PoiType.cafe:
        return 'Cafe';
      case PoiType.pharmacy:
        return 'Pharmacy';
    }
  }
}

class OverpassService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  Future<List<QuietPoi>> fetchQuietPlaces({
    required double lat,
    required double lng,
    int radiusMeters = 1000,
  }) async {
    final query = '''
[out:json];
(
  node["amenity"="library"](around:$radiusMeters,$lat,$lng);
  node["leisure"="park"](around:$radiusMeters,$lat,$lng);
  node["amenity"="cafe"](around:$radiusMeters,$lat,$lng);
  node["amenity"="pharmacy"](around:$radiusMeters,$lat,$lng);
);
out body;
''';

    final response = await http.get(
      Uri.parse('$_endpoint?data=${Uri.encodeComponent(query)}'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Overpass API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = json['elements'] as List<dynamic>? ?? [];

    final pois = <QuietPoi>[];
    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;
      final elLat = (el['lat'] as num?)?.toDouble();
      final elLng = (el['lon'] as num?)?.toDouble();
      if (elLat == null || elLng == null) continue;

      final tags = el['tags'] as Map<String, dynamic>? ?? {};
      final type = _typeFromTags(tags);
      if (type == null) continue;

      final name = tags['name']?.toString() ??
          tags['amenity']?.toString() ??
          _typeLabel(type);

      pois.add(QuietPoi(
        id: '${el['type']}_${el['id']}',
        name: name,
        type: type,
        position: LatLng(elLat, elLng),
      ));
    }
    return pois;
  }

  static String _typeLabel(PoiType type) {
    switch (type) {
      case PoiType.library:
        return 'Library';
      case PoiType.park:
        return 'Park';
      case PoiType.cafe:
        return 'Cafe';
      case PoiType.pharmacy:
        return 'Pharmacy';
    }
  }

  PoiType? _typeFromTags(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'library') return PoiType.library;
    if (tags['leisure'] == 'park') return PoiType.park;
    if (tags['amenity'] == 'cafe') return PoiType.cafe;
    if (tags['amenity'] == 'pharmacy') return PoiType.pharmacy;
    return null;
  }

  static double walkingDistanceMeters(LatLng from, LatLng to) {
    const distance = Distance();
    return distance(from, to);
  }
}
