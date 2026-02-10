import 'package:flutter/material.dart';
import 'dart:async';

class WalkCompleteScreen extends StatefulWidget {
  final List<bool> completedNodes;

  const WalkCompleteScreen({
    super.key,
    required this.completedNodes,
  });

  @override
  State<WalkCompleteScreen> createState() => _WalkCompleteScreenState();
}

class _WalkCompleteScreenState extends State<WalkCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<bool> _visibleNodes;

  // A soft, leaf-like pattern (8 nodes)
  // Indexes map to completedNodes
  final List<Offset> _patternOffsets = const [
    Offset(0, -1.5),
    Offset(-1, -0.5),
    Offset(1, -0.5),
    Offset(-1.5, 0.5),
    Offset(0, 0.5),
    Offset(1.5, 0.5),
    Offset(-0.5, 1.5),
    Offset(0.5, 1.5),
  ];

  @override
  void initState() {
    super.initState();

    _visibleNodes = List.filled(widget.completedNodes.length, false);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _revealNodes();
  }

  void _revealNodes() async {
    for (int i = 0; i < widget.completedNodes.length; i++) {
      if (widget.completedNodes[i]) {
        await Future.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        setState(() => _visibleNodes[i] = true);
      }
    }

    _controller.forward();
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
      backgroundColor: cs.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.secondaryContainer.withOpacity(0.45),
              cs.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
          child: Column(
            children: [
              const Spacer(),

              // 🌸 Pattern Reveal
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(widget.completedNodes.length, (i) {
                    final offset = _patternOffsets[i] * 60;

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      left: 110 + offset.dx - 12,
                      top: 110 + offset.dy - 12,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 400),
                        scale: _visibleNodes[i] ? 1 : 0,
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 48),

              // ✨ Completion Title
              Text(
                'Walk complete',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),

              const SizedBox(height: 16),

              // 🧠 Artifact framing (not a question)
              Text(
                'You formed a calm pattern\nby staying present.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
              ),

              const Spacer(),

              // 🌙 Soft exit
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Return when ready'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
