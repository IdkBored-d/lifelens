import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'moodlog_store.dart';

enum LogSource { quickAction, tab }

class MoodLogScreen extends StatefulWidget {
  const MoodLogScreen({super.key, this.source = LogSource.quickAction});
  final LogSource source;

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen> {
  int selectedMood = -1;
  double intensity = 3;
  final notesCtrl = TextEditingController();
  final Set<String> tags = {};

  final moods = const [
    _MoodOption("Happy", "😊"),
    _MoodOption("Calm", "😌"),
    _MoodOption("Neutral", "😐"),
    _MoodOption("Anxious", "😟"),
    _MoodOption("Sad", "😔"),
  ];

  final tagOptions = const [
    "School",
    "Work",
    "Sleep",
    "Social",
    "Exercise",
    "Food",
    "Family",
    "Health",
  ];

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  String get intensityLabel {
    if (intensity <= 2) return "Low";
    if (intensity <= 4) return "Moderate";
    return "High";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Mood Log")),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How do you feel right now?",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "A quick check-in helps your Mini-Me learn important patterns over time.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: "Mood",
                        trailing: selectedMood == -1
                            ? "Select one"
                            : moods[selectedMood].label,
                      ),
                      const SizedBox(height: 12),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: moods.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemBuilder: (context, i) {
                          final m = moods[i];
                          final isSelected = i == selectedMood;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Feedback.forTap(context);
                              setState(() => selectedMood = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              transform: isSelected
                                  ? (Matrix4.identity()..scale(1.05))
                                  : Matrix4.identity(),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primaryContainer
                                    : cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary.withOpacity(0.40)
                                      : cs.outlineVariant.withOpacity(0.55),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: "Intensity",
                        trailing: "$intensityLabel · ${intensity.toInt()}/5",
                      ),
                      Slider(
                        value: intensity,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        onChanged: (v) => setState(() => intensity = v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("1", style: theme.textTheme.labelMedium),
                          Text("5", style: theme.textTheme.labelMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: "Context (optional)"),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tagOptions.map((t) {
                          final selected = tags.contains(t);
                          return FilterChip(
                            selected: selected,
                            label: Text(t),
                            onSelected: (v) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (v) {
                                  tags.add(t);
                                } else {
                                  tags.remove(t);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(title: "Notes (optional)"),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: "Anything you want to remember?",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (widget.source == LogSource.tab) ...[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: "Recent check-ins"),
                        const SizedBox(height: 10),

                        Consumer<MoodLogStore>(
                          builder: (context, store, _) {
                            if (store.items.isEmpty) {
                              return Text(
                                "No check-ins yet. Log one above to get started.",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              );
                            }
                            final recent = store.items.take(5).toList();

                            return Column(
                              children: recent.map((it) {
                                final tagText = it.tags.isEmpty
                                    ? "No tags"
                                    : it.tags.take(2).join(" · ");

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _RecentCheckInRow(
                                    emoji: it.emoji,
                                    title: it.moodLabel,
                                    subtitle: "${it.intensity}/5 · $tagText",
                                    notes: it.notes,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedMood == -1
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();

                            final store = context.read<MoodLogStore>();
                            final m = moods[selectedMood];

                            store.add(
                              MoodCheckIn(
                                moodLabel: m.label,
                                emoji: m.emoji,
                                intensity: intensity.toInt(),
                                tags: tags.toList(),
                                notes: notesCtrl.text.trim(),
                                createdAt: DateTime.now(),
                              ),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Mood saved (UI Only)"),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(milliseconds: 900),
                              ),
                            );
                            if (widget.source == LogSource.quickAction) {
                              Navigator.of(context).pop();
                            } else {
                              setState(() {
                                selectedMood = -1;
                                notesCtrl.clear();
                                tags.clear();
                                intensity = 3;
                              });
                            }
                          },
                    child: Text(
                      widget.source == LogSource.tab
                          ? "Save and log another time"
                          : "Save check-in",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodOption {
  const _MoodOption(this.label, this.emoji);
  final String label;
  final String emoji;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _RecentCheckInRow extends StatefulWidget {
  const _RecentCheckInRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.notes,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final String notes;

  @override
  State<_RecentCheckInRow> createState() => _RecentCheckInRowState();
}

class _RecentCheckInRowState extends State<_RecentCheckInRow> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasNotes = widget.notes.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: hasNotes ? () => setState(() => expanded = !expanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasNotes)
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),

            if (hasNotes && expanded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(0.45),
                  ),
                ),
                child: Text(
                  widget.notes,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
