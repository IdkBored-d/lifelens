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
    this.illnessLevel = 0,
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
  final double illnessLevel;
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
            other.illnessLevel == illnessLevel &&
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
    illnessLevel,
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
    this.animationState,
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
    this.autoWaveToken = 0,
    this.lockScreenPosition = false,
    this.headTiltBias = 0,
    this.celebrateOnOpen = false,
    this.danceOnOpen = false,
  });

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String? companionId;
  final String? moodLabel;
  final String? moodEmoji;
  final String? animationState;
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
  final int autoWaveToken;
  final bool lockScreenPosition;
  final double headTiltBias;
  final bool celebrateOnOpen;
  final bool danceOnOpen;

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
    this.blink = 0,
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
  final double blink;
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
    final expression = _resolveExpression(moodLabel, null);
    final normalizedBodyWidth = bodyWidthScale.clamp(0.82, 1.24);
    final headSize = size * 0.62;
    final shouldersWidth = size * 0.68 * normalizedBodyWidth;
    final shouldersHeight = size * 0.28;
    final headTop = size * 0.12;
    final faceTop = headTop + headSize * 0.26;
    final shouldersBottom = size * 0.12;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: shouldersBottom,
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
            top: headTop,
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
            top: faceTop,
            child: CartoonFace(
              expression: expression,
              palette: palette,
              size: headSize * 0.5,
              blink: blink,
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
    duration: const Duration(milliseconds: 1550),
  );

  _MiniMeReaction _reaction = _MiniMeReaction.none;
  bool _didNotifyHatchComplete = false;
  bool _didAutoWave = false;
  bool _coughLoopScheduled = false;
  bool _cryLoopScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleAutoGreetingIfNeeded();
      _scheduleIllnessCoughIfNeeded(delay: const Duration(milliseconds: 900));
      _scheduleSadCryIfNeeded(delay: const Duration(milliseconds: 760));
    });
  }

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
    } else if (dx < 0.28 && dy < 0.72) {
      _triggerReaction(_MiniMeReaction.doubleBicep);
    } else if (dx > 0.72 && dy < 0.72) {
      _triggerReaction(_MiniMeReaction.wave);
    } else if (dx >= 0.36 && dx <= 0.64 && dy < 0.62) {
      _triggerReaction(_MiniMeReaction.shimmy);
    } else if (dx >= 0.34 && dx <= 0.66 && dy < 0.84) {
      _triggerReaction(_MiniMeReaction.bounce);
    } else if (dy >= 0.84) {
      _triggerReaction(_MiniMeReaction.celebrate);
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
    if (widget.autoWaveToken != oldWidget.autoWaveToken) {
      _didAutoWave = false;
      _scheduleAutoGreetingIfNeeded(delay: const Duration(milliseconds: 220));
    }
    if (widget.isHatched && !oldWidget.isHatched) {
      _hatchController.value = 1;
      _didNotifyHatchComplete = true;
      _scheduleAutoGreetingIfNeeded(delay: const Duration(milliseconds: 260));
      _scheduleIllnessCoughIfNeeded(delay: const Duration(milliseconds: 900));
    } else if (!widget.isHatched && oldWidget.isHatched) {
      _hatchController.value = 0;
      _didNotifyHatchComplete = false;
      _didAutoWave = false;
      _coughLoopScheduled = false;
      _cryLoopScheduled = false;
    } else if (widget.visualState.illnessLevel > 0.36 &&
        oldWidget.visualState.illnessLevel <= 0.36) {
      _scheduleIllnessCoughIfNeeded(delay: const Duration(milliseconds: 420));
    }
    if (_isSadMood(widget.moodLabel, widget.animationState) &&
        !_isSadMood(oldWidget.moodLabel, oldWidget.animationState)) {
      _scheduleSadCryIfNeeded(delay: const Duration(milliseconds: 420));
    }
  }

  void _scheduleIllnessCoughIfNeeded({
    Duration delay = const Duration(seconds: 7),
  }) {
    if (_coughLoopScheduled || !mounted || !widget.isHatched) {
      return;
    }
    if (widget.visualState.illnessLevel <= 0.36) {
      return;
    }

    _coughLoopScheduled = true;
    Future<void>.delayed(delay, () {
      _coughLoopScheduled = false;
      if (!mounted || !widget.isHatched) return;
      if (widget.visualState.illnessLevel <= 0.36) return;

      if (_reaction == _MiniMeReaction.none) {
        _triggerReaction(_MiniMeReaction.cough);
      }
      _scheduleIllnessCoughIfNeeded();
    });
  }

  void _scheduleSadCryIfNeeded({Duration delay = const Duration(seconds: 8)}) {
    if (_cryLoopScheduled || !mounted || !widget.isHatched) {
      return;
    }
    if (!_isSadMood(widget.moodLabel, widget.animationState)) {
      return;
    }

    _cryLoopScheduled = true;
    Future<void>.delayed(delay, () {
      _cryLoopScheduled = false;
      if (!mounted || !widget.isHatched) return;
      if (!_isSadMood(widget.moodLabel, widget.animationState)) return;

      if (_reaction == _MiniMeReaction.none) {
        _triggerReaction(_MiniMeReaction.cry);
      }
      _scheduleSadCryIfNeeded();
    });
  }

  void _scheduleAutoGreetingIfNeeded({
    Duration delay = const Duration(milliseconds: 420),
  }) {
    if (_didAutoWave || !widget.isHatched || !mounted) {
      return;
    }

    _didAutoWave = true;
    Future<void>.delayed(delay, () {
      if (!mounted) return;
      if (_reaction != _MiniMeReaction.none) return;
      if (_isSadMood(widget.moodLabel, widget.animationState)) {
        _triggerReaction(_MiniMeReaction.cry);
        _scheduleSadCryIfNeeded();
        return;
      }
      if (widget.danceOnOpen) {
        _triggerReaction(_MiniMeReaction.dance);
        return;
      }
      if (widget.celebrateOnOpen) {
        _triggerReaction(_MiniMeReaction.celebrate);
        return;
      }
      // Randomly wave or bounce on each greeting
      final useWave = (DateTime.now().millisecondsSinceEpoch % 2) == 0;
      _triggerReaction(useWave ? _MiniMeReaction.wave : _MiniMeReaction.bounce);
    });
  }

  void _triggerReaction(_MiniMeReaction reaction) {
    final duration = switch (reaction) {
      _MiniMeReaction.doubleBicep => const Duration(milliseconds: 2000),
      _MiniMeReaction.wave => const Duration(milliseconds: 2050),
      _MiniMeReaction.celebrate => const Duration(milliseconds: 1600),
      _MiniMeReaction.shimmy => const Duration(milliseconds: 1150),
      _MiniMeReaction.bounce => const Duration(milliseconds: 1400),
      _MiniMeReaction.cough => const Duration(milliseconds: 1350),
      _MiniMeReaction.cry => const Duration(milliseconds: 2850),
      _MiniMeReaction.dance => const Duration(milliseconds: 3200),
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
    final expression = _resolveExpression(
      widget.moodLabel,
      widget.animationState,
    );
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
              final bob =
                  (widget.lockScreenPosition
                      ? 0.0
                      : idleMotion.bob * energyScale) +
                  reactionMotion.bob;
              final sway =
                  idleMotion.sway *
                      (0.76 + widget.visualState.energyLevel * 0.38) +
                  reactionMotion.sway;
              final headDip =
                  idleMotion.headDip +
                  widget.visualState.postureSlump * 4.5 -
                  widget.visualState.recoveryLevel * 1.2 +
                  reactionMotion.headDip;
              final conversationalHeadTilt = widget.headTiltBias == 0
                  ? 0.0
                  : widget.headTiltBias +
                        math.sin(_idleController.value * math.pi * 2) * 0.018;
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
              final preHatchIdle =
                  (!widget.isHatched && !_hatchController.isAnimating)
                  ? 1.0
                  : (1 - hatchProgress).clamp(0.0, 1.0);
              final hatchCharge = ((hatchProgress - 0.08) / 0.44).clamp(
                0.0,
                1.0,
              );
              final hatchBurst = ((hatchProgress - 0.52) / 0.42).clamp(
                0.0,
                1.0,
              );
              final revealFlash =
                  (1.0 - ((hatchProgress - 0.66).abs() / 0.18).clamp(0.0, 1.0))
                      .clamp(0.0, 1.0);
              final eggOpacity = (1 - (hatchProgress * 1.5)).clamp(0.0, 1.0);
              final mascotOpacity = ((hatchProgress - 0.28) / 0.72).clamp(
                0.0,
                1.0,
              );
              final eggScale =
                  1.0 -
                  (hatchProgress * 0.08) +
                  math.sin(_idleController.value * math.pi * 2) *
                      preHatchIdle *
                      0.018;
              final mascotScale = 0.82 + (mascotOpacity * 0.18);
              final eggIdleLift =
                  -math.sin(_idleController.value * math.pi * 2) *
                  clampedSize *
                  0.012 *
                  preHatchIdle;
              final eggIdleSway =
                  math.sin(_idleController.value * math.pi * 4) *
                  0.028 *
                  preHatchIdle;
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
                  if (!widget.isHatched || hatchBurst < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _HatchLevelUpFx(
                          size: clampedSize,
                          color: widget.glow ?? palette.primary,
                          chargeProgress: hatchCharge,
                          burstProgress: hatchBurst,
                          flashProgress: revealFlash,
                          pulseT: _idleController.value,
                        ),
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
                    offset: Offset(
                      widget.lockScreenPosition
                          ? hatchShake
                          : idleMotion.offsetX + hatchShake,
                      bob,
                    ),
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
                                    coughMouthOpen:
                                        reactionMotion.coughMouthOpen,
                                    cryingLevel: reactionMotion.cryingLevel,
                                    headDip:
                                        headDip -
                                        (1 - mascotOpacity) * 10 -
                                        muscleTone * 3.5,
                                    headTilt: conversationalHeadTilt,
                                    degradationLevel: visualWearLevel,
                                    visualState: widget.visualState,
                                    powerPulse: powerPulse,
                                  ),
                                ),
                              ),
                            if (!widget.isHatched || eggOpacity > 0)
                              Opacity(
                                opacity: eggOpacity,
                                child: Transform.translate(
                                  offset: Offset(0, eggIdleLift),
                                  child: Transform.rotate(
                                    angle: eggIdleSway,
                                    child: Transform.scale(
                                      scale: eggScale,
                                      child: _MiniMeEgg(
                                        size: clampedSize * 0.7,
                                        accentColor:
                                            widget.glow ?? palette.accessory,
                                        bob: bob,
                                        crackProgress: hatchProgress,
                                        idlePulse: preHatchIdle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (reactionMotion.coughPuff > 0)
                    Positioned(
                      top: clampedSize * 0.22,
                      left: clampedSize * 0.54,
                      child: IgnorePointer(
                        child: _CoughPuffFx(
                          size: clampedSize,
                          progress: reactionMotion.coughPuff,
                          color: widget.glow ?? palette.accessory,
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
    required this.coughMouthOpen,
    required this.cryingLevel,
    required this.headDip,
    required this.headTilt,
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
  final double coughMouthOpen;
  final double cryingLevel;
  final double headDip;
  final double headTilt;
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
    final illnessLevel = visualState.illnessLevel.clamp(0.0, 1.0);
    final bodyWidth =
        size *
        0.44 *
        (bodyWidthScale.clamp(0.78, 1.28) +
            displayedMuscleTone * 0.08 -
            illnessLevel * 0.05);
    final bodyHeight =
        size * (0.46 + displayedMuscleTone * 0.03 - illnessLevel * 0.012);
    final slumpOffset =
        (visualState.postureSlump * 0.76 + illnessLevel * 0.24) * size * 0.04;
    final confidenceLift = displayedMuscleTone * size * 0.022;
    final headTop = size * 0.13 + headDip * 0.2 + slumpOffset - confidenceLift;
    final headOffsetX = headTilt * headSize * 0.12;
    final bodyTop = size * 0.38 + slumpOffset * 0.5 - confidenceLift * 0.4;
    final torsoTilt =
        visualState.postureSlump * -0.06 +
        visualState.recoveryLevel * 0.02 +
        displayedMuscleTone * 0.018;
    final shoulderDrop =
        visualState.postureSlump * size * 0.02 -
        illnessLevel * size * 0.012 -
        displayedMuscleTone * size * 0.01;
    final armWidth =
        size * (0.16 + displayedMuscleTone * 0.035 - illnessLevel * 0.008);
    final armHeight =
        size * (0.25 + displayedMuscleTone * 0.015 - illnessLevel * 0.006);
    final shoulderSpread =
        size * (displayedMuscleTone * 0.035 + flexPose * 0.012);
    final flexLift = displayedMuscleTone * 0.16 + flexPose * 0.14;
    final armTop =
        bodyTop +
        size * 0.04 +
        shoulderDrop -
        (armLiftLeft + flexPose * 0.04) * size * 0.11;
    final legTop = bodyTop + bodyHeight * 0.75;
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
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: headTop - headSize * 0.08,
            left: size / 2 - headSize * 0.17 + headOffsetX,
            child: Transform.rotate(
              angle: headTilt * 0.85,
              child: _Crest(
                crest: crest,
                palette: palette,
                size: headSize * 0.34,
                messyHairLevel: visualState.messyHairLevel,
                recoveryLevel: visualState.recoveryLevel,
              ),
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
            left: size / 2 - headSize / 2 + headOffsetX,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(torsoTurn * 0.65)
                ..rotateZ(headTilt)
                ..scaleByDouble(
                  1 - displayedMuscleTone * 0.02 - illnessLevel * 0.14,
                  1 - displayedMuscleTone * 0.02 + illnessLevel * 0.035,
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
            left: size / 2 - headSize * 0.36 + headOffsetX,
            child: Transform.rotate(
              angle: headTilt,
              child: Transform.scale(
                scaleX: 1 - illnessLevel * 0.12,
                scaleY: 1 + illnessLevel * 0.03,
                child: CartoonFace(
                  expression: expression,
                  palette: palette,
                  size: headSize * 0.72,
                  blink: blink,
                  degradationLevel: degradationLevel,
                  headDip: headDip,
                  wateryEyes: visualState.wateryEyes,
                  puffiness: (visualState.sleepDebtLevel + illnessLevel * 0.68)
                      .clamp(0.0, 1.0),
                  sickLevel: illnessLevel,
                  coughOpen: coughMouthOpen,
                  cryingLevel: cryingLevel,
                ),
              ),
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
            top: legTop,
            child: _Leg(
              width: size * 0.11,
              height: size * 0.205,
              color: palette.belly,
            ),
          ),
          Positioned(
            right: size / 2 - bodyWidth * 0.24,
            top: legTop,
            child: _Leg(
              width: size * 0.11,
              height: size * 0.205,
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
    this.idlePulse = 0,
  });

  final double size;
  final Color accentColor;
  final double bob;
  final double crackProgress;
  final double idlePulse;

  @override
  Widget build(BuildContext context) {
    final shellGlow = idlePulse.clamp(0.0, 1.0);
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
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(
                      alpha: 0.06 + shellGlow * 0.1,
                    ),
                    blurRadius: size * (0.02 + shellGlow * 0.03),
                    spreadRadius: size * (0.003 + shellGlow * 0.006),
                  ),
                ],
              ),
            ),
            if (shellGlow > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: size * (0.64 + shellGlow * 0.04),
                      height: size * (0.78 + shellGlow * 0.04),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size),
                        gradient: RadialGradient(
                          colors: [
                            accentColor.withValues(
                              alpha: 0.08 + shellGlow * 0.04,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
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

class _HatchLevelUpFx extends StatelessWidget {
  const _HatchLevelUpFx({
    required this.size,
    required this.color,
    required this.chargeProgress,
    required this.burstProgress,
    required this.flashProgress,
    required this.pulseT,
  });

  final double size;
  final Color color;
  final double chargeProgress;
  final double burstProgress;
  final double flashProgress;
  final double pulseT;

  @override
  Widget build(BuildContext context) {
    final pulse = (math.sin(pulseT * math.pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0);
    final glowSize = size * (0.44 + chargeProgress * 0.34 + pulse * 0.02);
    final coreOpacity = (0.16 + chargeProgress * 0.22 + flashProgress * 0.18)
        .clamp(0.0, 0.7)
        .toDouble();

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: glowSize,
          height: glowSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: coreOpacity),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
        CustomPaint(
          size: Size(size, size),
          painter: _HatchLevelUpPainter(
            color: color,
            chargeProgress: chargeProgress,
            burstProgress: burstProgress,
            flashProgress: flashProgress,
          ),
        ),
      ],
    );
  }
}

class _HatchLevelUpPainter extends CustomPainter {
  const _HatchLevelUpPainter({
    required this.color,
    required this.chargeProgress,
    required this.burstProgress,
    required this.flashProgress,
  });

  final Color color;
  final double chargeProgress;
  final double burstProgress;
  final double flashProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.22;

    final ring1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = color.withValues(
        alpha: (0.06 + chargeProgress * 0.2).clamp(0.0, 0.35),
      );
    final ring2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color.withValues(
        alpha: (0.04 + burstProgress * 0.34).clamp(0.0, 0.45),
      );

    canvas.drawCircle(
      center,
      baseRadius + chargeProgress * size.shortestSide * 0.06,
      ring1,
    );
    if (burstProgress > 0) {
      canvas.drawCircle(
        center,
        baseRadius + size.shortestSide * (0.07 + burstProgress * 0.22),
        ring2,
      );
    }

    final particleCount = 14;
    for (var i = 0; i < particleCount; i++) {
      final t = i / particleCount;
      final angle = t * math.pi * 2 + burstProgress * 1.6;
      final spread = size.shortestSide * (0.12 + burstProgress * 0.32);
      final offset = Offset(math.cos(angle) * spread, math.sin(angle) * spread);
      final particleRadius = (size.shortestSide * 0.008 + burstProgress * 1.8)
          .clamp(1.0, 3.4)
          .toDouble();
      final alpha = (0.08 + burstProgress * 0.45 - t * 0.06).clamp(0.0, 0.48);
      canvas.drawCircle(
        center + offset,
        particleRadius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    if (flashProgress > 0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: (flashProgress * 0.28).clamp(0.0, 0.28),
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        center,
        size.shortestSide * (0.12 + flashProgress * 0.24),
        flashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchLevelUpPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.chargeProgress != chargeProgress ||
        oldDelegate.burstProgress != burstProgress ||
        oldDelegate.flashProgress != flashProgress;
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

    if (visualState.illnessLevel > 0.05) {
      final sickTint = Paint()
        ..color = const Color(
          0xFFB7D7C4,
        ).withValues(alpha: visualState.illnessLevel * 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          headRect.deflate(size.width * 0.015),
          Radius.circular(size.width * 0.32),
        ),
        sickTint,
      );

      final hollowPaint = Paint()
        ..color = const Color(
          0xFF53617F,
        ).withValues(alpha: visualState.illnessLevel * 0.11)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.7),
          width: size.width * (0.34 + visualState.illnessLevel * 0.08),
          height: size.height * 0.2,
        ),
        hollowPaint,
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
    case 'affectionate':
      return _IdleMotion(
        bob: wave * 4.8,
        sway: wave * 0.02,
        turn: slowWave * 0.026,
        offsetX: wave * 0.9,
        shimmer: (slowWave + 1) / 2 * 0.75,
        headDip: math.max(0, wave) * -1.8,
        shadowScale: 0.98 - math.max(0, wave) * 0.03,
      );
    case 'surprised':
      return _IdleMotion(
        bob: wave.abs() * 6.2 - 1.2,
        sway: wave * 0.018,
        turn: slowWave * 0.012,
        offsetX: fastWave * 0.5,
        shimmer: 0.82,
        headDip: -1.6 + math.max(0, wave) * -1.3,
        shadowScale: 0.96,
      );
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
    case _MiniMeReaction.wave:
      // Phase 1 (0–0.18): arm shoots up quickly
      final raise = Curves.easeOutBack.transform((t / 0.18).clamp(0.0, 1.0));
      // Phase 2 (0.14–0.78): waving window — 4 full back-and-forth swings
      final waveWindow = ((t - 0.14) / 0.64).clamp(0.0, 1.0);
      final waveEnvelope = math.sin(waveWindow * math.pi).clamp(0.0, 1.0);
      // 4 swings = 4 * π * 2 half-cycles; abs() gives snappy back-and-forth
      final swingRaw = math.sin(waveWindow * math.pi * 8.0);
      final swing = swingRaw * waveEnvelope; // −1 → +1, enveloped
      // Phase 3 (0.78–1.0): lower arm back down
      final lower = Curves.easeInCubic.transform(
        ((t - 0.78) / 0.22).clamp(0.0, 1.0),
      );
      // Arm stays raised high (0.72 at peak) + swings add ±0.20 excursion
      final armBase = raise * 0.72 * (1.0 - lower);
      final armSwing = swing * 0.20 * (1.0 - lower);
      // Slight body lean in the direction of the wave
      final bodySway = swing * 0.022 * waveEnvelope;
      // Head tilts toward the raised arm, nods slightly with each swing
      final headNod = swing * 0.055 * waveEnvelope;
      return _ReactionMotion(
        bob: -raise * 1.8 * (1.0 - lower) + waveEnvelope * 0.6,
        sway: bodySway,
        headDip: -raise * 0.5 * (1.0 - lower) + headNod,
        leftArmLift: 0.0,
        rightArmLift: armBase + armSwing,
        shadowDelta: -0.015 * raise * (1.0 - lower),
      );
    case _MiniMeReaction.shimmy:
      final shimmyWindow = math.sin(t * math.pi).clamp(0.0, 1.0);
      final shimmyCycle = math.sin(t * math.pi * 7.5) * shimmyWindow;
      final shoulderPop = math.max(0.0, math.sin(t * math.pi * 3.8));
      return _ReactionMotion(
        bob: -shimmyWindow * 1.6 + shoulderPop * 0.6,
        sway: shimmyCycle * 0.018,
        headDip: -shoulderPop * 0.7,
        leftArmLift: 0.08 + shoulderPop * 0.1,
        rightArmLift: 0.08 + (1 - shoulderPop) * 0.1,
        shadowDelta: -0.03 * shimmyWindow,
      );
    case _MiniMeReaction.celebrate:
      final launch = Curves.easeOutCubic.transform((t / 0.22).clamp(0.0, 1.0));
      final airborne = ((t - 0.14) / 0.46).clamp(0.0, 1.0);
      final jumpArc = math.sin(airborne * math.pi).clamp(0.0, 1.0);
      final airborneTwist = math.sin(airborne * math.pi * 1.2) * jumpArc;
      final landing = ((t - 0.58) / 0.20).clamp(0.0, 1.0);
      final landingBounce = math.sin(landing * math.pi) * (1 - landing) * 0.42;
      final settle = Curves.easeOutCubic.transform(
        ((t - 0.78) / 0.22).clamp(0.0, 1.0),
      );
      final armLift = 0.18 + launch * 0.24 + jumpArc * 0.3 - settle * 0.04;
      return _ReactionMotion(
        bob: -jumpArc * 22 - launch * 2.5 + landingBounce * 5.5,
        sway: airborneTwist * 0.012,
        headDip: -jumpArc * 2.6 + landingBounce * 0.8,
        leftArmLift: armLift,
        rightArmLift: armLift,
        shadowDelta: -0.1 * jumpArc + landingBounce * 0.03,
      );
    case _MiniMeReaction.bounce:
      // Three distinct jumps: t maps 0→1 across 1400ms
      final jumpCount = 3;
      final segment = (t * jumpCount).clamp(0.0, jumpCount.toDouble());
      final jumpT = segment - segment.floor();
      // Each jump: quick rise (ease-in) and fast fall (elastic-like landing)
      final arc = math.sin(jumpT * math.pi);
      // Amplitude shrinks slightly for each successive jump
      final jumpIndex = segment.floor();
      final amp = 1.0 - jumpIndex * 0.15;
      final bobHeight = arc * 32 * amp; // tall, noticeable
      final landingSquash =
          (1.0 - arc) * (jumpT > 0.5 ? (jumpT - 0.5) * 2 : 0.0);
      return _ReactionMotion(
        bob: -bobHeight + landingSquash * 4,
        sway: math.sin(t * math.pi * jumpCount * 2) * 0.008,
        headDip: -arc * 3.5 * amp + landingSquash * 1.5,
        leftArmLift: arc * 0.18 * amp,
        rightArmLift: arc * 0.18 * amp,
        shadowDelta: -0.14 * arc * amp,
      );
    case _MiniMeReaction.cough:
      final pulseA = math.sin((t / 0.42).clamp(0.0, 1.0) * math.pi);
      final pulseB = math.sin(((t - 0.34) / 0.42).clamp(0.0, 1.0) * math.pi);
      final coughPulse = math.max(pulseA, pulseB).clamp(0.0, 1.0);
      final settle = Curves.easeOutCubic.transform(
        ((t - 0.66) / 0.34).clamp(0.0, 1.0),
      );
      final hunch = (coughPulse * (1 - settle * 0.35)).clamp(0.0, 1.0);
      final shake = math.sin(t * math.pi * 18) * coughPulse;
      final puffWindow = ((t - 0.08) / 0.76).clamp(0.0, 1.0);
      return _ReactionMotion(
        bob: hunch * 3.2,
        sway: -hunch * 0.08 + shake * 0.012,
        headDip: hunch * 13.5 + shake * 1.2,
        leftArmLift: 0.1 + hunch * 0.32,
        rightArmLift: 0.1 + hunch * 0.28,
        shadowDelta: 0.06 * hunch,
        coughPuff: math.sin(puffWindow * math.pi).clamp(0.0, 1.0),
        coughMouthOpen: coughPulse,
      );
    case _MiniMeReaction.cry:
      final enter = Curves.easeOutCubic.transform((t / 0.18).clamp(0.0, 1.0));
      final exit =
          1 - Curves.easeInCubic.transform(((t - 0.86) / 0.14).clamp(0.0, 1.0));
      final envelope = (enter * exit).clamp(0.0, 1.0);
      final sobA = math.max(0.0, math.sin(t * math.pi * 4.4));
      final sobB = math.max(0.0, math.sin((t * math.pi * 4.4) - 0.72));
      final sobPulse = math.max(sobA, sobB) * envelope;
      final tremble = math.sin(t * math.pi * 18.0) * envelope;
      return _ReactionMotion(
        bob: sobPulse * 2.8 + envelope * 1.1,
        sway: -envelope * 0.018 + tremble * 0.004,
        headDip: envelope * 5.8 + sobPulse * 1.8 + tremble * 0.32,
        leftArmLift: 0.08 + envelope * 0.18 + sobPulse * 0.04,
        rightArmLift: 0.08 + envelope * 0.2 + sobPulse * 0.04,
        shadowDelta: 0.032 * envelope,
        cryingLevel: (0.34 + sobPulse * 0.4) * envelope,
      );
    case _MiniMeReaction.dance:
      // 3200ms of full-body groove: 4-beat bar (800ms each) × 4 bars
      // beat: t subdivided into 16 beats (0.0625 each)
      final beat = (t * 16).floor();
      final beatT = (t * 16) - beat; // 0→1 within each beat
      // Hip sway: alternate left/right every beat — sin over whole duration
      final hipSway = math.sin(t * math.pi * 8) * 0.038;
      // Bob: bounce up on every beat (sharp up, ease down = gravity feel)
      final bobRaw = math.pow(1.0 - beatT, 2.0).toDouble();
      final bobHeight = bobRaw * 7.0;
      // Arms pump alternately: left up on even beats, right up on odd beats
      final isEvenBeat = beat % 2 == 0;
      final armPump =
          Curves.easeOutCubic.transform(
            math.sin(beatT * math.pi).clamp(0.0, 1.0),
          ) *
          0.28;
      // Head nod: tilts slightly toward the raised arm on each beat
      final headNod = math.sin(t * math.pi * 8) * 0.06;
      // Fade out the last 10% of the animation so it lands cleanly
      final fadeOut = (1.0 - ((t - 0.9) / 0.1).clamp(0.0, 1.0));
      return _ReactionMotion(
        bob: bobHeight * fadeOut,
        sway: hipSway * fadeOut,
        headDip: headNod * fadeOut,
        leftArmLift: (isEvenBeat ? armPump : armPump * 0.12) * fadeOut,
        rightArmLift: (isEvenBeat ? armPump * 0.12 : armPump) * fadeOut,
        shadowDelta: -0.04 * bobRaw * fadeOut,
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
    this.coughPuff = 0,
    this.coughMouthOpen = 0,
    this.cryingLevel = 0,
  });

  final double bob;
  final double sway;
  final double headDip;
  final double leftArmLift;
  final double rightArmLift;
  final double flexPoseLevel;
  final double shadowDelta;
  final double coughPuff;
  final double coughMouthOpen;
  final double cryingLevel;
}

enum _MiniMeReaction {
  none,
  flinch,
  doubleBicep,
  wave,
  shimmy,
  celebrate,
  bounce,
  cough,
  cry,
  dance,
}

class _CoughPuffFx extends StatelessWidget {
  const _CoughPuffFx({
    required this.size,
    required this.progress,
    required this.color,
  });

  final double size;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.28,
      height: size * 0.18,
      child: CustomPaint(
        painter: _CoughPuffPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
        ),
      ),
    );
  }
}

class _CoughPuffPainter extends CustomPainter {
  const _CoughPuffPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress);
    final alpha = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.34 * alpha);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.08 * alpha);

    final centers = [
      Offset(size.width * (0.16 + eased * 0.18), size.height * 0.56),
      Offset(size.width * (0.34 + eased * 0.25), size.height * 0.38),
      Offset(size.width * (0.54 + eased * 0.28), size.height * 0.62),
    ];
    final radii = [0.12, 0.1, 0.085];
    for (var i = 0; i < centers.length; i++) {
      final radius = size.width * (radii[i] + eased * 0.055);
      canvas.drawCircle(centers[i], radius, fillPaint);
      canvas.drawCircle(centers[i], radius, paint);
    }

    final burstPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.24 * alpha);
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.76),
      Offset(size.width * (0.2 + eased * 0.16), size.height * 0.86),
      burstPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.36),
      Offset(size.width * (0.24 + eased * 0.18), size.height * 0.22),
      burstPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoughPuffPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

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
  switch ((companionId ?? '').trim().toLowerCase()) {
    case 'pebble':
      return _sunsetPalette;
    case 'sprig':
      return _mintPalette;
    case 'dawn':
      return _twilightPalette;
    case 'cloud':
    default:
      return _classicPalette;
  }
}

