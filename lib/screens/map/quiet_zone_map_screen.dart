import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../providers/firebase_providers.dart';
import '../../services/overpass_service.dart';

class QuietZoneMapScreen extends ConsumerStatefulWidget {
  const QuietZoneMapScreen({super.key});

  @override
  ConsumerState<QuietZoneMapScreen> createState() => _QuietZoneMapScreenState();
}

class _QuietZoneMapScreenState extends ConsumerState<QuietZoneMapScreen> {
  final _mapController = MapController();
  final _overpass = OverpassService();
  LatLng? _userPosition;
  List<QuietPoi> _pois = [];
  QuietPoi? _nearest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await _currentPosition();
      _userPosition = LatLng(pos.latitude, pos.longitude);
      _pois = await _overpass.fetchQuietPlaces(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _nearest = _findNearest(_userPosition!, _pois);
      if (mounted) {
        _mapController.move(_userPosition!, 15);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location services disabled');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  QuietPoi? _findNearest(LatLng from, List<QuietPoi> pois) {
    if (pois.isEmpty) return null;
    QuietPoi? best;
    double bestDist = double.infinity;
    for (final p in pois) {
      final d = OverpassService.walkingDistanceMeters(from, p.position);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }

  Color _markerColor(PoiType type) {
    switch (type) {
      case PoiType.library:
        return Colors.blue;
      case PoiType.park:
        return AppColors.success;
      case PoiType.cafe:
        return AppColors.alert;
      case PoiType.pharmacy:
        return AppColors.critical;
    }
  }

  Future<void> _openDirections(LatLng dest) async {
    if (_userPosition == null) return;
    final from = '${_userPosition!.latitude},${_userPosition!.longitude}';
    final to = '${dest.latitude},${dest.longitude}';
    final uri = Uri.parse(
      'https://www.openstreetmap.org/directions?from=$from&to=$to',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customZones = ref.watch(customQuietZonesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Quiet places nearby'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userPosition ?? const LatLng(0, 0),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.presense.presense',
                        ),
                        if (_userPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _userPosition!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.person_pin_circle,
                                  color: AppColors.primaryAccent,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            for (final p in _pois)
                              Marker(
                                point: p.position,
                                width: 36,
                                height: 36,
                                child: Text(
                                  p.emoji,
                                  style: TextStyle(
                                    fontSize: 24,
                                    shadows: [
                                      Shadow(
                                        color: _markerColor(p.type),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            for (final z in customZones)
                              Marker(
                                point: LatLng(z.lat, z.lng),
                                width: 36,
                                height: 36,
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.primaryAccent,
                                  size: 32,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (_nearest != null && _userPosition != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _NearestCard(
                          poi: _nearest!,
                          distanceMeters: OverpassService.walkingDistanceMeters(
                            _userPosition!,
                            _nearest!.position,
                          ),
                          onGo: () => _openDirections(_nearest!.position),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _NearestCard extends StatelessWidget {
  final QuietPoi poi;
  final double distanceMeters;
  final VoidCallback onGo;

  const _NearestCard({
    required this.poi,
    required this.distanceMeters,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    final walkMin = (distanceMeters / 80).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nearest quiet zone',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${poi.emoji} ${poi.name}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            '${poi.typeLabel} · ~$walkMin min walk (${distanceMeters.round()} m)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onGo,
              child: const Text('Go here'),
            ),
          ),
        ],
      ),
    );
  }
}
