import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cartoon_face.dart';

enum MiniMeAmbientEffect { none, sparkles, haze, rainCloud, sweat }

enum MiniMeAccessoryMood { none, coffee, blanket, bandage, star }

enum MiniMeOutfitMode { standard, comfort, active, polished, worn }

class MiniMeVisualState {
  const MiniMeVisualState({
    this.wearLevel = 0,
    this.energyLevel = 0.6,
    this.recoveryLevel = 0,
    this.muscleToneLevel = 0,
    this.symptomLevel = 0,
    this.sleepDebtLevel = 0,
    this.distressLevel = 0,
    this.streakLevel = 0,
    this.messyHairLevel = 0,
    this.postureSlump = 0,
    this.wateryEyes = false,
    this.ambientEffect = MiniMeAmbientEffect.none,
    this.accessoryMood = MiniMeAccessoryMood.none,
    this.outfitMode = MiniMeOutfitMode.standard,
    this.statusText = '',
  });

  final double wearLevel;
  final double energyLevel;
  final double recoveryLevel;
  final double muscleToneLevel;
  final double symptomLevel;
  final double sleepDebtLevel;
  final double distressLevel;
  final double streakLevel;
  final double messyHairLevel;
  final double postureSlump;
  final bool wateryEyes;
  final MiniMeAmbientEffect ambientEffect;
  final MiniMeAccessoryMood accessoryMood;
  final MiniMeOutfitMode outfitMode;
  final String statusText;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MiniMeVisualState &&
            other.wearLevel == wearLevel &&
            other.energyLevel == energyLevel &&
            other.recoveryLevel == recoveryLevel &&
            other.muscleToneLevel == muscleToneLevel &&
            other.symptomLevel == symptomLevel &&
            other.sleepDebtLevel == sleepDebtLevel &&
            other.distressLevel == distressLevel &&
            other.streakLevel == streakLevel &&
            other.messyHairLevel == messyHairLevel &&
            other.postureSlump == postureSlump &&
            other.wateryEyes == wateryEyes &&
            other.ambientEffect == ambientEffect &&
            other.accessoryMood == accessoryMood &&
            other.outfitMode == outfitMode &&
            other.statusText == statusText;
  }

  @override
  int get hashCode => Object.hash(
    wearLevel,
    energyLevel,
    recoveryLevel,
    muscleToneLevel,
    symptomLevel,
    sleepDebtLevel,
    distressLevel,
    streakLevel,
    messyHairLevel,
    postureSlump,
    wateryEyes,
    ambientEffect,
    accessoryMood,
    outfitMode,
    statusText,
  );
}

class MiniMeAvatar extends StatefulWidget {
  const MiniMeAvatar({
    super.key,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    this.companionId,
    this.moodLabel,
    this.moodEmoji,
    this.glow,
    this.size = 320,
    this.onAvatarTap,
    this.onRotate,
    this.enableAutoRotate = true,
    this.enableInteractions = true,
    this.degradationLevel = 0,
    this.isHatched = true,
    this.visualState = const MiniMeVisualState(),
    this.onHatchComplete,
  });

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String? companionId;
  final String? moodLabel;
  final String? moodEmoji;
  final Color? glow;
  final double size;
  final VoidCallback? onAvatarTap;
  final ValueChanged<double>? onRotate;
  final bool enableAutoRotate;
  final bool enableInteractions;
  final double degradationLevel;
  final bool isHatched;
  final MiniMeVisualState visualState;
  final VoidCallback? onHatchComplete;

  @override
  State<MiniMeAvatar> createState() => _MiniMeAvatarState();
}

