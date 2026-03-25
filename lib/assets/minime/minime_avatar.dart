import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:lifelens/utils/minime_face_mapper.dart';

class MiniMeAvatar extends StatefulWidget {
  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String? moodLabel;
  final Color glow;
  final double size;
  final VoidCallback? onAvatarTap;
  final ValueChanged<double>? onRotate;

  const MiniMeAvatar({
    super.key,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    this.bodyWidthScale = 1.0,
    this.moodLabel,
    required this.glow,
    this.size = 220,
    this.onAvatarTap,
    this.onRotate,
  });

  @override
  State<MiniMeAvatar> createState() => _MiniMeAvatarState();
}

class _MiniMeAvatarState extends State<MiniMeAvatar>
    {

  @override
  Widget build(BuildContext context) {
    final expression = miniMeFaceForMood(widget.moodLabel);
    final bodyScale = widget.bodyWidthScale.clamp(0.75, 1.35).toDouble();

    return RepaintBoundary(
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(bodyScale, 1.0, 1.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ModelViewer(
                        src: widget.bodyModel,
                        alt: "Avatar Body",
                        ar: false,
                        autoRotate: true,
                        autoRotateDelay: 0,
                        rotationPerSecond: '25deg',
                        cameraControls: false,
                        disableZoom: true,
                        disablePan: true,
                      ),
                      if (widget.hairModel.isNotEmpty)
                        ModelViewer(
                          src: widget.hairModel,
                          alt: "Avatar Hair",
                          ar: false,
                          autoRotate: true,
                          autoRotateDelay: 0,
                          rotationPerSecond: '25deg',
                          cameraControls: false,
                          disableZoom: true,
                          disablePan: true,
                        ),
                      if (widget.shirtModel.isNotEmpty)
                        ModelViewer(
                          src: widget.shirtModel,
                          alt: "Avatar Shirt",
                          ar: false,
                          autoRotate: true,
                          autoRotateDelay: 0,
                          rotationPerSecond: '25deg',
                          cameraControls: false,
                          disableZoom: true,
                          disablePan: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onAvatarTap,
              ),
            ),
            Positioned(
              top: widget.size * 0.34,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Container(
                    key: ValueKey(expression),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      expression,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
