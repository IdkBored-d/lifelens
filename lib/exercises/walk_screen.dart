import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'walk_completion_screen.dart';

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen>
    with SingleTickerProviderStateMixin {
  static const int totalMinutes = 8;

  Timer? _timer;
  int _elapsedSeconds = 0;
  int _currentMinute = 0;

  // GAME STATE
  List<bool> _completedNodes = List.filled(totalMinutes, false);
  bool _isHolding = false;
  double _holdProgress = 0.0;

  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _startWalk();
  }

  void _startWalk() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _elapsedSeconds++;
        _currentMinute = (_elapsedSeconds ~/ 60).clamp(0, totalMinutes - 1);

        if (_elapsedSeconds >= totalMinutes * 60) {
          _endWalk();
        }
      });
    });
  }

  void _startHold() {
    if (_completedNodes[_currentMinute]) return;

    _isHolding = true;
    _holdProgress = 0;

    Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!_isHolding) {
        t.cancel();
        return;
      }

      setState(() {
        _holdProgress += 0.1;

        if (_holdProgress >= 1.0) {
          _completeNode();
          t.cancel();
        }
      });
    });
  }

  void _cancelHold() {
    _isHolding = false;
    setState(() => _holdProgress = 0);
  }

  void _completeNode() {
    HapticFeedback.mediumImpact();

    setState(() {
      _completedNodes[_currentMinute] = true;
      _holdProgress = 0;
      _isHolding = false;
    });
  }

  void _endWalk() {
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WalkCompleteScreen(
          completedNodes: _completedNodes,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slow Walk'),
        backgroundColor: cs.surface,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.secondaryContainer.withOpacity(0.35),
              cs.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              Text(
                '${totalMinutes - _currentMinute} min remaining',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
              ),

              const SizedBox(height: 20),

              // 🌟 NODE TRACK (Duolingo-style)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(totalMinutes, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _completedNodes[i]
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 48),

              // 🧘 HOLD-TO-COMPLETE ORB
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => _startHold(),
                  onTapUp: (_) => _cancelHold(),
                  onTapCancel: _cancelHold,
                  child: AnimatedBuilder(
                    animation: _floatController,
                    builder: (_, __) {
                      return Transform.translate(
                        offset: Offset(0, sin(_floatController.value * 2 * 3.14) * 8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Progress ring
                            SizedBox(
                              width: 160,
                              height: 160,
                              child: CircularProgressIndicator(
                                value: _holdProgress,
                                strokeWidth: 6,
                                color: cs.primary,
                                backgroundColor:
                                    cs.surfaceContainerHighest,
                              ),
                            ),

                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.surfaceContainerHighest,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.35),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _completedNodes[_currentMinute]
                                    ? Icons.check_rounded
                                    : Icons.spa_rounded,
                                size: 56,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                _prompts[_currentMinute],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
              ),

              const SizedBox(height: 16),

              Text(
                _completedNodes[_currentMinute]
                    ? 'Completed'
                    : 'Hold to complete',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _prompts = [
  'Begin gently • Find a pace that feels natural',
  'Grounding quest • Feel 5 steps fully',
  'Release quest • Soften shoulders and jaw',
  'Breath quest • Let breathing move on its own',
  'Awareness quest • Notice something green',
  'Listening quest • Find one quiet sound',
  'Body check-in • Scan from head to feet',
  'Almost there • Keep it slow and kind',
];
