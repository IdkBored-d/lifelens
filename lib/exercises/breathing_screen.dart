import 'package:flutter/material.dart';
import 'dart:async';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  String _phase = 'Inhale';
  int _seconds = 4;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startBreathingLoop();
  }

  void _startBreathingLoop() {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;

      setState(() {
        if (_phase == 'Inhale') {
          _phase = 'Hold';
        }
        else if (_phase == 'Hold') {
          _phase = 'Exhale';
        }
        else {
          _phase = 'Inhale';
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breathing'),
        backgroundColor: cs.surface,
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withOpacity(0.35),
              cs.surface,
            ],
          ),
        ),

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BreathingOrb(
                animation: _animation,
                phase: _phase,
              ),

              const SizedBox(height: 40),
              _BreathingText(phase: _phase),
              const SizedBox(height: 48),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('End breathing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathingOrb extends StatelessWidget {
  const _BreathingOrb({
    required this.animation,
    required this.phase,
  });

  final Animation<double> animation;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color baseColor;
    switch (phase) {
      case 'Inhale':
        baseColor = cs.primary;
        break;
      case 'Hold':
        baseColor = cs.secondary;
        break;
      case 'Ehale':
        baseColor = cs.tertiary;
        break;
      default:
        baseColor = cs.primary;
    }

    return ScaleTransition(
      scale: animation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  baseColor.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withOpacity(0.9),
                  baseColor.withOpacity(0.6),
                ],
              ),

              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.45),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathingText extends StatelessWidget {
  const _BreathingText({required this.phase});

  final String phase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          phase,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.onSurface,
          ),
        ),

        const SizedBox(height: 8),
        Text(
          _phaseHint(phase),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _phaseHint(String phase) {
    switch (phase) {
      case 'Inhale':
        return 'Breathe in slowly';
      case 'Hold':
        return 'Pause gently';
      case 'Exhale':
        return 'Release the breath';
      default:
        return '';
    }
  }
}