import 'dart:async' show unawaited;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/services/mood_log_draft_storage_service.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/shared_widgets/log_button_content.dart';
import 'package:lifelens/services/symptom_auto_detector_service.dart';
import 'package:provider/provider.dart';

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
  LogButtonVisualState _buttonState = LogButtonVisualState.idle;
  final notesCtrl = TextEditingController();
  final Set<String> tags = {};
  bool _restoringDraft = true;

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
  void initState() {
    super.initState();
    notesCtrl.addListener(_persistDraft);
    _restoreDraft();
  }

  @override
  void dispose() {
    notesCtrl.removeListener(_persistDraft);
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await MoodLogDraftStorageService.instance.load();
    if (!mounted) return;

    if (draft != null && draft.hasContent) {
      setState(() {
        selectedMood = draft.selectedMood;
        intensity = draft.intensity.clamp(1, 5);
        notesCtrl.text = draft.notes;
        tags
          ..clear()
          ..addAll(draft.tags);
        _restoringDraft = false;
      });
      return;
    }

    setState(() => _restoringDraft = false);
  }

  Future<void> _persistDraft() {
    if (_restoringDraft) {
      return Future.value();
    }

    return MoodLogDraftStorageService.instance.save(
      MoodLogDraft(
        selectedMood: selectedMood,
        intensity: intensity,
        notes: notesCtrl.text.trim(),
        tags: tags.toList(growable: false),
      ),
    );
  }

  Future<void> _clearDraft() async {
    await MoodLogDraftStorageService.instance.clear();
  }

  String get intensityLabel {
    switch (intensity.toInt()) {
      case 1:
        return "Very low";
      case 2:
        return "Low";
      case 3:
        return "Moderate";
      case 4:
        return "High";
      default:
        return "Very high";
    }
  }

  String moodHint(String label) {
    switch (label) {
      case "Happy":
        return "Capture what's going well right now.";
      case "Calm":
        return "Maintain that calm aura";
      case "Anxious":
        return "Noticing anxiety helps identify triggers.";
      case "Sad":
        return "Thank you for checking in - this matters.";
      default:
        return "A quick check-in helps over time.";
    }
  }

  BoxShadow intensityGlow(ColorScheme cs) {
    final t = (intensity - 1) / 4;

    return BoxShadow(
      color: cs.primary.withValues(alpha:0.20 + t * 0.45),
      blurRadius: 10 + t * 18,
      spreadRadius: 1 + t * 2.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text("Mood Log"),
        actions: [
          IconButton(
            tooltip: 'Clear draft',
            onPressed: () async {
              setState(() {
                selectedMood = -1;
                intensity = 3;
                notesCtrl.clear();
                tags.clear();
              });
              await _clearDraft();
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
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
                if (!_restoringDraft &&
                    (selectedMood != -1 ||
                        notesCtrl.text.trim().isNotEmpty ||
                        tags.isNotEmpty ||
                        intensity != 3)) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Draft saved automatically",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
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
                              _persistDraft();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              transform: isSelected
                                  ? (Matrix4.diagonal3Values(1.05, 1.05, 1.0))
                                  : Matrix4.identity(),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primaryContainer
                                    : cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary.withValues(alpha:0.40)
                                      : cs.outlineVariant.withValues(alpha:0.55),
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

                if (selectedMood != -1) ...[
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha:0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            moodHint(moods[selectedMood].label),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: "Intensity",
                        trailing: "$intensityLabel · ${intensity.toInt()}/5",
                      ),
                      const SizedBox(height: 8),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [intensityGlow(cs)],
                        ),
                        child: Text(
                          intensityLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),

                      Slider(
                        value: intensity,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => intensity = v);
                          _persistDraft();
                        },
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
                              _persistDraft();
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

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        (selectedMood == -1 ||
                            _buttonState == LogButtonVisualState.loading)
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            setState(
                              () => _buttonState = LogButtonVisualState.loading,
                            );
                            String? syncWarning;

                            final m = moods[selectedMood];
                            final notes = notesCtrl.text.trim();

                            // Compose log text: notes are primary, tags + intensity appended for ML context.
                            final tagPart = tags.isNotEmpty
                                ? ' [context: ${tags.join(', ')}]'
                                : '';
                            final userLog =
                                '${notes.isNotEmpty ? notes : m.label}$tagPart [intensity: ${intensity.toInt()}/5]';

                            final moodLogStore = context.read<MoodLogStore>();
                            try {
                              final now = DateTime.now();
                              final persistedSummary = notes.isEmpty
                                  ? 'Intensity ${intensity.toInt()}/5'
                                  : 'Intensity ${intensity.toInt()}/5 · $notes';
                              final moodEntry = MoodEntry()
                                ..date = now.toIso8601String().substring(0, 10)
                                ..rawLog = userLog
                                ..condensedLog = persistedSummary
                                ..resolvedMood = m.label
                                ..resolvedBy = "user"
                                ..mobileBertPrediction = null
                                ..mobileBertTopProb = null
                                ..userConfirmed = null
                                ..responseText = ""
                                ..fitnessScoreSnapshot = 0.0
                                ..timestamp = now;
                              await IsarService.instance.init();
                              await IsarService.instance.writeMoodEntry(
                                moodEntry,
                              );
                              if (!mounted) return;
                              moodLogStore.add(
                                MoodCheckIn(
                                  moodLabel: m.label,
                                  emoji: m.emoji,
                                  intensity: intensity.toInt(),
                                  tags: tags.toList(growable: false),
                                  notes: notes,
                                  createdAt: now,
                                ),
                              );
                              try {
                                await _syncMoodToCloud(
                                  entry: moodEntry,
                                  intensityValue: intensity.toInt(),
                                  selectedTags: tags.toList(growable: false),
                                );
                              } catch (_) {
                                syncWarning =
                                    'Saved on this device. Cloud sync failed for this mood log.';
                              }

                              // Auto-detect and register symptoms from user notes
                              unawaited(
                                SymptomAutoDetectorService.autoRegisterDetectedSymptoms(
                                  userLog,
                                  'mood_log',
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not save mood log: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              setState(
                                () => _buttonState = LogButtonVisualState.idle,
                              );
                              return;
                            }

                            await _clearDraft();

                            if (!context.mounted) return;
                            setState(
                              () => _buttonState = LogButtonVisualState.success,
                            );
                            if (syncWarning != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(syncWarning),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            await Future<void>.delayed(
                              const Duration(milliseconds: 800),
                            );
                            if (!context.mounted) return;
                            if (widget.source == LogSource.quickAction) {
                              Navigator.of(context).pop();
                            } else {
                              setState(() {
                                selectedMood = -1;
                                notesCtrl.clear();
                                tags.clear();
                                intensity = 3;
                                _restoringDraft = false;
                                _buttonState = LogButtonVisualState.idle;
                              });
                            }
                          },
                    child: LogButtonContent(
                      state: _buttonState,
                      idleLabel: widget.source == LogSource.tab
                          ? "Save and log another time"
                          : "Save check-in",
                      loadingLabel: 'Saving check-in',
                      successLabel: 'Saved',
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

  Future<void> _syncMoodToCloud({
    required MoodEntry entry,
    required int intensityValue,
    required List<String> selectedTags,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('mood_logs')
        .add({
          'date': entry.date,
          'rawLog': entry.rawLog,
          'condensedLog': entry.condensedLog,
          'resolvedMood': entry.resolvedMood,
          'resolvedBy': entry.resolvedBy,
          'mobileBertPrediction': entry.mobileBertPrediction,
          'mobileBertTopProb': entry.mobileBertTopProb,
          'userConfirmed': entry.userConfirmed,
          'responseText': entry.responseText,
          'fitnessScoreSnapshot': entry.fitnessScoreSnapshot,
          'intensity': intensityValue,
          'tags': selectedTags,
          'createdAt': Timestamp.fromDate(entry.timestamp),
        });
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
        border: Border.all(color: cs.outlineVariant.withValues(alpha:0.45)),
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
          border: Border.all(color: cs.outlineVariant.withValues(alpha:0.45)),
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
                    color: cs.outlineVariant.withValues(alpha:0.45),
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
