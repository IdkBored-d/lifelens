import 'package:flutter/material.dart';
import 'package:lifelens/shared_widgets/pill.dart';
import 'package:lifelens/shared_widgets/soft_icon_button.dart';

class MiniMeHeroCard extends StatelessWidget {
  const MiniMeHeroCard({
    required this.title,
    required this.moodLabel,
    required this.statusLine,
  });

  final String title;
  final String moodLabel;
  final String statusLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color stateColor = _stateColorFromMood(moodLabel, cs);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.55),
            cs.secondaryContainer.withOpacity(0.45),
            cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mini-Me placeholder (swap for ModelViewer later)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stateColor,
              boxShadow: [
                BoxShadow(
                  color: stateColor.withOpacity(0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: Icon(Icons.person_rounded, size: 44, color: cs.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  moodLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(text: statusLine, icon: Icons.bolt_rounded),
                    Pill(text: "Sync: Ready", icon: Icons.cloud_done_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SoftIconButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mini-Me details (UI only)"),
                behavior: SnackBarBehavior.floating,
                duration: Duration(milliseconds: 900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _stateColorFromMood(String moodLabel, ColorScheme cs) {
    final m = moodLabel.toLowerCase();

    if (m.contains("calm")) return Color(0xFFb4A6E6);
    if (m.contains("happy") || m.contains("joy")) return Colors.greenAccent;
    if (m.contains("sad")) return Colors.redAccent;
    if (m.contains("neutral")) return Color(0xFF8C91A8);
    if (m.contains("anxious") || m.contains("stress"))
      return Colors.orangeAccent;

    return cs.primary;
  }
}