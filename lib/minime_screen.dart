import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';

String miniMeAssetForMood(String? moodLabel) {
  // map mood labels to the new emoji‑style 3D models
  String asset;
  switch (moodLabel) {
    case "Happy":
      asset = "assets/minime/emoji_happy.glb";
      break;
    case "Sad":
      asset = "assets/minime/emoji_sad.glb";
      break;
    case "Calm":
      asset = "assets/minime/emoji_calm.glb";
      break;
    case "Anxious":
    case "Stressed":
      asset = "assets/minime/emoji_anxious.glb";
      break;
    case "Energetic":
      // energetic doesn't have its own file yet; happy works well
      asset = "assets/minime/emoji_happy.glb";
      break;
    default:
      asset = "assets/minime/emoji_neutral.glb";
  }
  // log so we can see what's being chosen in debug console
  debugPrint('MiniMe asset for mood "$moodLabel": $asset');
  return asset;
}

class MiniMeScreen extends StatelessWidget {
  const MiniMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Mini-Me")),
      body: SafeArea(
        child: Consumer<MoodLogStore>(
          builder: (context, store, _) {
            final latest = store.items.isEmpty ? null : store.items.first;

            final moodLabel = latest?.moodLabel;
            final intensity = latest?.intensity ?? 0;
            final asset = miniMeAssetForMood(moodLabel);
            final glow = _glowForIntensity(cs, intensity);

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                // =========================
                // MINI-ME HERO
                // =========================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.45),
                    ),
                  ),
                  child: Column(
                    children: [
                      MiniMeAvatar(
                        key: ValueKey(asset),
                        modelAsset: asset,
                        glow: glow,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Your Mini-Me",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        latest == null
                            ? "Log a mood to help me understand you."
                            : "Today: ${latest.moodLabel} · ${latest.intensity}/5",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // =========================
                // QUICK ACTIONS
                // =========================
                _SectionHeader(
                  title: "Quick actions",
                  subtitle: "Log something in under 10 seconds.",
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionChip(icon: Icons.mood_rounded, label: "Mood"),
                    _ActionChip(icon: Icons.nightlight_round, label: "Sleep"),
                    _ActionChip(
                        icon: Icons.directions_run_rounded,
                        label: "Exercise"),
                    _ActionChip(icon: Icons.list_alt_rounded, label: "History"),
                  ],
                ),

                const SizedBox(height: 24),

                // =========================
                // INSIGHTS
                // =========================
                _SectionHeader(
                  title: "What I noticed",
                  subtitle: "Based on your recent check-ins.",
                ),
                const SizedBox(height: 10),

                if (latest == null)
                  _InsightCard(
                    icon: Icons.auto_awesome_rounded,
                    title: "Start with one check-in",
                    body:
                        "Once you log a few moods, I’ll begin spotting patterns.",
                  )
                else ...[
                  _InsightCard(
                    icon: Icons.timeline_rounded,
                    title: "Recent trend",
                    body: _recentTrendText(store),
                  ),
                  const SizedBox(height: 10),
                  _InsightCard(
                    icon: Icons.lightbulb_rounded,
                    title: "Suggestion",
                    body: _nextSuggestionText(latest),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
String _recentTrendText(MoodLogStore store) {
  final recent = store.items.take(5).toList();
  if (recent.length < 2) {
    return "Log a couple more check-ins to see trends.";
  }
  final mood = recent.first.moodLabel;
  return "In your last ${recent.length} check-ins, you logged “$mood” most recently.";
}

String _nextSuggestionText(dynamic latest) {
  if (latest == null) return "Try logging a mood.";

  if (latest.moodLabel == "Anxious" && latest.intensity >= 4) {
    return "Try a 30-second reset: inhale 4s, exhale 6s.";
  }

  if (latest.moodLabel == "Sad") {
    return "If you can, add a short note about what happened today.";
  }

  return "Want to log sleep or exercise next? Those often connect to mood.";
}

Color _glowForIntensity(ColorScheme cs, int intensity) {
  if (intensity <= 1) return cs.primary.withOpacity(0.18);
  if (intensity == 2) return cs.primary.withOpacity(0.26);
  if (intensity == 3) return cs.primary.withOpacity(0.34);
  if (intensity == 4) return cs.primary.withOpacity(0.42);
  return cs.primary.withOpacity(0.5);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