class MiniMePortraitAvatar extends StatelessWidget {
  const MiniMePortraitAvatar({
    super.key,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    this.companionId,
    this.moodLabel,
    this.size = 64,
    this.degradationLevel = 0,
    this.visualState = const MiniMeVisualState(),
  });

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String? companionId;
  final String? moodLabel;
  final double size;
  final double degradationLevel;
  final MiniMeVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(
      bodyModel,
      hairModel,
      shirtModel,
      companionId,
    );
    final expression = _resolveExpression(moodLabel);
    final headSize = size * 0.66;
    final shouldersWidth = size * 0.76 * bodyWidthScale.clamp(0.9, 1.12);
    final shouldersHeight = size * 0.34;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: size * 0.02,
            child: Container(
              width: shouldersWidth,
              height: shouldersHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.secondary, palette.primary],
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.04,
            child: SizedBox(
              width: headSize,
              height: headSize,
              child: CustomPaint(
                painter: _HeadShellPainter(
                  palette: palette,
                  degradationLevel: degradationLevel,
                  visualState: visualState,
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.18,
            child: CartoonFace(
              expression: expression,
              palette: palette,
              size: headSize * 0.5,
              blink: 0,
              degradationLevel: degradationLevel,
              headDip: 0,
              wateryEyes: visualState.wateryEyes,
              puffiness: visualState.sleepDebtLevel,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMeAvatarState extends State<MiniMeAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _idleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  late final AnimationController _reactionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _hatchController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  _MiniMeReaction _reaction = _MiniMeReaction.none;
  bool _didNotifyHatchComplete = false;

  @override
  void dispose() {
    _idleController.dispose();
    _reactionController.dispose();
    _hatchController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details, double size) {
    if (!widget.isHatched) {
      _startHatching();
      return;
    }

    if (!widget.enableInteractions) {
      widget.onAvatarTap?.call();
      return;
    }

    final dx = details.localPosition.dx / size;
    final dy = details.localPosition.dy / size;

    if (dy < 0.38) {
      _triggerReaction(_MiniMeReaction.flinch);
    } else if (dx < 0.34 && dy < 0.78) {
      _triggerReaction(_MiniMeReaction.doubleBicep);
    } else if (dx > 0.66 && dy < 0.78) {
      _triggerReaction(_MiniMeReaction.doubleBicep);
    } else {
      _triggerReaction(_MiniMeReaction.bounce);
    }

    widget.onAvatarTap?.call();
  }

  void _startHatching() {
    if (_hatchController.isAnimating || widget.isHatched) {
      return;
    }

    _didNotifyHatchComplete = false;
    _hatchController
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  void didUpdateWidget(covariant MiniMeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHatched && !oldWidget.isHatched) {
      _hatchController.value = 1;
      _didNotifyHatchComplete = true;
    } else if (!widget.isHatched && oldWidget.isHatched) {
      _hatchController.value = 0;
      _didNotifyHatchComplete = false;
    }
  }

  void _triggerReaction(_MiniMeReaction reaction) {
    final duration = switch (reaction) {
      _MiniMeReaction.doubleBicep => const Duration(milliseconds: 2000),
      _ => const Duration(milliseconds: 420),
    };
    setState(() => _reaction = reaction);
    _reactionController
      ..duration = duration
      ..stop()
      ..value = 0
      ..forward().whenComplete(() {
        if (mounted) {
          setState(() => _reaction = _MiniMeReaction.none);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(
      widget.bodyModel,
      widget.hairModel,
      widget.shirtModel,
      widget.companionId,
    );
    final expression = _resolveExpression(widget.moodLabel);
    final visualWearLevel = _resolveVisualWearLevel(
      widget.moodLabel,
      math.max(widget.degradationLevel, widget.visualState.wearLevel),
    );
    final accessory = _resolveAccessory(widget.shirtModel);
    final crest = _resolveCrest(widget.hairModel);
    final clampedSize = widget.size.clamp(140.0, 720.0);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (details) => _handleTapDown(details, clampedSize),
        child: SizedBox(
          width: clampedSize,
          height: clampedSize,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _idleController,
              _reactionController,
              _hatchController,
            ]),
            builder: (context, _) {
              final idleMotion = _motionForExpression(
                expression,
                widget.enableAutoRotate ? _idleController.value : 0,
              );
              final energyScale = 0.72 + widget.visualState.energyLevel * 0.48;
              final reactionMotion = _reactionMotion(
                _reaction,
                _reactionController.value,
              );
              final bob = idleMotion.bob * energyScale + reactionMotion.bob;
              final sway =
                  idleMotion.sway *
                      (0.76 + widget.visualState.energyLevel * 0.38) +
                  reactionMotion.sway;
              final headDip =
                  idleMotion.headDip +
                  widget.visualState.postureSlump * 4.5 -
                  widget.visualState.recoveryLevel * 1.2 +
                  reactionMotion.headDip;
              final shadowScale =
                  idleMotion.shadowScale +
                  widget.visualState.postureSlump * 0.04 -
                  widget.visualState.energyLevel * 0.02 +
                  reactionMotion.shadowDelta;
              final muscleTone = widget.visualState.muscleToneLevel.clamp(
                0.0,
                1.0,
              );
              final powerPulse =
                  math.sin(_idleController.value * math.pi * 2) *
                  muscleTone *
                  clampedSize *
                  0.012;
              final hatchProgress = widget.isHatched
                  ? 1.0
                  : Curves.easeInOutCubic.transform(_hatchController.value);
              final eggOpacity = (1 - (hatchProgress * 1.5)).clamp(0.0, 1.0);
              final mascotOpacity = ((hatchProgress - 0.28) / 0.72).clamp(
                0.0,
                1.0,
              );
              final eggScale = 1.0 - (hatchProgress * 0.08);
              final mascotScale = 0.82 + (mascotOpacity * 0.18);
              final hatchShake =
                  math.sin(hatchProgress * math.pi * 10) *
                  (1 - hatchProgress) *
                  clampedSize *
                  0.035;

              if (!widget.isHatched &&
                  hatchProgress >= 0.98 &&
                  !_didNotifyHatchComplete) {
                _didNotifyHatchComplete = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    widget.onHatchComplete?.call();
                  }
                });
              }

              if (widget.onRotate != null) {
                widget.onRotate!(sway);
              }

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  RepaintBoundary(
                    child: _AmbientHalo(
                      size: clampedSize,
                      color: widget.glow ?? palette.primary,
                      shimmer: idleMotion.shimmer,
                      visualState: widget.visualState,
                    ),
                  ),
                  Positioned(
                    bottom: clampedSize * 0.1,
                    child: Transform.scale(
                      scaleX: shadowScale,
                      child: Container(
                        width: clampedSize * 0.42,
                        height: clampedSize * 0.08,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(idleMotion.offsetX + hatchShake, bob),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateZ(sway)
                        ..rotateY(idleMotion.turn),
                      child: RepaintBoundary(
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (mascotOpacity > 0)
                              Opacity(
                                opacity: mascotOpacity,
                                child: Transform.scale(
                                  scale: mascotScale,
                                  child: _MascotBody(
                                    palette: palette,
                                    expression: expression,
                                    accessory: accessory,
                                    crest: crest,
                                    size: clampedSize,
                                    blink: _blinkValue(_idleController.value),
                                    bodyWidthScale: widget.bodyWidthScale,
                                    armLiftLeft: reactionMotion.leftArmLift,
                                    armLiftRight: reactionMotion.rightArmLift,
                                    flexPoseLevel: reactionMotion.flexPoseLevel,
                                    headDip:
                                        headDip -
                                        (1 - mascotOpacity) * 10 -
                                        muscleTone * 3.5,
                                    degradationLevel: visualWearLevel,
                                    visualState: widget.visualState,
                                    powerPulse: powerPulse,
                                  ),
                                ),
                              ),
                            if (!widget.isHatched || eggOpacity > 0)
                              Opacity(
                                opacity: eggOpacity,
                                child: Transform.scale(
                                  scale: eggScale,
                                  child: _MiniMeEgg(
                                    size: clampedSize * 0.7,
                                    accentColor:
                                        widget.glow ?? palette.accessory,
                                    bob: bob,
                                    crackProgress: hatchProgress,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _blinkValue(double t) {
    const windows = <double>[0.17, 0.51, 0.86];
    var best = 0.0;
    for (final center in windows) {
      final distance = (t - center).abs();
      if (distance < 0.045) {
        final normalized = 1 - (distance / 0.045);
        best = math.max(best, Curves.easeInOut.transform(normalized));
      }
    }
    return best;
  }
}

class _MascotBody extends StatelessWidget {
  const _MascotBody({
    required this.palette,
    required this.expression,
    required this.accessory,
    required this.crest,
    required this.size,
    required this.blink,
    required this.bodyWidthScale,
    required this.armLiftLeft,
    required this.armLiftRight,
    required this.flexPoseLevel,
    required this.headDip,
    required this.degradationLevel,
    required this.visualState,
    required this.powerPulse,
  });

  final MiniMeFacePalette palette;
  final String expression;
  final _MiniMeAccessory accessory;
  final _MiniMeCrest crest;
  final double size;
  final double blink;
  final double bodyWidthScale;
  final double armLiftLeft;
  final double armLiftRight;
  final double flexPoseLevel;
  final double headDip;
  final double degradationLevel;
  final MiniMeVisualState visualState;
  final double powerPulse;

  @override
  Widget build(BuildContext context) {
    final headSize = size * 0.39;
    final muscleTone = visualState.muscleToneLevel.clamp(0.0, 1.0);
    final flexPose = flexPoseLevel.clamp(0.0, 1.0);
    final flexMuscleBoost = flexPose * 0.42;
    final displayedMuscleTone = (muscleTone + flexMuscleBoost).clamp(0.0, 1.0);
    final bodyWidth =
        size *
        0.44 *
        (bodyWidthScale.clamp(0.86, 1.16) + displayedMuscleTone * 0.08);
    final bodyHeight = size * (0.46 + displayedMuscleTone * 0.03);
    final slumpOffset = visualState.postureSlump * size * 0.035;
    final confidenceLift = displayedMuscleTone * size * 0.022;
    final headTop = size * 0.13 + headDip * 0.2 + slumpOffset - confidenceLift;
    final bodyTop = size * 0.38 + slumpOffset * 0.5 - confidenceLift * 0.4;
    final torsoTilt =
        visualState.postureSlump * -0.06 +
        visualState.recoveryLevel * 0.02 +
        displayedMuscleTone * 0.018;
    final shoulderDrop =
        visualState.postureSlump * size * 0.02 -
        displayedMuscleTone * size * 0.01;
    final armWidth = size * (0.16 + displayedMuscleTone * 0.035);
    final armHeight = size * (0.25 + displayedMuscleTone * 0.015);
    final shoulderSpread =
        size * (displayedMuscleTone * 0.035 + flexPose * 0.012);
    final flexLift = displayedMuscleTone * 0.16 + flexPose * 0.14;
    final armTop =
        bodyTop +
        size * 0.04 +
        shoulderDrop -
        (armLiftLeft + flexPose * 0.04) * size * 0.11;
    final torsoTurn = 0.0;
    final leftArmAngle =
        -0.22 -
        (armLiftLeft + flexLift) * 0.58 -
        visualState.postureSlump * 0.04 -
        displayedMuscleTone * 0.05 -
        flexPose * 0.03;
    final rightArmAngle =
        0.22 +
        (armLiftRight + flexLift) * 0.58 +
        visualState.postureSlump * 0.04 +
        displayedMuscleTone * 0.05 +
        flexPose * 0.03;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: headTop - headSize * 0.08,
            child: _Crest(
              crest: crest,
              palette: palette,
              size: headSize * 0.34,
              messyHairLevel: visualState.messyHairLevel,
              recoveryLevel: visualState.recoveryLevel,
            ),
          ),
          Positioned(
            left: size / 2 - bodyWidth * 0.67 - shoulderSpread,
            top: armTop,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()..rotateZ(leftArmAngle),
              child: _Arm(
                width: armWidth,
                height: armHeight,
                color: palette.primary,
                shadowColor: palette.secondary,
                muscleToneLevel: displayedMuscleTone,
                flexPoseLevel: flexPose,
              ),
            ),
          ),
          Positioned(
            right: size / 2 - bodyWidth * 0.67 - shoulderSpread,
            top:
                bodyTop +
                size * 0.04 +
                shoulderDrop -
                (armLiftRight + flexPose * 0.04) * size * 0.11,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()..rotateZ(rightArmAngle),
              child: _Arm(
                width: armWidth,
                height: armHeight,
                color: palette.primary,
                shadowColor: palette.secondary,
                muscleToneLevel: displayedMuscleTone,
                flexPoseLevel: flexPose,
              ),
            ),
          ),
          Positioned(
            top: bodyTop,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(torsoTurn)
                ..rotateZ(torsoTilt),
              child: Transform.scale(
                scaleX: 1 + displayedMuscleTone * 0.05 + flexPose * 0.03,
                scaleY: 1 + (powerPulse / size) + flexPose * 0.02,
                child: SizedBox(
                  width: bodyWidth,
                  height: bodyHeight,
                  child: CustomPaint(
                    painter: _BodyPainter(
                      palette: palette,
                      degradationLevel: degradationLevel,
                      visualState: visualState,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: headTop,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(torsoTurn * 0.65)
                ..scaleByDouble(
                  1 - displayedMuscleTone * 0.02,
                  1 - displayedMuscleTone * 0.02,
                  1,
                  1,
                ),
              child: SizedBox(
                width: headSize,
                height: headSize,
                child: CustomPaint(
                  painter: _HeadShellPainter(
                    palette: palette,
                    degradationLevel: degradationLevel,
                    visualState: visualState,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: headTop + headSize * 0.16,
            child: CartoonFace(
              expression: expression,
              palette: palette,
              size: headSize * 0.72,
              blink: blink,
              degradationLevel: degradationLevel,
              headDip: headDip,
              wateryEyes: visualState.wateryEyes,
              puffiness: visualState.sleepDebtLevel,
            ),
          ),
          Positioned(
            top: bodyTop + bodyHeight * 0.24,
            child: _AccessoryBadge(
              accessory: accessory,
              palette: palette,
              size: size * 0.16,
              accessoryMood: visualState.accessoryMood,
              outfitMode: visualState.outfitMode,
            ),
          ),
          Positioned(
            left: size / 2 - bodyWidth * 0.24,
            bottom: size * 0.11,
            child: _Leg(
              width: size * 0.11,
              height: size * 0.17,
              color: palette.belly,
            ),
          ),
          Positioned(
            right: size / 2 - bodyWidth * 0.24,
            bottom: size * 0.11,
            child: _Leg(
              width: size * 0.11,
              height: size * 0.17,
              color: palette.belly,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMeEgg extends StatelessWidget {
  const _MiniMeEgg({
    required this.size,
    required this.accentColor,
    required this.bob,
    this.crackProgress = 0,
  });

  final double size;
  final Color accentColor;
  final double bob;
  final double crackProgress;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, bob * 0.35),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: size * 0.06,
              child: Container(
                width: size * 0.48,
                height: size * 0.1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
            ),
            Container(
              width: size * 0.56,
              height: size * 0.72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Color.alphaBlend(
                      accentColor.withValues(alpha: 0.22),
                      Colors.white,
                    ),
                  ],
                ),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.65),
                  width: 2,
                ),
              ),
            ),
            if (crackProgress > 0.12)
              Positioned(
                top: size * 0.16,
                child: SizedBox(
                  width: size * 0.44,
                  height: size * 0.44,
                  child: CustomPaint(
                    painter: _EggCrackPainter(
                      color: accentColor.withValues(alpha: 0.7),
                      progress: crackProgress,
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

class _EggCrackPainter extends CustomPainter {
  const _EggCrackPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.02)
      ..lineTo(size.width * 0.44, size.height * 0.18)
      ..lineTo(size.width * 0.54, size.height * 0.3)
      ..lineTo(size.width * 0.4, size.height * 0.48)
      ..lineTo(size.width * 0.56, size.height * 0.64)
      ..lineTo(size.width * 0.46, size.height * 0.88);

    final metric = path.computeMetrics().first;
    final visiblePath = metric.extractPath(0, metric.length * eased);
    canvas.drawPath(visiblePath, paint);
  }

  @override
  bool shouldRepaint(covariant _EggCrackPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

class _HeadShellPainter extends CustomPainter {
  const _HeadShellPainter({
    required this.palette,
    required this.degradationLevel,
    required this.visualState,
  });

  final MiniMeFacePalette palette;
  final double degradationLevel;
  final MiniMeVisualState visualState;

  @override
  void paint(Canvas canvas, Size size) {
    final headRect = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.1,
      size.width * 0.88,
      size.height * 0.82,
    );

    final earPaint = Paint()..color = palette.primary;
    canvas.drawCircle(
      Offset(size.width * 0.23, size.height * 0.18),
      size.width * 0.12,
      earPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.77, size.height * 0.18),
      size.width * 0.12,
      earPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.23, size.height * 0.2),
      size.width * 0.06,
      Paint()..color = palette.accessory.withValues(alpha: 0.24),
    );
    canvas.drawCircle(
      Offset(size.width * 0.77, size.height * 0.2),
      size.width * 0.06,
      Paint()..color = palette.accessory.withValues(alpha: 0.24),
    );

    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.16, -0.22),
        radius: 0.94,
        colors: [Colors.white, palette.primary],
      ).createShader(headRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(size.width * 0.34)),
      headPaint,
    );

    if (visualState.recoveryLevel > 0.45) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.44, size.height * 0.24),
          width: size.width * 0.38,
          height: size.height * 0.16,
        ),
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.08 + visualState.recoveryLevel * 0.1,
          ),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, Radius.circular(size.width * 0.34)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02,
    );

    if (degradationLevel > 0.2) {
      final sagPaint = Paint()
        ..color = const Color(
          0xFF7D8CA8,
        ).withValues(alpha: degradationLevel * 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.72),
          width: size.width * (0.42 + degradationLevel * 0.08),
          height: size.height * 0.18,
        ),
        sagPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeadShellPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.degradationLevel != degradationLevel ||
        oldDelegate.visualState != visualState;
  }
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({
    required this.palette,
    required this.degradationLevel,
    required this.visualState,
  });

  final MiniMeFacePalette palette;
  final double degradationLevel;
  final MiniMeVisualState visualState;

  @override
  void paint(Canvas canvas, Size size) {
    final muscleTone = visualState.muscleToneLevel.clamp(0.0, 1.0);
    final shellRect = Rect.fromLTWH(
      size.width * 0.06,
      0,
      size.width * 0.88,
      size.height,
    );
    final shirtRect = Rect.fromLTWH(
      shellRect.left,
      size.height * 0.16,
      shellRect.width,
      size.height * 0.6,
    );

    final bodyPath = Path()
      ..moveTo(shellRect.left + shellRect.width * 0.18, shellRect.top)
      ..quadraticBezierTo(
        shellRect.left + shellRect.width * (0.02 - muscleTone * 0.06),
        shellRect.top + shellRect.height * (0.22 - muscleTone * 0.06),
        shellRect.left + shellRect.width * 0.12,
        shellRect.bottom - shellRect.height * 0.2,
      )
      ..quadraticBezierTo(
        shellRect.left + shellRect.width * 0.18,
        shellRect.bottom,
        shellRect.center.dx,
        shellRect.bottom,
      )
      ..quadraticBezierTo(
        shellRect.right - shellRect.width * 0.18,
        shellRect.bottom,
        shellRect.right - shellRect.width * 0.12,
        shellRect.bottom - shellRect.height * 0.2,
      )
      ..quadraticBezierTo(
        shellRect.right - shellRect.width * (0.02 - muscleTone * 0.06),
        shellRect.top + shellRect.height * (0.22 - muscleTone * 0.06),
        shellRect.right - shellRect.width * 0.18,
        shellRect.top,
      )
      ..close();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = palette.primary
        ..style = PaintingStyle.fill,
    );

    final shirtPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(shirtRect, Radius.circular(size.width * 0.18)),
      );
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawPath(
      shirtPath,
      Paint()
        ..color = palette.secondary
        ..style = PaintingStyle.fill,
    );

    switch (visualState.outfitMode) {
      case MiniMeOutfitMode.comfort:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.5, size.height * 0.22),
            width: size.width * 0.52,
            height: size.height * 0.24,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * 0.04
            ..strokeCap = StrokeCap.round,
        );
        break;
      case MiniMeOutfitMode.active:
        final stripePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.018
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.35),
          Offset(size.width * 0.4, size.height * 0.64),
          stripePaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.75, size.height * 0.35),
          Offset(size.width * 0.6, size.height * 0.64),
          stripePaint,
        );
        break;
      case MiniMeOutfitMode.polished:
        canvas.drawCircle(
          Offset(size.width * 0.68, size.height * 0.34),
          size.width * 0.04,
          Paint()..color = Colors.white.withValues(alpha: 0.34),
        );
        break;
      case MiniMeOutfitMode.worn:
      case MiniMeOutfitMode.standard:
        break;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          size.width * 0.5,
          size.height * (0.78 - muscleTone * 0.02),
        ),
        width: size.width * (0.42 + muscleTone * 0.06),
        height: size.height * (0.18 + muscleTone * 0.02),
      ),
      Paint()..color = palette.belly,
    );

    if (muscleTone > 0.18) {
      final definitionPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08 + muscleTone * 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.33, size.height * 0.36),
        Offset(size.width * 0.42, size.height * 0.52),
        definitionPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.67, size.height * 0.36),
        Offset(size.width * 0.58, size.height * 0.52),
        definitionPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.46),
          width: size.width * (0.18 + muscleTone * 0.08),
          height: size.height * (0.16 + muscleTone * 0.06),
        ),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        definitionPaint,
      );
    }

    if (degradationLevel > 0.04) {
      final tiredPaint = Paint()
        ..color = const Color(
          0xFF52627F,
        ).withValues(alpha: degradationLevel * 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.74),
          width: size.width * (0.44 + degradationLevel * 0.1),
          height: size.height * 0.16,
        ),
        tiredPaint,
      );
    }

    if (degradationLevel > 0.22) {
      final wrinklePaint = Paint()
        ..color = Colors.black.withValues(alpha: degradationLevel * 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.34, size.height * 0.54),
        Offset(size.width * 0.66, size.height * 0.54),
        wrinklePaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.37, size.height * 0.6),
        Offset(size.width * 0.63, size.height * 0.6),
        wrinklePaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.28, size.height * 0.47),
        Offset(size.width * 0.44, size.height * 0.5),
        wrinklePaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.56, size.height * 0.5),
        Offset(size.width * 0.73, size.height * 0.46),
        wrinklePaint,
      );
    }

    if (degradationLevel > 0.38) {
      final scuffPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.3, size.height * 0.46),
          width: size.width * 0.12,
          height: size.height * 0.07,
        ),
        scuffPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.72, size.height * 0.66),
          width: size.width * 0.1,
          height: size.height * 0.06,
        ),
        scuffPaint,
      );
    }

    if (degradationLevel > 0.48) {
      final frayPaint = Paint()
        ..color = Colors.black.withValues(alpha: degradationLevel * 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.01
        ..strokeCap = StrokeCap.round;
      final leftTear = Path()
        ..moveTo(size.width * 0.26, size.height * 0.48)
        ..lineTo(size.width * 0.22, size.height * 0.56)
        ..lineTo(size.width * 0.28, size.height * 0.62)
        ..lineTo(size.width * 0.32, size.height * 0.54)
        ..close();
      final rightTear = Path()
        ..moveTo(size.width * 0.7, size.height * 0.58)
        ..lineTo(size.width * 0.66, size.height * 0.67)
        ..lineTo(size.width * 0.72, size.height * 0.72)
        ..lineTo(size.width * 0.77, size.height * 0.63)
        ..close();
      final tearInteriorPaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill;

      canvas.drawPath(leftTear, tearInteriorPaint);
      canvas.drawPath(rightTear, tearInteriorPaint);
      canvas.drawPath(leftTear, frayPaint);
      canvas.drawPath(rightTear, frayPaint);

      canvas.drawLine(
        Offset(size.width * 0.23, size.height * 0.59),
        Offset(size.width * 0.2, size.height * 0.62),
        frayPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.29, size.height * 0.6),
        Offset(size.width * 0.26, size.height * 0.64),
        frayPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.68, size.height * 0.7),
        Offset(size.width * 0.65, size.height * 0.74),
        frayPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.74, size.height * 0.69),
        Offset(size.width * 0.71, size.height * 0.75),
        frayPaint,
      );
    }

    if (degradationLevel > 0.68) {
      final seamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.008
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.24, size.height * 0.34),
        Offset(size.width * 0.32, size.height * 0.38),
        seamPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.24, size.height * 0.37),
        Offset(size.width * 0.32, size.height * 0.41),
        seamPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.65, size.height * 0.46),
        Offset(size.width * 0.78, size.height * 0.51),
        seamPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.65, size.height * 0.49),
        Offset(size.width * 0.77, size.height * 0.54),
        seamPaint,
      );
    }
    canvas.restore();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.016,
    );
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.degradationLevel != degradationLevel ||
        oldDelegate.visualState != visualState;
  }
}