String _resolveExpression(String? moodLabel, String? animationState) {
  switch ((moodLabel ?? '').trim().toLowerCase()) {
    case 'affectionate':
    case 'love':
      return 'affectionate';
    case 'surprised':
    case 'surprise':
      return 'surprised';
    case 'happy':
    case 'excited':
    case 'joyful':
    case 'joy':
      return 'happy';
    case 'neutral':
    case 'content':
      return 'neutral';
    case 'scared':
    case 'fear':
    case 'anxious':
      return 'scared';
    case 'sad':
    case 'sadness':
    case 'tired':
    case 'low':
      return 'sad';
    case 'angry':
    case 'anger':
    case 'frustrated':
      return 'angry';
  }

  // Only fall back to animation hints when no explicit mood can be resolved.
  switch ((animationState ?? '').trim().toLowerCase()) {
    case 'alert_pulse':
      return 'angry';
    case 'recover_rise':
      return 'happy';
    case 'decline_fade':
      return 'sad';
    case 'steady_idle':
      return 'calm';
    default:
      return 'neutral';
  }
}

bool _isSadMood(String? moodLabel, String? animationState) {
  return _resolveExpression(moodLabel, animationState) == 'sad';
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

const MiniMeFacePalette _classicPalette = MiniMeFacePalette(
  primary: Color(0xFFE8EDF7),
  secondary: Color(0xFF5F8FD7),
  belly: Color(0xFFF5F7FB),
  beak: Color(0xFFD8DEEA),
  cheek: Color(0xFFF0B7C5),
  eye: Color(0xFF17345C),
  accessory: Color(0xFF6F83E8),
);

const MiniMeFacePalette _sunsetPalette = MiniMeFacePalette(
  primary: Color(0xFFFFF6EF),
  secondary: Color(0xFFE59678),
  belly: Color(0xFFFFFBF6),
  beak: Color(0xFFF3DCCD),
  cheek: Color(0xFFF2B8A9),
  eye: Color(0xFF3E2D3B),
  accessory: Color(0xFFE8A06F),
);

const MiniMeFacePalette _mintPalette = MiniMeFacePalette(
  primary: Color(0xFFF2FAF4),
  secondary: Color(0xFF6AB79D),
  belly: Color(0xFFF8FEFA),
  beak: Color(0xFFDDEEE3),
  cheek: Color(0xFFBDE4D0),
  eye: Color(0xFF1F3D33),
  accessory: Color(0xFF6CC2A4),
);

const MiniMeFacePalette _twilightPalette = MiniMeFacePalette(
  primary: Color(0xFFCFCCEC),
  secondary: Color(0xFF646CB8),
  belly: Color(0xFFE4E1F5),
  beak: Color(0xFFC9C4E3),
  cheek: Color(0xFFB4AAD7),
  eye: Color(0xFF1E2245),
  accessory: Color(0xFF6E75C8),
);
