import 'dart:math' as math;
import 'package:flutter/material.dart';

class MiniMeAvatar extends StatefulWidget {
  final String imageAsset;
  final Color glow;
  final double size;

  const MiniMeAvatar({
    super.key,
    required this.imageAsset,
    required this.glow,
    this.size = 220,
  });

  @override
  State<MiniMeAvatar> createState() => _MiniMeAvatarState();
}

class _MiniMeAvatarState extends State<MiniMeAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, __) {
        final t = _breath.value;
        final scale = 1 + 0.03 * math.sin(t * math.pi * 2);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.glow,
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Image.asset(
              widget.imageAsset,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}
