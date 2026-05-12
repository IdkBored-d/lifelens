import 'package:flutter/material.dart';
import 'package:lifelens/shared_widgets/pill.dart';
import 'package:lifelens/shared_widgets/soft_icon_button.dart';

class MiniMeHeroCard extends StatelessWidget {
  const MiniMeHeroCard({
    super.key,
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
    final isLight = cs.brightness == Brightness.light;

    final Color stateColor = _stateColorFromMood(moodLabel, cs);
    final titleColor = isLight ? Colors.white : cs.onSurface;
    final bodyColor = isLight
        ? Colors.white.withValues(alpha: 0.78)
        : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isLight
                ? const Color(0xFF3730A3)
                : cs.primaryContainer.withValues(alpha: 0.55),
            isLight
                ? const Color(0xFF0F766E)
                : cs.secondaryContainer.withValues(alpha: 0.45),
            isLight ? const Color(0xFF111827) : cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.transparent,
          width: isLight ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.20 : 0.04),
            blurRadius: isLight ? 30 : 12,
            offset: Offset(0, isLight ? 16 : 8),
          ),
          if (isLight)
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.18),
              blurRadius: 34,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Stack(
        children: [
          if (isLight)
            Positioned(
              right: -34,
              top: -42,
              child: IgnorePointer(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              // Mini-Me placeholder (swap for ModelViewer later)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLight ? Colors.white : stateColor,
                  boxShadow: [
                    BoxShadow(
                      color: (isLight ? Colors.black : stateColor).withValues(
                        alpha: isLight ? 0.24 : 0.28,
                      ),
                      blurRadius: isLight ? 24 : 12,
                      spreadRadius: isLight ? 0 : 1,
                      offset: Offset(0, isLight ? 10 : 0),
                    ),
                  ],
                ),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isLight
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              stateColor.withValues(alpha: 0.26),
                              Colors.white,
                            ],
                          )
                        : null,
                    color: isLight ? null : cs.surface,
                    border: Border.all(
                      color: isLight
                          ? Colors.white.withValues(alpha: 0.95)
                          : cs.outlineVariant.withValues(alpha: 0.55),
                      width: isLight ? 2.2 : 1,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: isLight ? const Color(0xFF312E81) : cs.primary,
                  ),
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
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      moodLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: bodyColor,
                        fontWeight: isLight ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill(text: statusLine, icon: Icons.bolt_rounded),
                        Pill(
                          text: "Sync: Ready",
                          icon: Icons.cloud_done_outlined,
                        ),
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
        ],
      ),
    );
  }

  Color _stateColorFromMood(String moodLabel, ColorScheme cs) {
    final m = moodLabel.toLowerCase();

    if (m.contains("happy") || m.contains("joy")) return Colors.greenAccent;
    if (m.contains("affectionate") || m.contains("love"))
      return const Color(0xFFFF9DB3);
    if (m.contains("sad")) return Colors.redAccent;
    if (m.contains("angry") || m.contains("anger"))
      return const Color(0xFFFF8A65);
    if (m.contains("scared") || m.contains("fear") || m.contains("anxious")) {
      return Colors.orangeAccent;
    }
    if (m.contains("surprised") || m.contains("surprise")) {
      return const Color(0xFFFFD166);
    }
    if (m.contains("neutral")) return Color(0xFF8C91A8);

    return cs.primary;
  }
}
