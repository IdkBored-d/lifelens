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

    return Consumer<AvatarStore>(
      builder: (context, avatarStore, _) {
        return MiniMeAvatarBadge(
          size: size,
          padding: padding,
          backgroundColor: backgroundColor ?? cs.primaryContainer,
          borderColor: borderColor ?? cs.outlineVariant.withValues(alpha: 0.45),
          bodyModel: avatarStore.bodyModel,
          hairModel: avatarStore.hairModel,
          shirtModel: avatarStore.shirtModel,
          bodyWidthScale: avatarStore.bodyWidthScale,
          companionId: avatarStore.companionId,
          isHatched: avatarStore.isMiniMeHatched,
          degradationLevel: avatarStore.degradationLevel,
          fallbackLabel: avatarStore.miniMeName,
        );
      },
    );
  }
}
