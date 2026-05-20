import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../providers/stress_provider.dart';
import '../home/home_screen.dart';
import 'dart:async';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late StreamSubscription _timerSub;
  final TextEditingController _phoneController = TextEditingController();
  int _secondsLeft = 180;
  bool _done = false;
  bool _numberSaved = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 3),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(stressProvider.notifier).startCalibration();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('caregiver_number') ?? '';
      if (saved.isNotEmpty) {
        _phoneController.text = saved.replaceFirst('+', '');
        setState(() => _numberSaved = true);
      }
    });

    _timerSub = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _done = true;
        }
      });

      if (_secondsLeft == 0) {
        ref.read(stressProvider.notifier).finishCalibration();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timerSub.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  String get _timeLabel {
    int min = _secondsLeft ~/ 60;
    int sec = _secondsLeft % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _saveNumber() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caregiver_number', '+$number');
    setState(() => _numberSaved = true);
    FocusScope.of(context).unfocus();
  }

  void _skip() {
    ref.read(stressProvider.notifier).finishCalibration();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stress = ref.watch(stressProvider);
    final notifier = ref.read(stressProvider.notifier);
    double progress = 1 - (_secondsLeft / 180);
    int samplesCollected = notifier.calibrationProgress;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              const Text(
                'PRESENSE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Baseline Calibration',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                _done ? 'Calibration Complete' : 'Learning Your Baseline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _done
                    ? 'Your personal baseline is ready.'
                    : 'Sit quietly while we learn your resting state.\nDo not move too much.',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) => CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFF1A1A1A),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _done
                                ? const Color(0xFF2D6A4F)
                                : const Color(0xFFB5B5B5),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _done ? 'OK' : _timeLabel,
                            style: TextStyle(
                              color: _done
                                  ? const Color(0xFF2D6A4F)
                                  : Colors.white,
                              fontSize: _done ? 32 : 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          if (!_done)
                            Text(
                              '$samplesCollected samples',
                              style: const TextStyle(
                                color: Color(0xFF2D6A4F),
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              _readingTile('HR', '${stress.hr.toInt()} bpm', 'Heart Rate'),
              const SizedBox(height: 12),
              _readingTile('MOV', stress.movement.toStringAsFixed(2), 'Movement'),
              const SizedBox(height: 12),
              _readingTile('HRV', '${stress.hrv.toInt()} ms', 'HRV'),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _numberSaved
                        ? const Color(0xFF2D6A4F)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CAREGIVER',
                          style: TextStyle(
                            color: Color(0xFF2D6A4F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              '+',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '7 XXX XXX XXXX',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF444444),
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) {
                                  if (_numberSaved) {
                                    setState(() => _numberSaved = false);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _saveNumber,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _numberSaved
                              ? const Color(0xFF2D6A4F).withOpacity(0.2)
                              : const Color(0xFF2D6A4F),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _numberSaved ? 'SAVED' : 'SAVE',
                          style: TextStyle(
                            color: _numberSaved
                                ? const Color(0xFF2D6A4F)
                                : Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _numberSaved
                    ? 'Caregiver will be called during emergencies'
                    : 'Enter a number to enable emergency calls',
                style: const TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 32),

              if (!_done)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'SKIP CALIBRATION',
                      style: TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readingTile(String code, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                code,
                style: const TextStyle(
                  color: Color(0xFF2D6A4F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}