class _AmbientHalo extends StatelessWidget {
  const _AmbientHalo({
    required this.size,
    required this.color,
    required this.shimmer,
    required this.visualState,
  });

  final double size;
  final Color color;
  final double shimmer;
  final MiniMeVisualState visualState;

  @override
  Widget build(BuildContext context) {
    Color auraColor;
    switch (visualState.ambientEffect) {
      case MiniMeAmbientEffect.sparkles:
        auraColor = const Color(0xFFD8C56A);
        break;
      case MiniMeAmbientEffect.haze:
        auraColor = const Color(0xFF8191AA);
        break;
      case MiniMeAmbientEffect.rainCloud:
        auraColor = const Color(0xFF7D92B7);
        break;
      case MiniMeAmbientEffect.sweat:
        auraColor = const Color(0xFF73B7DE);
        break;
      case MiniMeAmbientEffect.none:
        auraColor = color;
        break;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width:
              size * (0.6 + shimmer * 0.02 + visualState.recoveryLevel * 0.02),
          height:
              size * (0.6 + shimmer * 0.02 + visualState.recoveryLevel * 0.02),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.1 + shimmer * 0.08, -0.15),
              colors: [
                auraColor.withValues(
                  alpha: 0.16 + visualState.recoveryLevel * 0.04,
                ),
                auraColor.withValues(
                  alpha: 0.05 + visualState.distressLevel * 0.03,
                ),
                Colors.transparent,
              ],
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
        if (visualState.ambientEffect != MiniMeAmbientEffect.none)
          SizedBox(
            width: size * 0.72,
            height: size * 0.72,
            child: CustomPaint(
              painter: _AmbientEffectPainter(
                effect: visualState.ambientEffect,
                shimmer: shimmer,
                intensity: math.max(
                  visualState.recoveryLevel,
                  math.max(
                    visualState.sleepDebtLevel,
                    visualState.symptomLevel,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AmbientEffectPainter extends CustomPainter {
  const _AmbientEffectPainter({
    required this.effect,
    required this.shimmer,
    required this.intensity,
  });

  final MiniMeAmbientEffect effect;
  final double shimmer;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case MiniMeAmbientEffect.sparkles:
        final paint = Paint()
          ..color = const Color(0xFFE2C85B).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.01
          ..strokeCap = StrokeCap.round;
        for (final point in <Offset>[
          Offset(size.width * 0.2, size.height * 0.34),
          Offset(size.width * 0.75, size.height * 0.18),
          Offset(size.width * 0.84, size.height * 0.58),
        ]) {
          _drawSparkle(
            canvas,
            point.translate(0, shimmer * 3),
            paint,
            size.width * 0.035,
          );
        }
        break;
      case MiniMeAmbientEffect.haze:
        final hazePaint = Paint()
          ..color = const Color(
            0xFF7B8BA6,
          ).withValues(alpha: 0.12 + intensity * 0.12)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.34, size.height * 0.62),
            width: size.width * 0.28,
            height: size.height * 0.12,
          ),
          hazePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.7, size.height * 0.44),
            width: size.width * 0.24,
            height: size.height * 0.1,
          ),
          hazePaint,
        );
        break;
      case MiniMeAmbientEffect.rainCloud:
        final cloudPaint = Paint()
          ..color = const Color(0xFF879BC0).withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        final dropPaint = Paint()
          ..color = const Color(0xFF76B6E6).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.012
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(
          Offset(size.width * 0.28, size.height * 0.26),
          size.width * 0.05,
          cloudPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.36, size.height * 0.24),
          size.width * 0.06,
          cloudPaint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.44, size.height * 0.27),
          size.width * 0.05,
          cloudPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.25,
              size.height * 0.26,
              size.width * 0.22,
              size.height * 0.06,
            ),
            Radius.circular(size.width * 0.03),
          ),
          cloudPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.32, size.height * 0.36),
          Offset(size.width * 0.3, size.height * 0.44),
          dropPaint,
        );
        canvas.drawLine(
          Offset(size.width * 0.4, size.height * 0.36),
          Offset(size.width * 0.38, size.height * 0.46),
          dropPaint,
        );
        break;
      case MiniMeAmbientEffect.sweat:
        final paint = Paint()
          ..color = const Color(0xFF76B6E6).withValues(alpha: 0.52)
          ..style = PaintingStyle.fill;
        final tear = Path()
          ..moveTo(size.width * 0.74, size.height * 0.2)
          ..quadraticBezierTo(
            size.width * 0.79,
            size.height * 0.24,
            size.width * 0.75,
            size.height * 0.3,
          )
          ..quadraticBezierTo(
            size.width * 0.69,
            size.height * 0.26,
            size.width * 0.74,
            size.height * 0.2,
          )
          ..close();
        canvas.drawPath(tear.shift(Offset(0, shimmer * 4)), paint);
        break;
      case MiniMeAmbientEffect.none:
        break;
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, Paint paint, double radius) {
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientEffectPainter oldDelegate) {
    return oldDelegate.effect != effect ||
        oldDelegate.shimmer != shimmer ||
        oldDelegate.intensity != intensity;
  }
}

