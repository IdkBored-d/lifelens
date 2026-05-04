import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/assets/minime/minime_avatar.dart';
import 'package:lifelens/avatar_store.dart';
import 'package:lifelens/services/mood_log_draft_storage_service.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'package:lifelens/moodlog_store.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'package:lifelens/sleep_store.dart';
import 'package:lifelens/shared_widgets/log_button_content.dart';
import 'package:lifelens/services/symptom_auto_detector_service.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';
import 'package:provider/provider.dart';

enum LogSource { quickAction, tab }

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class MoodLogScreen extends StatefulWidget {
  const MoodLogScreen({super.key, this.source = LogSource.quickAction});
  final LogSource source;

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen> {
  int selectedMood = -1;
  int intensity = 3;
  LogButtonVisualState _buttonState = LogButtonVisualState.idle;
  final notesCtrl = TextEditingController();
  final Set<String> tags = {};
  bool _restoringDraft = true;
  bool _showPreviousLogs = false;

  final moods = const [
    _MoodOption("Neutral", "😐"),
    _MoodOption("Angry", "😠"),
    _MoodOption("Scared", "😨"),
    _MoodOption("Happy", "😊"),
    _MoodOption("Affectionate", "🥰"),
    _MoodOption("Sad", "😔"),
    _MoodOption("Surprised", "😲"),
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
    "Partner",
    "Finances",
    "Hobby",
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
        intensity = draft.intensity;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);
    final avatarSelection = context.select<AvatarStore, _MoodAvatarSelection>(
      (avatarStore) => _MoodAvatarSelection.fromStore(avatarStore),
    );

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

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final faceSize = width >= 420 ? 82.0 : 74.0;

                          if (width < 360) {
                            return Column(
                              children: [
                                for (
                                  var rowStart = 0;
                                  rowStart < moods.length;
                                  rowStart += 2
                                )
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: rowStart + 2 < moods.length
                                          ? 18
                                          : 0,
                                    ),
                                    child: Row(
                                      children: [
                                        for (
                                          var column = 0;
                                          column < 2;
                                          column++
                                        )
                                          Expanded(
                                            child:
                                                column + rowStart < moods.length
                                                ? Padding(
                                                    padding: EdgeInsets.only(
                                                      right: column == 0
                                                          ? 10
                                                          : 0,
                                                      left: column == 1
                                                          ? 10
                                                          : 0,
                                                    ),
                                                    child: _MoodTile(
                                                      option:
                                                          moods[rowStart +
                                                              column],
                                                      isSelected:
                                                          rowStart + column ==
                                                          selectedMood,
                                                      faceSize: faceSize,
                                                      avatarSelection:
                                                          avatarSelection,
                                                      onTap: () {
                                                        Feedback.forTap(
                                                          context,
                                                        );
                                                        setState(
                                                          () => selectedMood =
                                                              rowStart + column,
                                                        );
                                                        _persistDraft();
                                                      },
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          }

                          final topRow = moods.take(4).toList(growable: false);
                          final bottomRow = moods
                              .skip(4)
                              .toList(growable: false);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    for (var i = 0; i < topRow.length; i++)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: i < topRow.length - 1
                                                ? 16
                                                : 0,
                                          ),
                                          child: _MoodTile(
                                            option: topRow[i],
                                            isSelected: i == selectedMood,
                                            faceSize: faceSize,
                                            avatarSelection: avatarSelection,
                                            onTap: () {
                                              Feedback.forTap(context);
                                              setState(() => selectedMood = i);
                                              _persistDraft();
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < bottomRow.length;
                                      i++
                                    ) ...[
                                      Flexible(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 110,
                                          ),
                                          child: _MoodTile(
                                            option: bottomRow[i],
                                            isSelected: i + 4 == selectedMood,
                                            faceSize: faceSize,
                                            avatarSelection: avatarSelection,
                                            onTap: () {
                                              Feedback.forTap(context);
                                              setState(
                                                () => selectedMood = i + 4,
                                              );
                                              _persistDraft();
                                            },
                                          ),
                                        ),
                                      ),
                                      if (i < bottomRow.length - 1)
                                        const SizedBox(width: 20),
                                    ],
                                  ],
                                ),
                              ],
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
                        trailing: '$intensity/5',
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          showValueIndicator: ShowValueIndicator.onDrag,
                        ),
                        child: Slider(
                          value: intensity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$intensity/5',
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => intensity = value.round());
                            _persistDraft();
                          },
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Low',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'High',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(
                            () => _showPreviousLogs = !_showPreviousLogs,
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _showPreviousLogs
                                    ? 'Hide previous logs'
                                    : 'View previous logs',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(
                              _showPreviousLogs
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      if (_showPreviousLogs) ...[
                        const SizedBox(height: 12),
                        const _PreviousMoodLogsSection(),
                      ],
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

                            // Compose log text: notes are primary, tags appended for context.
                            final tagPart = tags.isNotEmpty
                                ? ' [context: ${tags.join(', ')}]'
                                : '';
                            final userLog =
                                '${notes.isNotEmpty ? notes : m.label}$tagPart';

                            try {
                              final now = DateTime.now();
                              final persistedSummary = notes.isEmpty
                                  ? '${m.label} ($intensity/5)'
                                  : '$notes ($intensity/5)';
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
                              if (context.mounted) {
                                final moodStore = context.read<MoodLogStore>();
                                moodStore.add(
                                  MoodCheckIn(
                                    moodLabel: m.label,
                                    emoji: m.emoji,
                                    intensity: intensity,
                                    tags: tags.toList(growable: false),
                                    notes: notes,
                                    createdAt: now,
                                  ),
                                );
                                unawaited(
                                  context
                                      .read<MiniMeSuggestionsInbox>()
                                      .refresh(
                                        moodStore: moodStore,
                                        sleepStore: context.read<SleepStore>(),
                                      ),
                                );
                              }
                              await TrackingReminderService.instance
                                  .handleLogRecorded();
                              try {
                                await _syncMoodToCloud(
                                  entry: moodEntry,
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
                                intensity = 3;
                                notesCtrl.clear();
                                tags.clear();
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

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.option,
    required this.isSelected,
    required this.faceSize,
    required this.avatarSelection,
    required this.onTap,
  });

  final _MoodOption option;
  final bool isSelected;
  final double faceSize;
  final _MoodAvatarSelection avatarSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: isSelected
            ? (Matrix4.identity()..scaleByDouble(1.03, 1.03, 1.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.40)
                : cs.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: faceSize + 10,
                child: Center(
                  child: _AnimatedMoodMiniMeFace(
                    bodyModel: avatarSelection.bodyModel,
                    hairModel: avatarSelection.hairModel,
                    shirtModel: avatarSelection.shirtModel,
                    bodyWidthScale: avatarSelection.bodyWidthScale,
                    companionId: avatarSelection.companionId,
                    moodLabel: option.label,
                    degradationLevel: avatarSelection.degradationLevel,
                    isSelected: isSelected,
                    size: faceSize,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviousMoodLogsSection extends StatelessWidget {
  const _PreviousMoodLogsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatarSelection = context.select<AvatarStore, _MoodAvatarSelection>(
      (avatarStore) => _MoodAvatarSelection.fromStore(avatarStore),
    );
    final historySelection = context
        .select<MoodLogStore, _MoodHistorySelection>(
          (moodStore) => _MoodHistorySelection.fromStore(moodStore),
        );

    if (historySelection.isLoading) {
      return const LinearProgressIndicator(minHeight: 3);
    }

    if (historySelection.items.isEmpty) {
      return Text(
        'No mood logs yet. Save one above and it will show up here.',
        style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Column(
      children: historySelection.items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PreviousMoodLogCard(
                item: item,
                avatarSelection: avatarSelection,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PreviousMoodLogCard extends StatelessWidget {
  const _PreviousMoodLogCard({
    required this.item,
    required this.avatarSelection,
  });

  final MoodCheckIn item;
  final _MoodAvatarSelection avatarSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: MiniMePortraitAvatar(
                  bodyModel: avatarSelection.bodyModel,
                  hairModel: avatarSelection.hairModel,
                  shirtModel: avatarSelection.shirtModel,
                  bodyWidthScale: avatarSelection.bodyWidthScale,
                  companionId: avatarSelection.companionId,
                  moodLabel: item.moodLabel,
                  degradationLevel: avatarSelection.degradationLevel,
                  size: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.moodLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (item.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.notes,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodAvatarSelection {
  const _MoodAvatarSelection({
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    required this.companionId,
    required this.degradationLevel,
  });

  factory _MoodAvatarSelection.fromStore(AvatarStore avatarStore) {
    return _MoodAvatarSelection(
      bodyModel: avatarStore.bodyModel,
      hairModel: avatarStore.hairModel,
      shirtModel: avatarStore.shirtModel,
      bodyWidthScale: avatarStore.effectiveBodyWidthScale,
      companionId: avatarStore.companionId,
      degradationLevel: avatarStore.degradationLevel,
    );
  }

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String companionId;
  final double degradationLevel;

  @override
  bool operator ==(Object other) {
    return other is _MoodAvatarSelection &&
        other.bodyModel == bodyModel &&
        other.hairModel == hairModel &&
        other.shirtModel == shirtModel &&
        other.bodyWidthScale == bodyWidthScale &&
        other.companionId == companionId &&
        other.degradationLevel == degradationLevel;
  }

  @override
  int get hashCode => Object.hash(
    bodyModel,
    hairModel,
    shirtModel,
    bodyWidthScale,
    companionId,
    degradationLevel,
  );
}

class _MoodHistorySelection {
  const _MoodHistorySelection({
    required this.isLoading,
    required this.items,
    required this.signature,
  });

  factory _MoodHistorySelection.fromStore(MoodLogStore moodStore) {
    final today = DateTime.now();
    final items = moodStore.items
        .where((item) => _isSameDay(item.createdAt, today))
        .take(10)
        .toList(growable: false);
    final signature = items
        .map(
          (item) =>
              '${item.createdAt.microsecondsSinceEpoch}:${item.moodLabel}:${item.intensity}:${item.notes}',
        )
        .join('|');
    return _MoodHistorySelection(
      isLoading: moodStore.isLoading,
      items: items,
      signature:
          '${moodStore.isLoading}::${moodStore.items.length}::$signature',
    );
  }

  final bool isLoading;
  final List<MoodCheckIn> items;
  final String signature;

  @override
  bool operator ==(Object other) =>
      other is _MoodHistorySelection &&
      other.isLoading == isLoading &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(isLoading, signature);
}

class _AnimatedMoodMiniMeFace extends StatefulWidget {
  const _AnimatedMoodMiniMeFace({
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    required this.companionId,
    required this.moodLabel,
    required this.degradationLevel,
    required this.isSelected,
    required this.size,
  });

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String companionId;
  final String moodLabel;
  final double degradationLevel;
  final bool isSelected;
  final double size;

  @override
  State<_AnimatedMoodMiniMeFace> createState() =>
      _AnimatedMoodMiniMeFaceState();
}

class _AnimatedMoodMiniMeFaceState extends State<_AnimatedMoodMiniMeFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phaseOffset = _blinkPhaseForMood(widget.moodLabel);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final blink = _blinkValue(_controller.value, phaseOffset);
        final scale = widget.isSelected ? 1.06 : 1.0;

        return Transform.scale(
          scale: scale,
          child: MiniMePortraitAvatar(
            bodyModel: widget.bodyModel,
            hairModel: widget.hairModel,
            shirtModel: widget.shirtModel,
            bodyWidthScale: widget.bodyWidthScale,
            companionId: widget.companionId,
            moodLabel: widget.moodLabel,
            size: widget.size,
            blink: blink,
            degradationLevel: widget.degradationLevel,
            visualState: const MiniMeVisualState(),
          ),
        );
      },
    );
  }
}

double _blinkPhaseForMood(String moodLabel) {
  final normalized = moodLabel.trim().toLowerCase();
  return (normalized.hashCode.abs() % 100) / 100.0;
}

double _blinkValue(double progress, double phaseOffset) {
  final phased = (progress + phaseOffset) % 1.0;
  final firstBlink = _blinkPulse(phased, 0.18, 0.08);
  final secondBlink = _blinkPulse(phased, 0.62, 0.06);
  return math.max(firstBlink, secondBlink).clamp(0.0, 1.0);
}

double _blinkPulse(double progress, double center, double width) {
  final distance = (progress - center).abs();
  if (distance > width) return 0;
  final normalized = 1 - (distance / width);
  return Curves.easeInOut.transform(normalized);
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
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
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
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
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
                    color: cs.outlineVariant.withValues(alpha: 0.45),
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
