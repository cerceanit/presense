import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../providers/chart_history_provider.dart';
import '../../providers/live_session_provider.dart';
import '../../providers/navigation_provider.dart';
import '../breathing/breathing_exercise_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../main/main_screen.dart';
import '../map/quiet_zone_map_screen.dart';
import '../watch/watch_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveSessionProvider).start();
      ref.read(chartHistoryProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PendingScreen>(pendingScreenProvider, (prev, next) {
      if (next == PendingScreen.none || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pendingScreenProvider.notifier).state = PendingScreen.none;
        if (next == PendingScreen.breathing) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BreathingExerciseScreen(),
            ),
          );
        } else if (next == PendingScreen.map) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const QuietZoneMapScreen(),
            ),
          );
        }
      });
    });

    final pages = const [
      MainScreen(),
      DashboardScreen(),
      WatchScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: pages[_tabIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Main',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.watch_rounded),
              label: 'Watch',
            ),
          ],
        ),
      ),
    );
  }
}