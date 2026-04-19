import 'package:flutter/material.dart';
import 'package:lifelens/avatar_store.dart';
import 'package:lifelens/shared_widgets/mini_me_avatar_badge.dart';
import 'package:provider/provider.dart';

class MiniMeProfileIcon extends StatelessWidget {
  const MiniMeProfileIcon({
    super.key,
    this.size = 40,
    this.padding = 4,
    this.backgroundColor,
    this.borderColor,
  });

  final double size;
  final double padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final iconData = context.select<AvatarStore, _MiniMeProfileIconData>(
      (avatarStore) => _MiniMeProfileIconData.fromStore(avatarStore),
    );

    return MiniMeAvatarBadge(
      size: size,
      padding: padding,
      backgroundColor: backgroundColor ?? cs.primaryContainer,
      borderColor: borderColor ?? cs.outlineVariant.withValues(alpha: 0.45),
      bodyModel: iconData.bodyModel,
      hairModel: iconData.hairModel,
      shirtModel: iconData.shirtModel,
      bodyWidthScale: iconData.bodyWidthScale,
      companionId: iconData.companionId,
      isHatched: iconData.isHatched,
      degradationLevel: iconData.degradationLevel,
      fallbackLabel: iconData.fallbackLabel,
    );
  }
}

class _MiniMeProfileIconData {
  const _MiniMeProfileIconData({
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    required this.companionId,
    required this.isHatched,
    required this.degradationLevel,
    required this.fallbackLabel,
  });

  factory _MiniMeProfileIconData.fromStore(AvatarStore avatarStore) {
    return _MiniMeProfileIconData(
      bodyModel: avatarStore.bodyModel,
      hairModel: avatarStore.hairModel,
      shirtModel: avatarStore.shirtModel,
      bodyWidthScale: avatarStore.effectiveBodyWidthScale,
      companionId: avatarStore.companionId,
      isHatched: avatarStore.isMiniMeHatched,
      degradationLevel: avatarStore.degradationLevel,
      fallbackLabel: avatarStore.miniMeName,
    );
  }

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String companionId;
  final bool isHatched;
  final double degradationLevel;
  final String fallbackLabel;

  @override
  bool operator ==(Object other) {
    return other is _MiniMeProfileIconData &&
        other.bodyModel == bodyModel &&
        other.hairModel == hairModel &&
        other.shirtModel == shirtModel &&
        other.bodyWidthScale == bodyWidthScale &&
        other.companionId == companionId &&
        other.isHatched == isHatched &&
        other.degradationLevel == degradationLevel &&
        other.fallbackLabel == fallbackLabel;
  }

  @override
  int get hashCode => Object.hash(
    bodyModel,
    hairModel,
    shirtModel,
    bodyWidthScale,
    companionId,
    isHatched,
    degradationLevel,
    fallbackLabel,
  );
}
