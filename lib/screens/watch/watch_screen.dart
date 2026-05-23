import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../providers/band_status_provider.dart';
import '../../providers/stress_provider.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({super.key});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bandAsync = ref.watch(bandStatusProvider);
    final stress = ref.watch(stressProvider);
    final notifier = ref.watch(stressProvider.notifier);

    final band = bandAsync.valueOrNull ?? BandStatus.disconnected;
    final connected = band.connected;

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _StatusHeader(connected: connected),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: _WatchFace(
                    hr: stress.hr.round(),
                    connected: connected,
                    ringController: _ringController,
                  ),
                ),
              ),
              _StatsGrid(
                batteryPercent: 85,
                rssi: band.rssi,
                lastSync: notifier.lastSyncTime ?? band.lastSync,
                dataPointsToday: stress.dataPointsToday,
              ),
              if (!connected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        ref.read(stressProvider.notifier).reconnectBand(),
                    child: const Text('RECONNECT'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final bool connected;

  const _StatusHeader({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? AppColors.success : AppColors.critical,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          connected
              ? 'Xiaomi Band 9 Connected'
              : 'Searching for device...',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

class _WatchFace extends StatelessWidget {
  final int hr;
  final bool connected;
  final AnimationController ringController;

  const _WatchFace({
    required this.hr,
    required this.connected,
    required this.ringController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ringController,
      builder: (context, child) {
        final t = ringController.value;
        final pulse = connected ? 1.0 : 0.85 + 0.15 * math.sin(t * math.pi * 2);
        final rotation = connected ? t * 2 * math.pi : 0.0;

        return Transform.scale(
          scale: pulse,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: connected
                      ? AppColors.success
                      : AppColors.textSecondary.withValues(alpha: 0.4),
                  width: 4,
                ),
              ),
              child: Center(child: child),
            ),
          ),
        );
      },
      child: Container(
        width: 180,
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryAccent.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hr > 0 ? '$hr' : '--',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            Text(
              'bpm',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int batteryPercent;
  final int? rssi;
  final DateTime? lastSync;
  final int dataPointsToday;

  const _StatsGrid({
    required this.batteryPercent,
    required this.rssi,
    required this.lastSync,
    required this.dataPointsToday,
  });

  String _formatSync(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatTile(label: 'Battery', value: '$batteryPercent%'),
        _StatTile(
          label: 'Signal',
          value: rssi != null ? '$rssi dBm' : '—',
        ),
        _StatTile(label: 'Last sync', value: _formatSync(lastSync)),
        _StatTile(
          label: 'Data today',
          value: '$dataPointsToday readings today',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
