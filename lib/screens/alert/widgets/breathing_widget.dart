import 'dart:async';

import 'package:flutter/material.dart';

class BreathingWidget extends StatefulWidget {
  const BreathingWidget({super.key});

  @override
  State<BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<BreathingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _phase = 'BREATHE IN';
  int _countdown = 4;
  int _phaseIndex = 0;
  Timer? _phaseTimer;

  final List<Map<String, dynamic>> _phases = [
    {'label': 'BREATHE IN', 'duration': 4, 'expand': true},
    {'label': 'HOLD', 'duration': 4, 'expand': null},
    {'label': 'BREATHE OUT', 'duration': 6, 'expand': false},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _startPhase(0);
  }

  void _startPhase(int index) {
    _phaseIndex = index % _phases.length;
    final phase = _phases[_phaseIndex];
    final duration = phase['duration'] as int;

    setState(() {
      _phase = phase['label'] as String;
      _countdown = duration;
    });

    _controller.duration = Duration(seconds: duration);

    final expand = phase['expand'];
    if (expand == true) {
      _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.forward(from: 0);
    } else if (expand == false) {
      _animation = Tween<double>(begin: 1.0, end: 0.3).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.forward(from: 0);
    } else {
      _controller.stop();
    }

    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _startPhase(_phaseIndex + 1);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _BreathingPainter(progress: _animation.value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _phase,
                    style: const TextStyle(
                      color: Color(0xFF2D6A4F),
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BreathingPainter extends CustomPainter {
  final double progress;

  const _BreathingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final r = maxRadius * (0.3 + 0.7 * progress);

    canvas.drawCircle(
      center,
      r * 1.3,
      Paint()..color = const Color(0xFF2D6A4F).withOpacity(0.12 * progress),
    );
    canvas.drawCircle(
      center,
      r * 1.1,
      Paint()..color = const Color(0xFF2D6A4F).withOpacity(0.2 * progress),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()..color = const Color(0xFF2D6A4F).withOpacity(0.15 + 0.2 * progress),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFF2D6A4F).withOpacity(0.6 + 0.4 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BreathingPainter old) => old.progress != progress;
}
