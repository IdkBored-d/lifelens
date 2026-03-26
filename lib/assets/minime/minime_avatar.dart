import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:lifelens/utils/minime_face_mapper.dart';

class MiniMeAvatar extends StatefulWidget {
  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String? moodLabel;
  final String? moodEmoji;
  final Color glow;
  final double size;
  final VoidCallback? onAvatarTap;
  final ValueChanged<double>? onRotate;
  final bool enableAutoRotate;

  const MiniMeAvatar({
    super.key,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    this.bodyWidthScale = 1.0,
    this.moodLabel,
    this.moodEmoji,
    required this.glow,
    this.size = 220,
    this.onAvatarTap,
    this.onRotate,
    this.enableAutoRotate = false,
  });

  @override
  State<MiniMeAvatar> createState() => _MiniMeAvatarState();
}

class _MiniMeAvatarState extends State<MiniMeAvatar> {
  @override
  Widget build(BuildContext context) {
    final expression = widget.moodEmoji ?? miniMeFaceForMood(widget.moodLabel);
    final bodyScale = widget.bodyWidthScale.clamp(0.75, 1.35).toDouble();
    // Fit emoji within a fixed virtual head circle for consistent placement.
    final headDiameter = (widget.size * 0.315).clamp(56.0, 180.0);
    final headTop = (widget.size * 0.06).clamp(8.0, 104.0);

    return RepaintBoundary(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: widget.glow, blurRadius: 24, spreadRadius: 2),
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
                        autoRotate: widget.enableAutoRotate,
                        autoRotateDelay: 0,
                        rotationPerSecond: '12deg',
                        cameraControls: false,
                        disableZoom: true,
                        disablePan: true,
                      ),
                      if (widget.hairModel.isNotEmpty)
                        ModelViewer(
                          src: widget.hairModel,
                          alt: "Avatar Hair",
                          ar: false,
                          autoRotate: widget.enableAutoRotate,
                          autoRotateDelay: 0,
                          rotationPerSecond: '12deg',
                          cameraControls: false,
                          disableZoom: true,
                          disablePan: true,
                        ),
                      if (widget.shirtModel.isNotEmpty)
                        ModelViewer(
                          src: widget.shirtModel,
                          alt: "Avatar Shirt",
                          ar: false,
                          autoRotate: widget.enableAutoRotate,
                          autoRotateDelay: 0,
                          rotationPerSecond: '12deg',
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
              top: headTop,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: SizedBox(
                    key: ValueKey(expression),
                    width: headDiameter,
                    height: headDiameter,
                    child: ClipOval(
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.84,
                          heightFactor: 0.84,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(
                              expression,
                              strutStyle: const StrutStyle(
                                height: 1,
                                forceStrutHeight: true,
                              ),
                              style: TextStyle(
                                fontSize: headDiameter,
                                height: 1,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
