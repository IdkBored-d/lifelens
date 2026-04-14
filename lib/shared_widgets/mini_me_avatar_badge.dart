import 'package:flutter/material.dart';
import 'package:lifelens/assets/minime/minime_avatar.dart';

class MiniMeAvatarBadge extends StatelessWidget {
  const MiniMeAvatarBadge({
    super.key,
    required this.size,
    this.padding = 4,
    this.backgroundColor,
    this.borderColor,
    this.bodyModel,
    this.hairModel,
    this.shirtModel,
    this.bodyWidthScale,
    this.companionId,
    this.isHatched = true,
    this.degradationLevel = 0,
    this.fallbackLabel,
  });

  final double size;
  final double padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? bodyModel;
  final String? hairModel;
  final String? shirtModel;
  final double? bodyWidthScale;
  final String? companionId;
  final bool isHatched;
  final double degradationLevel;
  final String? fallbackLabel;

  bool get _hasMiniMeSnapshot =>
      (bodyModel ?? '').isNotEmpty &&
      (hairModel ?? '').isNotEmpty &&
      (shirtModel ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatarSize = size - (padding * 2);
    final usePortraitRenderer = avatarSize <= 60;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? cs.primaryContainer,
        border: Border.all(
          color: borderColor ?? cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: cs.surface.withValues(alpha: 0.96),
          child: _hasMiniMeSnapshot
              ? IgnorePointer(
                  child: usePortraitRenderer
                      ? MiniMePortraitAvatar(
                          bodyModel: bodyModel!,
                          hairModel: hairModel!,
                          shirtModel: shirtModel!,
                          bodyWidthScale: bodyWidthScale ?? 1.0,
                          companionId: companionId,
                          size: avatarSize,
                          degradationLevel: degradationLevel,
                        )
                      : MiniMeAvatar(
                          bodyModel: bodyModel!,
                          hairModel: hairModel!,
                          shirtModel: shirtModel!,
                          bodyWidthScale: bodyWidthScale ?? 1.0,
                          companionId: companionId,
                          size: avatarSize,
                          enableAutoRotate: false,
                          enableInteractions: false,
                          isHatched: isHatched,
                          degradationLevel: degradationLevel,
                        ),
                )
              : Center(
                  child: Text(
                    ((fallbackLabel ?? '?').trim().isEmpty
                            ? '?'
                            : (fallbackLabel ?? '?').trim().characters.first)
                        .toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