class _Arm extends StatelessWidget {
  const _Arm({
    required this.width,
    required this.height,
    required this.color,
    required this.shadowColor,
    this.muscleToneLevel = 0,
    this.flexPoseLevel = 0,
  });

  final double width;
  final double height;
  final Color color;
  final Color shadowColor;
  final double muscleToneLevel;
  final double flexPoseLevel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ArmPainter(
          color: color,
          shadowColor: shadowColor,
          muscleToneLevel: muscleToneLevel,
          flexPoseLevel: flexPoseLevel,
        ),
      ),
    );
  }
}

class _ArmPainter extends CustomPainter {
  const _ArmPainter({
    required this.color,
    required this.shadowColor,
    required this.muscleToneLevel,
    required this.flexPoseLevel,
  });

  final Color color;
  final Color shadowColor;
  final double muscleToneLevel;
  final double flexPoseLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final tone = muscleToneLevel.clamp(0.0, 1.0);
    final path = _buildDefaultArmPath(size, tone);

    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()..color = shadowColor.withValues(alpha: 0.18),
    );
    canvas.drawPath(path, Paint()..color = color);

    if (tone > 0.14) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.10 + tone * 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * 0.16),
        Offset(size.width * (0.62 + tone * 0.06), size.height * 0.42),
        highlightPaint,
      );

      final bicepPaint = Paint()
        ..color = shadowColor.withValues(alpha: 0.12 + tone * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.52, size.height * 0.28),
          width: size.width * (0.34 + tone * 0.16),
          height: size.height * (0.18 + tone * 0.08),
        ),
        math.pi * 0.9,
        math.pi * 0.85,
        false,
        bicepPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArmPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.muscleToneLevel != muscleToneLevel ||
        oldDelegate.flexPoseLevel != flexPoseLevel;
  }

  Path _buildDefaultArmPath(Size size, double tone) {
    return Path()
      ..moveTo(size.width * 0.46, 0)
      ..quadraticBezierTo(
        size.width * (0.08 - tone * 0.03),
        size.height * (0.18 - tone * 0.02),
        size.width * 0.14,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.96,
        size.width * 0.5,
        size.height * 0.98,
      )
      ..quadraticBezierTo(
        size.width * (0.86 + tone * 0.05),
        size.height * 0.92,
        size.width * 0.82,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.16,
        size.width * 0.5,
        0,
      )
      ..close();
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _AccessoryBadge extends StatelessWidget {
  const _AccessoryBadge({
    required this.accessory,
    required this.palette,
    required this.size,
    required this.accessoryMood,
    required this.outfitMode,
  });

  final _MiniMeAccessory accessory;
  final MiniMeFacePalette palette;
  final double size;
  final MiniMeAccessoryMood accessoryMood;
  final MiniMeOutfitMode outfitMode;

  @override
  Widget build(BuildContext context) {
    Widget baseAccessory;
    switch (accessory) {
      case _MiniMeAccessory.tie:
        baseAccessory = SizedBox(
          width: size,
          height: size * 1.1,
          child: CustomPaint(painter: _TiePainter(color: palette.accessory)),
        );
      case _MiniMeAccessory.band:
        baseAccessory = Container(
          width: size,
          height: size * 0.26,
          decoration: BoxDecoration(
            color: palette.accessory,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      case _MiniMeAccessory.none:
        baseAccessory = const SizedBox.shrink();
    }

    if (accessoryMood == MiniMeAccessoryMood.none &&
        outfitMode == MiniMeOutfitMode.standard) {
      return baseAccessory;
    }

    return SizedBox(
      width: size * 1.7,
      height: size * 1.55,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          baseAccessory,
          if (outfitMode == MiniMeOutfitMode.comfort)
            Positioned(
              top: size * 0.12,
              child: Container(
                width: size * 1.22,
                height: size * 0.36,
                decoration: BoxDecoration(
                  color: palette.secondary.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(size),
                ),
              ),
            ),
          if (accessoryMood == MiniMeAccessoryMood.coffee)
            Positioned(
              right: size * 0.02,
              top: size * 0.16,
              child: _MiniPropIcon(
                icon: Icons.coffee_rounded,
                color: const Color(0xFF9C6744),
              ),
            ),
          if (accessoryMood == MiniMeAccessoryMood.blanket)
            Positioned(
              top: size * 0.18,
              child: Container(
                width: size * 1.12,
                height: size * 0.4,
                decoration: BoxDecoration(
                  color: palette.secondary.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(size * 0.24),
                ),
              ),
            ),
          if (accessoryMood == MiniMeAccessoryMood.bandage)
            Positioned(
              left: size * 0.04,
              top: size * 0.2,
              child: Transform.rotate(
                angle: -0.28,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8D9BA),
                    borderRadius: BorderRadius.circular(size),
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.08,
                      height: size * 0.08,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC9B28E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (accessoryMood == MiniMeAccessoryMood.star)
            Positioned(
              right: size * 0.02,
              top: 0,
              child: _MiniPropIcon(
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFE1BD51),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniPropIcon extends StatelessWidget {
  const _MiniPropIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _TiePainter extends CustomPainter {
  const _TiePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.18),
          width: size.width * 0.28,
          height: size.height * 0.14,
        ),
        Radius.circular(size.width * 0.08),
      ),
      paint,
    );
    final tail = Path()
      ..moveTo(size.width * 0.5, size.height * 0.24)
      ..lineTo(size.width * 0.38, size.height * 0.96)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height,
        size.width * 0.62,
        size.height * 0.96,
      )
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _TiePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _Crest extends StatelessWidget {
  const _Crest({
    required this.crest,
    required this.palette,
    required this.size,
    required this.messyHairLevel,
    required this.recoveryLevel,
  });

  final _MiniMeCrest crest;
  final MiniMeFacePalette palette;
  final double size;
  final double messyHairLevel;
  final double recoveryLevel;

  @override
  Widget build(BuildContext context) {
    if (crest == _MiniMeCrest.none) {
      return const SizedBox.shrink();
    }

    return Transform.rotate(
      angle: (messyHairLevel - recoveryLevel * 0.35) * 0.14,
      child: SizedBox(
        width: size * 1.8,
        height: size * 1.3,
        child: CustomPaint(
          painter: _CrestPainter(
            crest: crest,
            color: palette.accessory,
            messyHairLevel: messyHairLevel,
          ),
        ),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  const _CrestPainter({
    required this.crest,
    required this.color,
    required this.messyHairLevel,
  });

  final _MiniMeCrest crest;
  final Color color;
  final double messyHairLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final droop = messyHairLevel * size.height * 0.12;

    void leaf(double startX, double peakX, double peakY, double endX) {
      final path = Path()
        ..moveTo(startX, size.height)
        ..quadraticBezierTo(peakX, peakY + droop, endX, size.height * 0.9)
        ..quadraticBezierTo(
          (startX + endX) / 2,
          size.height * (0.72 + messyHairLevel * 0.08),
          startX,
          size.height,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    switch (crest) {
      case _MiniMeCrest.fluff:
        leaf(
          size.width * 0.18,
          size.width * 0.34,
          size.height * 0.08,
          size.width * 0.46,
        );
        leaf(size.width * 0.42, size.width * 0.56, 0, size.width * 0.7);
        break;
      case _MiniMeCrest.sprout:
        leaf(
          size.width * 0.26,
          size.width * 0.4,
          size.height * 0.12,
          size.width * 0.54,
        );
        leaf(
          size.width * 0.46,
          size.width * 0.62,
          size.height * 0.04,
          size.width * 0.76,
        );
        break;
      case _MiniMeCrest.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CrestPainter oldDelegate) {
    return oldDelegate.crest != crest ||
        oldDelegate.color != color ||
        oldDelegate.messyHairLevel != messyHairLevel;
  }
}

_IdleMotion _motionForExpression(String expression, double t) {
  final wave = math.sin(t * math.pi * 2);
  final fastWave = math.sin(t * math.pi * 4);
  final slowWave = math.cos(t * math.pi * 2);

  switch (expression) {
    case 'happy':
      return _IdleMotion(
        bob: wave * 6.5,
        sway: wave * 0.03,
        turn: slowWave * 0.04,
        offsetX: wave * 1.4,
        shimmer: (slowWave + 1) / 2,
        headDip: math.max(0, wave) * -2.8,
        shadowScale: 0.96 - math.max(0, wave) * 0.05,
      );
    case 'sad':
      return _IdleMotion(
        bob: wave * 2.2 + 2.8,
        sway: wave * 0.012,
        turn: slowWave * 0.015,
        offsetX: 0,
        shimmer: 0.22,
        headDip: 4 + math.max(0, wave) * 1.4,
        shadowScale: 1.02,
      );
    case 'angry':
      return _IdleMotion(
        bob: wave * 2.8,
        sway: wave * 0.02,
        turn: slowWave * 0.02,
        offsetX: fastWave * 0.6,
        shimmer: 0.3,
        headDip: -0.6,
        shadowScale: 0.98,
      );
    case 'calm':
      return _IdleMotion(
        bob: wave * 3.2,
        sway: wave * 0.015,
        turn: slowWave * 0.02,
        offsetX: wave * 0.4,
        shimmer: (slowWave + 1) / 2 * 0.45,
        headDip: slowWave * -0.8,
        shadowScale: 1,
      );
    default:
      return _IdleMotion(
        bob: wave * 4.2,
        sway: wave * 0.02,
        turn: slowWave * 0.03,
        offsetX: wave * 0.8,
        shimmer: (slowWave + 1) / 2 * 0.6,
        headDip: slowWave * -1.2,
        shadowScale: 1,
      );
  }
}

_ReactionMotion _reactionMotion(_MiniMeReaction reaction, double t) {
  switch (reaction) {
    case _MiniMeReaction.flinch:
      final eased = Curves.easeOut.transform(t);
      return _ReactionMotion(
        bob: math.sin(eased * math.pi) * 5,
        sway: -math.sin(eased * math.pi) * 0.04,
        headDip: math.sin(eased * math.pi) * 10,
        leftArmLift: 0.14,
        rightArmLift: 0.14,
        shadowDelta: 0.06,
      );
    case _MiniMeReaction.doubleBicep:
      final enter = _timedPoseValue(t, enterEnd: 0.18, holdEnd: 0.78);
      final exit = t <= 0.78
          ? 0.0
          : Curves.easeIn.transform((t - 0.78) / 0.22).clamp(0.0, 1.0);
      final settle = Curves.easeInOut.transform(
        ((t - 0.18) / 0.60).clamp(0.0, 1.0),
      );
      return _ReactionMotion(
        bob: -enter * 2.4 + settle * 0.6 - exit * 0.8,
        sway: math.sin(settle * math.pi) * 0.004,
        headDip: -enter * 1.8 + settle * 0.4,
        leftArmLift: 0.12 + enter * 0.52 - exit * 0.08,
        rightArmLift: 0.12 + enter * 0.52 - exit * 0.08,
        flexPoseLevel: enter,
        shadowDelta: -0.06 * enter,
      );
    case _MiniMeReaction.bounce:
      final eased = Curves.easeOut.transform(t);
      return _ReactionMotion(
        bob: -math.sin(eased * math.pi) * 7,
        sway: 0,
        headDip: -math.sin(eased * math.pi) * 2,
        leftArmLift: 0.1,
        rightArmLift: 0.1,
        shadowDelta: -0.07,
      );
    case _MiniMeReaction.none:
      return const _ReactionMotion();
  }
}

class _IdleMotion {
  const _IdleMotion({
    required this.bob,
    required this.sway,
    required this.turn,
    required this.offsetX,
    required this.shimmer,
    required this.headDip,
    required this.shadowScale,
  });

  final double bob;
  final double sway;
  final double turn;
  final double offsetX;
  final double shimmer;
  final double headDip;
  final double shadowScale;
}

class _ReactionMotion {
  const _ReactionMotion({
    this.bob = 0,
    this.sway = 0,
    this.headDip = 0,
    this.leftArmLift = 0,
    this.rightArmLift = 0,
    this.flexPoseLevel = 0,
    this.shadowDelta = 0,
  });

  final double bob;
  final double sway;
  final double headDip;
  final double leftArmLift;
  final double rightArmLift;
  final double flexPoseLevel;
  final double shadowDelta;
}

enum _MiniMeReaction { none, flinch, doubleBicep, bounce }

double _timedPoseValue(
  double t, {
  required double enterEnd,
  required double holdEnd,
}) {
  if (t <= 0) return 0;
  if (t < enterEnd) {
    return Curves.easeOutBack.transform((t / enterEnd).clamp(0.0, 1.0));
  }
  if (t <= holdEnd) {
    return 1.0;
  }
  return (1 -
          Curves.easeInOut.transform(
            ((t - holdEnd) / (1 - holdEnd)).clamp(0.0, 1.0),
          ))
      .clamp(0.0, 1.0);
}

MiniMeFacePalette _resolvePalette(
  String bodyModel,
  String hairModel,
  String shirtModel,
  String? companionId,
) {
  final source = [
    companionId ?? '',
    bodyModel,
    hairModel,
    shirtModel,
  ].join('|').toLowerCase();
  final index = source.hashCode.abs() % _palettes.length;
  return _palettes[index];
}

String _resolveExpression(String? moodLabel) {
  switch ((moodLabel ?? '').trim().toLowerCase()) {
    case 'happy':
    case 'excited':
    case 'joyful':
      return 'happy';
    case 'calm':
    case 'peaceful':
      return 'calm';
    case 'anxious':
    case 'sad':
    case 'tired':
    case 'low':
      return 'sad';
    case 'angry':
    case 'frustrated':
      return 'angry';
    default:
      return 'neutral';
  }
}

double _resolveVisualWearLevel(String? moodLabel, double degradationLevel) {
  return degradationLevel.clamp(0.0, 1.0).toDouble();
}

_MiniMeCrest _resolveCrest(String hairModel) {
  final key = hairModel.toLowerCase();
  if (key.contains('male') || key.contains('sprout')) {
    return _MiniMeCrest.sprout;
  }
  if (key.contains('hair') || key.contains('fluff')) {
    return _MiniMeCrest.fluff;
  }
  return _MiniMeCrest.none;
}

_MiniMeAccessory _resolveAccessory(String shirtModel) {
  final key = shirtModel.toLowerCase();
  if (key.contains('tie')) {
    return _MiniMeAccessory.tie;
  }
  if (key.isNotEmpty) {
    return _MiniMeAccessory.band;
  }
  return _MiniMeAccessory.none;
}

enum _MiniMeAccessory { none, band, tie }

enum _MiniMeCrest { none, fluff, sprout }

const List<MiniMeFacePalette> _palettes = [
  MiniMeFacePalette(
    primary: Color(0xFFF8F6F2),
    secondary: Color(0xFF75A0E3),
    belly: Color(0xFFF2F0EC),
    beak: Color(0xFFE3D9CF),
    cheek: Color(0xFFF0B7C5),
    eye: Color(0xFF17345C),
    accessory: Color(0xFF90A7F4),
  ),
  MiniMeFacePalette(
    primary: Color(0xFFFFF6EA),
    secondary: Color(0xFFE7A16F),
    belly: Color(0xFFF6ECDD),
    beak: Color(0xFFE1B98A),
    cheek: Color(0xFFF0B6A6),
    eye: Color(0xFF3A2A27),
    accessory: Color(0xFF8B78D9),
  ),
  MiniMeFacePalette(
    primary: Color(0xFFF1FBF3),
    secondary: Color(0xFF67BEA0),
    belly: Color(0xFFE8F5EA),
    beak: Color(0xFFD9E6D7),
    cheek: Color(0xFFF0C4CF),
    eye: Color(0xFF234236),
    accessory: Color(0xFF5C9D87),
  ),
  MiniMeFacePalette(
    primary: Color(0xFFF8F8FC),
    secondary: Color(0xFF9A8DE8),
    belly: Color(0xFFF0F0F8),
    beak: Color(0xFFE4DCF2),
    cheek: Color(0xFFF0BED1),
    eye: Color(0xFF2B2950),
    accessory: Color(0xFFE89172),
  ),
];
