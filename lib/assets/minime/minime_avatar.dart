import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:model_viewer_plus/model_viewer_plus.dart';

class MiniMeAvatar extends StatefulWidget {
  /// Path to the 3‑D model asset (usually a `.glb` file).
  final String modelAsset;
  final Color glow;
  final double size;

  const MiniMeAvatar({
    super.key,
    required this.modelAsset,
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
            child: ClipOval(
              child: ModelViewer(
                // key at this level too; ensures the WebView is torn down
                // whenever the asset path changes.
                key: ValueKey(widget.modelAsset),
                src: widget.modelAsset,
                alt: 'Mini‑Me avatar',
                autoRotate: true,
                cameraControls: true,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        );
      },
    );
  }
}
