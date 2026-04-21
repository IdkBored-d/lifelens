import 'package:flutter/material.dart';
import 'package:lifelens/avatar_store.dart';
import 'package:lifelens/models/mini_me_companion.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.onGetStarted,
    this.ctaLabel = 'Build my baseline',
  });

  final VoidCallback onGetStarted;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.surface),
            Color.alphaBlend(cs.secondary.withValues(alpha: 0.1), cs.surface),
            cs.surface,
          ],
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your Mini-Me',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            const _CompanionCarousel(),
            const SizedBox(height: 16),
            const _MiniMePreviewPanel(),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(ctaLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionCarousel extends StatelessWidget {
  const _CompanionCarousel();

  @override
  Widget build(BuildContext context) {
    return Selector<AvatarStore, String>(
      selector: (_, store) => store.companionId,
      builder: (context, companionId, _) {
        final avatarStore = context.read<AvatarStore>();
        return SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: miniMeCompanionPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final companion = miniMeCompanionPresets[index];
              final selected = companion.id == companionId;
              return RepaintBoundary(
                child: _CompanionCard(
                  companion: companion,
                  selected: selected,
                  onTap: () => avatarStore.setCompanionId(companion.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MiniMePreviewPanel extends StatelessWidget {
  const _MiniMePreviewPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Selector<AvatarStore, _MiniMePreviewData>(
      selector: (_, store) => _MiniMePreviewData(
        companionId: store.companionId,
        companionName: store.selectedCompanion.name,
        accentColor: store.selectedCompanion.accentColor,
      ),
      builder: (context, data, _) {
        final theme = Theme.of(context);
        return RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.38),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hatch ${data.companionName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: _EggPreview(accentColor: data.accentColor),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.egg_alt_rounded),
                  label: const Text('Hatches after setup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniMePreviewData {
  const _MiniMePreviewData({
    required this.companionId,
    required this.companionName,
    required this.accentColor,
  });

  final String companionId;
  final String companionName;
  final Color accentColor;

  @override
  bool operator ==(Object other) {
    return other is _MiniMePreviewData &&
        other.companionId == companionId &&
        other.companionName == companionName &&
        other.accentColor == accentColor;
  }

  @override
  int get hashCode => Object.hash(companionId, companionName, accentColor);
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.companion,
    required this.selected,
    required this.onTap,
  });

  final MiniMeCompanionPreset companion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 154,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.88)
              : cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? companion.accentColor
                : cs.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: companion.accentColor.withValues(
                alpha: selected ? 0.16 : 0.07,
              ),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _EggPreview(
                accentColor: companion.accentColor,
                compact: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              companion.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: selected ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              companion.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected
                    ? cs.onPrimaryContainer.withValues(alpha: 0.78)
                    : cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EggPreview extends StatelessWidget {
  const _EggPreview({required this.accentColor, this.compact = false});

  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 74.0 : 110.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: size * 0.02,
            child: Container(
              width: size * 0.62,
              height: size * 0.12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ),
          ),
          Container(
            width: size * 0.68,
            height: size * 0.82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Color.alphaBlend(
                    accentColor.withValues(alpha: 0.24),
                    Colors.white,
                  ),
                ],
              ),
              border: Border.all(color: accentColor.withValues(alpha: 0.6)),
            ),
          ),
          Positioned(
            top: size * 0.27,
            child: Container(
              width: size * 0.2,
              height: size * 0.055,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: accentColor.withValues(alpha: 0.34),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.25,
            left: size * 0.26,
            right: size * 0.26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: size * 0.09,
                  height: size * 0.09,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: size * 0.09,
                  height: size * 0.09,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
