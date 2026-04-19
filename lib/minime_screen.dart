import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;
import 'package:provider/provider.dart';
import 'package:lifelens/app_services.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';
import 'package:lifelens/utils/minime_helpers.dart';
import 'package:lifelens/services/streak_service.dart';
import 'package:lifelens/services/minime_backend_service.dart';
import 'package:lifelens/services/chat_session_service.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/services/mini_me_suggestions_inbox.dart';
import 'package:lifelens/models/sleep.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/chat_message.dart';
import 'package:lifelens/database/fitness_entry.dart';
import 'avatar_store.dart';
import 'avatar_customization_screen.dart';
import 'sleep_store.dart';

class MiniMeScreen extends StatefulWidget {
  const MiniMeScreen({super.key, required this.userName, this.isActive = true});

  final String userName;
  final bool isActive;

  @override
  State<MiniMeScreen> createState() => _MiniMeScreenState();
}

class _MiniMeScreenState extends State<MiniMeScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  bool _didLoadOpeningSuggestion = false;
  bool _isSurfacingUnreadSuggestions = false;
  bool _isCoachExpanded = false;
  bool _isReplying = false;
  bool _isIntelligenceLoading = false;
  String? _dailyLoggingPromptText;
  final List<_MiniMeChatMessage> _messages = [];
  String? _latestAssistantMessageText;
  MiniMeIntelligenceReply? _intelligence;
  final ExerciseStore _exerciseStore = ExerciseStore();
  int _activeSymptomCount = 0;
  String? _derivedUiSignature;
  _MiniMeDerivedUiState? _derivedUiState;

  // Chat session persistence (ISAR-backed, replaces flat-file MiniMeChatStorageService)
  String? _sessionId;
  int _messageSequence = 0;
  int _avatarWaveToken = 1;
  late final ChatSessionService _chatSessionService;

  @override
  void initState() {
    super.initState();
    _chatSessionService = ChatSessionService(
      AppServices.quickTrack,
      AppServices.gemma,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Intelligence loads first — drives opening message + avatar mood.
      // 3-second timeout so a slow/offline backend doesn't block the screen.
      await _refreshIntelligence().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
      if (!mounted) return;
      await _refreshStartLoggingPromptState();
      if (!mounted) return;
      final moodStore = context.read<MoodLogStore>();
      final moodCtx = _buildMoodContext(moodStore);
      _sessionId = await _chatSessionService.startSession(
        moodLabel: moodCtx.label,
        moodIntensity: moodCtx.intensity,
        moodNotes: moodCtx.notes.isEmpty ? null : moodCtx.notes,
      );
      _bootstrapMiniMe();
    });
  }

  @override
  void dispose() {
    if (_sessionId != null) _chatSessionService.endSession(_sessionId!);
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MiniMeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      setState(() => _avatarWaveToken += 1);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _syncUnreadSuggestions(forceRefresh: true);
      });
    }
  }

  void _appendMessage(_MiniMeChatMessage message) {
    _messages.add(message);
    if (message.role == _ChatRole.assistant) {
      final trimmed = message.text.trim();
      if (trimmed.isNotEmpty) {
        _latestAssistantMessageText = trimmed;
      }
    }
  }

  void _replaceMessages(Iterable<_MiniMeChatMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);

    _latestAssistantMessageText = null;
    for (final message in _messages.reversed) {
      if (message.role != _ChatRole.assistant) continue;
      final trimmed = message.text.trim();
      if (trimmed.isEmpty) continue;
      _latestAssistantMessageText = trimmed;
      break;
    }
  }

  // ignore: unused_element
  Future<void> _runDaySummary() async {
    if (_isReplying) return;

    setState(() {
      _isCoachExpanded = true;
      _isReplying = true;
      _appendMessage(
        const _MiniMeChatMessage(
          role: _ChatRole.user,
          text: 'Generate my day summary',
        ),
      );
    });
    _scrollToBottom();

    try {
      // TODO: replace `true` with a real connectivity check (connectivity_plus).
      final result = await AppServices.eodPipeline.runEndOfDay(
        isOnline: await AppServices.isOnline(),
      );

      if (!mounted) return;

      final flagNote =
          result.flagged && (result.flagReason?.isNotEmpty ?? false)
          ? '\n\n⚠ ${result.flagReason}'
          : '';
      final replyText = result.summary.isNotEmpty
          ? '${result.summary}$flagNote'
          : 'Day summary complete. No significant patterns detected today.';

      setState(() {
        _appendMessage(
          _MiniMeChatMessage(role: _ChatRole.assistant, text: replyText),
        );
        _isReplying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appendMessage(
          const _MiniMeChatMessage(
            role: _ChatRole.assistant,
            text:
                'Could not generate day summary right now. Please try again later.',
          ),
        );
        _isReplying = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _refreshStartLoggingPromptState() async {
    final promptText = await _computeDailyLoggingPromptText();
    if (!mounted) return;
    setState(() {
      _dailyLoggingPromptText = promptText;
      if (promptText != null) {
        _replaceMessages(const <_MiniMeChatMessage>[]);
      }
    });
  }

  Future<void> _loadOpeningSuggestion() async {
    if (_didLoadOpeningSuggestion) return;
    final moodStore = context.read<MoodLogStore>();

    if (await _computeDailyLoggingPromptText() != null) {
      return;
    }

    _didLoadOpeningSuggestion = true;

    final moodContext = _buildMoodContext(moodStore);
    final summaryContext = await _buildSummaryContext();

    try {
      final response = await MiniMeBackendService.instance.chat(
        userMessage: '',
        moodLabel: moodContext.label,
        moodIntensity: moodContext.intensity,
        moodNotes: moodContext.notes,
        recentMoods: moodContext.recentMoodSummary,
        activeSymptoms: const [],
        history: const [],
        summaryContext: summaryContext,
        intelligence: _intelligence,
      );

      if (!mounted) return;
      final opening = response.openingSuggestion.isEmpty
          ? response.reply
          : response.openingSuggestion;

      setState(() {
        _appendMessage(
          _MiniMeChatMessage(role: _ChatRole.assistant, text: opening),
        );
      });
      await _persistMessages();
      await _refreshIntelligence();

      // Proactive check-in for acute-risk users — fires only when both
      // user_phase == 'acute-risk' and an alert string is set.
      if (mounted &&
          _intelligence != null &&
          _intelligence!.userPhase == 'acute-risk' &&
          (_intelligence!.alert?.isNotEmpty ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _appendMessage(
            const _MiniMeChatMessage(
              role: _ChatRole.assistant,
              text:
                  'I noticed some patterns in your recent logs that I want to check in about. '
                  'How are you feeling right now? No pressure — just want to make sure you have support if you need it.',
            ),
          );
        });
        await _persistMessages();
      }
    } catch (_) {
      if (!mounted) return;

      // Tier 2: Gemma on-device greeting (no backend required)
      if (AppServices.isGemmaLoaded) {
        final isGpu = AppServices.gemma.activeBackend == PreferredBackend.gpu;
        final online = await AppServices.isOnline();
        if (isGpu || !online) {
          try {
            final greeting = await AppServices.gemma
                .generateMiniMeReply(
                  userMessage:
                      'Start our conversation with a warm, brief greeting. Keep it to 1-2 sentences.',
                  moodLabel: moodContext.label,
                  intelligenceSummary: _buildIntelligenceSummary(),
                )
                .timeout(const Duration(seconds: 20));
            if (!mounted) return;
            setState(() {
              _appendMessage(
                _MiniMeChatMessage(role: _ChatRole.assistant, text: greeting),
              );
            });
            await _persistMessages();
            return;
          } catch (_) {
            // fall through to Gemini
          }
        }
      }

      // Tier 3: Direct Gemini greeting (network, no backend server required)
      if (await AppServices.isOnline()) {
        try {
          final greeting = await AppServices.gemini.generateMiniMeReply(
            userMessage:
                'Start our conversation with a warm, brief greeting. Keep it to 1-2 sentences.',
            moodLabel: moodContext.label,
            intelligenceSummary: _buildIntelligenceSummary(),
          );
          if (greeting.trim().isNotEmpty &&
              !greeting.startsWith('Unable to reach Gemini')) {
            if (!mounted) return;
            setState(() {
              _appendMessage(
                _MiniMeChatMessage(role: _ChatRole.assistant, text: greeting),
              );
            });
            await _persistMessages();
            return;
          }
        } catch (_) {
          // fall through to offline message
        }
      }

      // Tier 4: Static offline message
      if (!mounted) return;
      setState(() {
        _appendMessage(
          const _MiniMeChatMessage(
            role: _ChatRole.assistant,
            text:
                'Mini-Me backend is currently offline. I can still help in local mode and will retry when you send a message.',
          ),
        );
      });
      await _persistMessages();
    }
  }

  Future<String?> _computeDailyLoggingPromptText() async {
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();
    final today = DateTime.now();
    final firstName = _displayFirstName(widget.userName);

    final hasMoodToday = moodStore.items.any(
      (item) => _isSameDay(item.createdAt, today),
    );
    final hasSleepToday = sleepStore.items.any(
      (item) =>
          _isSameDay(item.date, today) || _isSameDay(item.wakeTime, today),
    );

    await _exerciseStore.ensureReady();
    final hasExerciseToday = _exerciseStore
        .getRecentExerciseHistory(limit: 40)
        .any((item) {
          final timestamp = DateTime.tryParse(item['timestamp'] ?? '');
          return timestamp != null && _isSameDay(timestamp, today);
        });

    final missing = <String>[
      if (!hasMoodToday) 'mood',
      if (!hasSleepToday) 'sleep',
      if (!hasExerciseToday) 'exercise',
    ];

    if (missing.length == 3) {
      return 'Hello $firstName. Start logging to get started';
    }

    if (missing.isEmpty) {
      return null;
    }

    return 'Make sure you log your ${_joinLogLabels(missing)} as well';
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _joinLogLabels(List<String> labels) {
    if (labels.length == 1) {
      return labels.first;
    }
    if (labels.length == 2) {
      return '${labels[0]} and ${labels[1]}';
    }
    final head = labels.sublist(0, labels.length - 1).join(', ');
    return '$head, and ${labels.last}';
  }

  Future<void> _refreshIntelligence() async {
    if (_isIntelligenceLoading || !mounted) return;

    setState(() {
      _isIntelligenceLoading = true;
    });

    final avatarStore = context.read<AvatarStore>();
    var recentFitnessEntries = const <FitnessEntry>[];

    try {
      final moodStore = context.read<MoodLogStore>();
      final sleepStore = context.read<SleepStore>();
      final recentMoods = moodStore.items.take(7).toList().reversed.toList();

      final mood = recentMoods
          .map((item) => item.intensity.clamp(1, 5))
          .toList(growable: false);

      final recentSleep = sleepStore.items
          .take(7)
          .toList()
          .reversed
          .map((item) => _sleepHoursFromEntry(item))
          .toList(growable: false);

      await _exerciseStore.ensureReady();
      final exercise = _exerciseStore
          .getRecentExerciseActivity(days: 7)
          .reversed
          .toList(growable: false);
      final activeSymptoms = await IsarService.instance
          .getActiveSymptomEntries();
      recentFitnessEntries = await IsarService.instance.getRecentFitnessEntries(
        days: 45,
      );
      final symptomCount = activeSymptoms
          .take(7)
          .map((entry) => entry.symptomList.length.clamp(0, 8))
          .toList(growable: false);
      avatarStore.setAutoBodyWidthScale(
        _autoBodyScaleFromFitnessEntries(recentFitnessEntries),
      );

      final payloadMood = mood.isEmpty ? const [3, 3, 3] : mood;
      final payloadSleep = recentSleep.isEmpty
          ? recentMoods
                .map((item) => _estimatedSleepHoursFromMood(item.moodLabel))
                .toList(growable: false)
          : recentSleep;
      final payloadExercise = exercise.isEmpty ? const [0, 0, 0] : exercise;
      final payloadSymptoms = symptomCount.isEmpty
          ? const [0, 0, 0]
          : symptomCount;

      final response = await MiniMeBackendService.instance.analyzeIntelligence(
        sleep: payloadSleep,
        mood: payloadMood,
        exercise: payloadExercise,
        symptomCount: payloadSymptoms,
      );

      if (!mounted) return;
      setState(() {
        _intelligence = response;
        _activeSymptomCount = activeSymptoms.length;
      });
    } catch (_) {
      // Keep UI functional even if backend is unavailable.
      avatarStore.setAutoBodyWidthScale(
        _autoBodyScaleFromFitnessEntries(recentFitnessEntries),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isIntelligenceLoading = false;
        });
      }
    }
  }

  double _autoBodyScaleFromFitnessEntries(List<FitnessEntry> entries) {
    if (entries.isEmpty) {
      return 1.0;
    }

    final recentWithBmi = entries
        .where((entry) => entry.bmi > 0)
        .take(14)
        .toList(growable: false);

    if (recentWithBmi.isEmpty) {
      return 1.0;
    }

    final latestBmi = recentWithBmi.first.bmi;
    final oldestBmi = recentWithBmi.length >= 4
        ? recentWithBmi.last.bmi
        : latestBmi;
    final baselineBmi =
        recentWithBmi.map((entry) => entry.bmi).reduce((a, b) => a + b) /
        recentWithBmi.length;

    final trendDelta = latestBmi - oldestBmi;
    final baselineDelta = latestBmi - baselineBmi;
    final combinedDelta = trendDelta * 0.6 + baselineDelta * 0.4;

    return (1.0 + (combinedDelta * 0.026)).clamp(0.82, 1.22).toDouble();
  }

  int _estimatedSleepHoursFromMood(String moodLabel) {
    final mood = moodLabel.trim().toLowerCase();
    if (mood == 'tired' || mood == 'sad' || mood == 'anxious') {
      return 5;
    }
    if (mood == 'neutral') {
      return 6;
    }
    return 7;
  }

  int _sleepHoursFromEntry(Sleep sleep) {
    final hours = sleep.duration.inMinutes / 60;
    return hours.round().clamp(0, 14);
  }

  String? _avatarMoodFromIntelligence(String? baseMoodLabel) {
    final linkage = _intelligence?.miniMeLinkage;
    final visualState = (linkage?['avatar_visual_state'] as String?)?.trim();
    if (visualState != null && visualState.isNotEmpty) {
      const visualToMood = <String, String>{
        'sleepy': 'tired',
        'drowsy': 'tired',
        'sad': 'sad',
        'concerned': 'anxious',
        'stressed': 'anxious',
        'sluggish': 'neutral',
        'critical': 'anxious',
        'urgent': 'anxious',
        'elevated': 'neutral',
        'uncertain': 'neutral',
        'neutral': 'neutral',
      };
      return visualToMood[visualState] ?? baseMoodLabel;
    }

    final state = _intelligence?.state;
    if (state == null) {
      return baseMoodLabel;
    }
    if (state['low_sleep'] == true) {
      return 'tired';
    }
    if (state['low_mood'] == true) {
      return 'sad';
    }
    return baseMoodLabel;
  }

  Future<void> _bootstrapMiniMe() async {
    if (_dailyLoggingPromptText != null) {
      return;
    }

    // Load recent messages from ISAR (last session) to restore history.
    final recentSessions = await IsarService.instance.getRecentChatSessions(
      limit: 1,
    );
    if (!mounted) return;

    if (recentSessions.isNotEmpty) {
      final List<ChatMessage> stored = await IsarService.instance
          .getMessagesForSession(recentSessions.first.sessionId);
      if (stored.isNotEmpty) {
        setState(() {
          _replaceMessages(
            stored.map(
              (m) => _MiniMeChatMessage(
                role: m.role == 'user' ? _ChatRole.user : _ChatRole.assistant,
                text: m.text,
              ),
            ),
          );
        });
        _scrollToBottom();
        await _syncUnreadSuggestions(forceRefresh: true);
        return;
      }
    }

    await _loadOpeningSuggestion();
    await _syncUnreadSuggestions(forceRefresh: false);
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isReplying) return;

    final moodStore = context.read<MoodLogStore>();
    final moodContext = _buildMoodContext(moodStore);
    final moodLabel = moodContext.label;

    setState(() {
      _isCoachExpanded = true;
      _appendMessage(_MiniMeChatMessage(role: _ChatRole.user, text: text));
      _isReplying = true;
    });
    await _persistMessages();
    _chatController.clear();
    _scrollToBottom();

    // Ensure intelligence is loaded — if initState timed out or this is the
    // first message before intelligence returned, fetch it now (3s timeout).
    if (_intelligence == null) {
      await _refreshIntelligence().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    }

    String reply;

    try {
      reply = await _geminiOrOffline(userText: text, moodContext: moodContext);
    } catch (_) {
      reply = _buildOfflineReply(userText: text, moodLabel: moodLabel);
    }

    if (!mounted) return;
    await _appendAssistantReplyInChunks(reply);
    await _refreshIntelligence();
  }

  Future<void> _syncUnreadSuggestions({required bool forceRefresh}) async {
    if (_isReplying || _isSurfacingUnreadSuggestions) return;

    final inbox = context.read<MiniMeSuggestionsInbox>();
    final moodStore = context.read<MoodLogStore>();
    final sleepStore = context.read<SleepStore>();

    if (forceRefresh || !inbox.isReady) {
      await inbox.refresh(moodStore: moodStore, sleepStore: sleepStore);
    }

    final unreadSuggestions = inbox.unreadSuggestions;
    if (!mounted || unreadSuggestions.isEmpty) return;

    _isSurfacingUnreadSuggestions = true;
    try {
      setState(() {
        _isCoachExpanded = true;
        _isReplying = true;
      });
      _scrollToBottom();

      final replies = _buildUnreadSuggestionMessages(unreadSuggestions);
      await _appendAssistantRepliesSequence(replies);
      await inbox.markSuggestionsViewed(unreadSuggestions);
      await _refreshIntelligence();
    } finally {
      _isSurfacingUnreadSuggestions = false;
    }
  }

  List<String> _buildUnreadSuggestionMessages(
    List<DailySuggestion> suggestions,
  ) {
    if (suggestions.isEmpty) {
      return const <String>[
        'I do not have a new suggestion yet, but I am still here if you want to check in.',
      ];
    }

    final intro = suggestions.length == 1
        ? 'I noticed 1 new suggestion from your recent check-ins.'
        : 'I noticed ${suggestions.length} new suggestions from your recent check-ins.';

    final replies = <String>[intro];
    for (var i = 0; i < suggestions.length; i++) {
      final item = suggestions[i];
      final action = item.action.trim();
      final reason = item.reason.trim();
      if (action.isEmpty && reason.isEmpty) continue;

      final buffer = StringBuffer('Suggestion ${i + 1}: ');
      if (action.isNotEmpty) {
        buffer.write(action);
      }
      if (reason.isNotEmpty) {
        if (action.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(reason);
      }
      replies.add(buffer.toString().trim());
    }

    return replies;
  }

  String _normalizeAssistantReply(String reply) {
    return reply
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  int _assistantRevealDelayMs(String reply) {
    final sentences = RegExp(r'[.!?]+').allMatches(reply).length.clamp(1, 6);
    final readingMs = reply.length * 18;
    final pacingMs = sentences * 320;
    return (900 + readingMs + pacingMs).clamp(1300, 5200).toInt();
  }

  Future<void> _appendAssistantReplyInChunks(String reply) async {
    final normalizedReply = _normalizeAssistantReply(reply);
    if (normalizedReply.isEmpty) {
      if (mounted) {
        setState(() => _isReplying = false);
      }
      return;
    }

    await Future<void>.delayed(
      Duration(milliseconds: _assistantRevealDelayMs(normalizedReply)),
    );

    if (!mounted) return;
    setState(() {
      _appendMessage(
        _MiniMeChatMessage(role: _ChatRole.assistant, text: normalizedReply),
      );
    });
    _scrollToBottom();
    await _persistMessages();

    if (mounted) {
      setState(() => _isReplying = false);
    }
  }

  Future<void> _appendAssistantRepliesSequence(List<String> replies) async {
    final normalizedReplies = replies
        .map(_normalizeAssistantReply)
        .where((reply) => reply.isNotEmpty)
        .toList(growable: false);

    if (normalizedReplies.isEmpty) {
      if (mounted) {
        setState(() => _isReplying = false);
      }
      return;
    }

    for (var i = 0; i < normalizedReplies.length; i++) {
      final reply = normalizedReplies[i];
      await Future<void>.delayed(
        Duration(milliseconds: _assistantRevealDelayMs(reply)),
      );

      if (!mounted) return;
      setState(() {
        _appendMessage(
          _MiniMeChatMessage(role: _ChatRole.assistant, text: reply),
        );
      });
      _scrollToBottom();
      await _persistMessages();

      if (i < normalizedReplies.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
      }
    }

    if (mounted) {
      setState(() => _isReplying = false);
    }
  }

  void _openFullChatSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MiniMeFullChatSheet(
        miniMeName: context.read<AvatarStore>().miniMeName,
        messages: _messages,
        isReplying: _isReplying,
      ),
    );
  }

  Future<String> _geminiOrOffline({
    required String userText,
    required _MiniMeMoodContext moodContext,
  }) async {
    if (await _isOnline()) {
      try {
        final summaryContext = await _buildSummaryContext();
        final history = _messages
            .take(20)
            .map(
              (m) => MiniMeChatTurn(
                role: m.role == _ChatRole.user ? 'user' : 'assistant',
                text: m.text,
              ),
            )
            .toList(growable: false);

        final response = await MiniMeBackendService.instance.chat(
          userMessage: userText,
          moodLabel: moodContext.label,
          moodIntensity: moodContext.intensity,
          moodNotes: moodContext.notes,
          recentMoods: moodContext.recentMoodSummary,
          activeSymptoms: const [],
          history: history,
          summaryContext: summaryContext,
          intelligence: _intelligence,
        );

        final reply = response.reply.trim().isNotEmpty
            ? response.reply.trim()
            : response.openingSuggestion.trim();
        if (reply.isNotEmpty) {
          return reply;
        }
      } catch (_) {
        // fall through to local model/offline fallback
      }
    }

    // Tier 2: Gemma on-device (no network required)
    // Skip when running on CPU backend and Gemini is reachable — CPU inference
    // on emulators / unsupported GPUs is too slow for interactive chat.
    if (AppServices.isGemmaLoaded) {
      final isGpu = AppServices.gemma.activeBackend == PreferredBackend.gpu;
      final online = await _isOnline();
      if (isGpu || !online) {
        try {
          return await AppServices.gemma
              .generateMiniMeReply(
                userMessage: userText,
                moodLabel: moodContext.label,
                intelligenceSummary: _buildIntelligenceSummary(),
              )
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          // fall through to direct Gemini
        }
      }
    }

    // Tier 3: Direct Gemini (network, no backend server required)
    if (await _isOnline()) {
      try {
        final directReply = await AppServices.gemini.generateMiniMeReply(
          userMessage: userText,
          moodLabel: moodContext.label,
          intelligenceSummary: _buildIntelligenceSummary(),
        );
        if (directReply.trim().isNotEmpty &&
            !directReply.startsWith('Unable to reach Gemini')) {
          return directReply;
        }
      } catch (_) {
        // fall through to offline template
      }
    }

    // Tier 4: Offline template
    return _buildOfflineReply(userText: userText, moodLabel: moodContext.label);
  }

  Future<bool> _isOnline() async {
    return AppServices.isOnline();
  }

  /// Builds a concise intelligence summary string for on-device LLM prompts.
  String? _buildIntelligenceSummary() {
    final i = _intelligence;
    if (i == null) return null;
    final parts = <String>[];
    if (i.lowSleep) parts.add('low sleep');
    if (i.lowMood) parts.add('low mood');
    if (i.inactive) parts.add('inactive');
    if (i.insights.isNotEmpty) parts.add(i.insights.first);
    final actions = i.selectedActions
        .map((a) => a.replaceAll('_', ' '))
        .join(', ');
    if (actions.isNotEmpty) parts.add('focus: $actions');
    if (parts.isEmpty) return null;
    return 'User is ${i.userPhase}. ${parts.join("; ")}.';
  }

  String _buildOfflineReply({
    required String userText,
    required String moodLabel,
  }) {
    final q = userText.toLowerCase();
    final i = _intelligence;

    // Intelligence-driven responses (PRIMARY)
    if (i != null) {
      if (i.userPhase == 'acute-risk') {
        return 'I want to make sure you feel supported right now. '
            'If anything feels overwhelming, reaching out to someone you trust — '
            'a friend, family member, or professional — can make a real difference. '
            'You are not alone in this.';
      }
      if (i.lowSleep && i.lowMood) {
        return 'Sleep and mood are closely connected. Tonight, try setting a '
            '20-minute wind-down reminder — reduce screens, write one thought '
            'to clear your mind. Small steps add up.';
      }
      if (i.lowSleep) {
        return 'Your recent sleep patterns suggest rest should be a priority. '
            "Tonight's plan: set a wind-down reminder, reduce light and screens, "
            'and write one thought to clear your mind before bed.';
      }
      if (i.inactive && i.lowMood) {
        return 'Movement and mood go hand in hand. Even a 10-minute walk can shift '
            'your energy. Start small — no pressure to do anything intense.';
      }
      if (i.inactive) {
        return 'Even a short walk helps reset your energy. Try a 10-minute '
            'movement break — it does not need to be intense to make a difference.';
      }
      if (i.lowMood) {
        return 'When mood is low, small wins matter most. Pick one thing you can '
            'complete in the next 15 minutes, then check in with yourself after.';
      }
      if (i.userPhase == 'declining') {
        return 'I have noticed a slight downward trend recently. '
            'Let us focus on one thing today — what feels most manageable: '
            'mood, sleep, or movement?';
      }
    }

    // Keyword-based fallback (when intelligence is null or stable with no flags)
    if (q.contains('sleep') || q.contains('tired')) {
      return "Tonight's sleep plan:\n1) Set a 20-minute wind-down reminder.\n2) Reduce light and screens.\n3) Write one thought to clear your mind before bed.";
    }
    if (q.contains('plan') || q.contains('routine') || q.contains('organize')) {
      return 'Your structure for today:\n1) One mood check-in.\n2) One movement block.\n3) One sleep-support action.\nKeep it simple and repeatable.';
    }

    return 'Model connection is not live yet. Based on your latest mood ($moodLabel), tell me your focus area (mood, sleep, symptoms, or exercise) and I will draft a short plan.';
  }

  /// Persist the most recently added message to ISAR via ChatSessionService.
  /// Called immediately after pushing a new message onto [_messages].
  /// Each message is written individually — crash-safe, no batch on navigate-away.
  Future<void> _persistMessages() async {
    if (_sessionId == null || _messages.isEmpty) return;
    final last = _messages.last;
    await _chatSessionService.addMessage(
      sessionId: _sessionId!,
      role: last.role == _ChatRole.user ? 'user' : 'assistant',
      text: last.text,
      sequenceNumber: _messageSequence++,
    );
  }

  _MiniMeMoodContext _buildMoodContext(MoodLogStore moodStore) {
    final latest = moodStore.items.isEmpty ? null : moodStore.items.first;
    final recent = moodStore.items.take(5).map((e) => e.moodLabel).toList();

    return _MiniMeMoodContext(
      label: latest?.moodLabel ?? 'Neutral',
      intensity: latest?.intensity ?? 0,
      notes: latest?.notes ?? '',
      recentMoodSummary: recent,
    );
  }

  _MiniMeDerivedUiState _getDerivedUiState({
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
    required String? effectiveMoodLabel,
  }) {
    final signature = _buildDerivedUiSignature(
      moodItems: moodItems,
      sleepItems: sleepItems,
      effectiveMoodLabel: effectiveMoodLabel,
    );
    final cached = _derivedUiState;
    if (cached != null && _derivedUiSignature == signature) {
      return cached;
    }

    final now = DateTime.now();
    final trackedStreakDays = _trackingStreakDays(
      now: now,
      moodItems: moodItems,
      sleepItems: sleepItems,
    );
    final computed = _MiniMeDerivedUiState(
      visualState: _buildMiniMeVisualState(
        moodItems: moodItems,
        sleepItems: sleepItems,
        effectiveMoodLabel: effectiveMoodLabel,
      ),
      celebrateOnOpen:
          trackedStreakDays >= 3 || _hasPositiveTrendForCelebration(),
    );
    _derivedUiSignature = signature;
    _derivedUiState = computed;
    return computed;
  }

  String _buildDerivedUiSignature({
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
    required String? effectiveMoodLabel,
  }) {
    final moodSignature = moodItems
        .take(6)
        .map(
          (item) =>
              '${item.createdAt.microsecondsSinceEpoch}:${item.intensity}:${item.moodLabel}',
        )
        .join('|');
    final sleepSignature = sleepItems
        .take(6)
        .map(
          (item) =>
              '${item.date.microsecondsSinceEpoch}:${item.wakeTime.microsecondsSinceEpoch}:${item.duration.inMinutes}',
        )
        .join('|');
    final intelligence = _intelligence;
    final intelligenceSignature = [
      _dayKey(DateTime.now()),
      _activeSymptomCount,
      effectiveMoodLabel ?? '',
      intelligence?.userPhase ?? '',
      intelligence?.lowSleep ?? false,
      intelligence?.lowMood ?? false,
      intelligence?.inactive ?? false,
      (intelligence?.miniMeLinkage['animation_state'] as String?) ?? '',
      intelligence?.trendClassification.values.join('|') ?? '',
    ].join('~');
    return '${moodItems.length}::${moodSignature}__${sleepItems.length}::${sleepSignature}__'
        '$intelligenceSignature';
  }

  Future<String> _buildSummaryContext() async {
    try {
      final moodSummary = await AppServices.quickTrack.buildMoodContext();
      final symptomSummary = await AppServices.quickTrack.buildSymptomContext();
      final conversationSummary = await AppServices.quickTrack
          .buildConversationContext();
      final parts = <String>[
        if (moodSummary.trim().isNotEmpty) 'Mood summary:\n$moodSummary',
        if (symptomSummary.trim().isNotEmpty)
          'Symptom summary:\n$symptomSummary',
        if (conversationSummary.trim().isNotEmpty)
          'Conversation summary:\n$conversationSummary',
      ];
      return parts.join('\n\n');
    } catch (_) {
      return '';
    }
  }

  // ignore: unused_element
  MiniMeVisualState _buildMiniMeVisualState({
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
    required String? effectiveMoodLabel,
  }) {
    final now = DateTime.now();
    final recentMoodItems = moodItems.take(6).toList(growable: false);
    final recentSleepItems = sleepItems.take(6).toList(growable: false);

    final avgMoodRecent = _averageMoodIntensity(
      recentMoodItems.take(3).toList(),
    );
    final avgMoodPrevious = _averageMoodIntensity(
      recentMoodItems.skip(3).take(3).toList(),
    );
    final avgSleepRecent = _averageSleepHours(
      recentSleepItems.take(3).toList(),
    );
    final avgSleepPrevious = _averageSleepHours(
      recentSleepItems.skip(3).take(3).toList(),
    );
    final hasRecentMoodData = recentMoodItems.isNotEmpty;
    final hasRecentSleepData = recentSleepItems.isNotEmpty;
    final sleepDebt = hasRecentSleepData
        ? ((7.5 - avgSleepRecent) / 3.5).clamp(0.0, 1.0)
        : 0.0;
    final symptomLevel = (_activeSymptomCount / 5).clamp(0.0, 1.0);
    final consistency = _trackingConsistency(
      now: now,
      moodItems: moodItems,
      sleepItems: sleepItems,
    );
    final streakStrength = _trackingStreakStrength(
      now: now,
      moodItems: moodItems,
      sleepItems: sleepItems,
    );

    final moodLabel = (effectiveMoodLabel ?? '').trim().toLowerCase();
    final intensity = hasRecentMoodData
        ? recentMoodItems.first.intensity / 5
        : 0.0;
    final moodDrop = avgMoodPrevious > 0
        ? ((avgMoodPrevious - avgMoodRecent) / 2.2).clamp(0.0, 1.0)
        : 0.0;
    final sleepDrop = hasRecentSleepData && avgSleepPrevious > 0
        ? ((avgSleepPrevious - avgSleepRecent) / 2.2).clamp(0.0, 1.0)
        : 0.0;
    var distressLevel = 0.0;
    if (_containsAny(moodLabel, const ['sad', 'low', 'down', 'distressed'])) {
      distressLevel += 0.34;
    }
    if (_containsAny(moodLabel, const ['anxious', 'stressed', 'overwhelmed'])) {
      distressLevel += 0.42;
    }
    if (_containsAny(moodLabel, const [
      'tired',
      'sleepy',
      'exhausted',
      'fatigued',
    ])) {
      distressLevel += 0.3;
    }
    distressLevel += intensity * 0.16;
    distressLevel += moodDrop * 0.24;
    if (_intelligence?.lowSleep == true) distressLevel += 0.14;
    if (_intelligence?.lowMood == true) distressLevel += 0.16;
    distressLevel = distressLevel.clamp(0.0, 1.0);

    var recoveryLevel = 0.0;
    if (avgMoodRecent > 0 &&
        avgMoodPrevious > 0 &&
        avgMoodRecent > avgMoodPrevious) {
      recoveryLevel += ((avgMoodRecent - avgMoodPrevious) / 2.0).clamp(
        0.0,
        0.3,
      );
    }
    if (avgSleepRecent > 0 &&
        avgSleepRecent >= avgSleepPrevious &&
        avgSleepRecent >= 7) {
      recoveryLevel += 0.24;
    }
    recoveryLevel += streakStrength * 0.26;
    recoveryLevel += consistency * 0.16;
    if (_containsAny(moodLabel, const ['calm', 'happy', 'joy', 'peaceful'])) {
      recoveryLevel += 0.16;
    }
    recoveryLevel = recoveryLevel.clamp(0.0, 1.0);

    final wearLevel =
        (sleepDebt * 0.22 +
                sleepDrop * 0.22 +
                moodDrop * 0.2 +
                distressLevel * 0.14 +
                symptomLevel * 0.12 -
                recoveryLevel * 0.18)
            .clamp(0.0, 1.0);
    final energyLevel =
        (0.62 +
                consistency * 0.16 +
                streakStrength * 0.08 +
                recoveryLevel * 0.18 -
                sleepDebt * 0.48 -
                distressLevel * 0.26 -
                symptomLevel * 0.16)
            .clamp(0.0, 1.0);

    final wateryEyes =
        (_containsAny(moodLabel, const ['sad', 'distressed', 'overwhelmed']) &&
            distressLevel > 0.42) ||
        symptomLevel > 0.7;
    final messyHair =
        (sleepDebt * 0.56 + distressLevel * 0.26 + symptomLevel * 0.14).clamp(
          0.0,
          1.0,
        );
    final postureSlump =
        (sleepDebt * 0.46 + distressLevel * 0.24 + (1 - energyLevel) * 0.22)
            .clamp(0.0, 1.0);
    final positiveMoodTrend = avgMoodRecent > 0
        ? ((avgMoodRecent - 3.0) / 2.0).clamp(0.0, 1.0)
        : 0.0;
    final strengtheningTrend =
        (recoveryLevel * 0.38 +
                streakStrength * 0.24 +
                consistency * 0.16 +
                energyLevel * 0.12 +
                positiveMoodTrend * 0.18 -
                distressLevel * 0.12 -
                sleepDebt * 0.08)
            .clamp(0.0, 1.0);

    MiniMeAmbientEffect ambientEffect = MiniMeAmbientEffect.none;
    if (recoveryLevel > 0.68 || streakStrength > 0.72) {
      ambientEffect = MiniMeAmbientEffect.sparkles;
    } else if (symptomLevel > 0.6) {
      ambientEffect = MiniMeAmbientEffect.rainCloud;
    } else if (_containsAny(moodLabel, const [
      'anxious',
      'stressed',
      'overwhelmed',
    ])) {
      ambientEffect = MiniMeAmbientEffect.sweat;
    } else if (sleepDebt > 0.52 || distressLevel > 0.56) {
      ambientEffect = MiniMeAmbientEffect.haze;
    }

    MiniMeAccessoryMood accessoryMood = MiniMeAccessoryMood.none;
    if (sleepDebt > 0.56) {
      accessoryMood = MiniMeAccessoryMood.coffee;
    } else if (symptomLevel > 0.56) {
      accessoryMood = MiniMeAccessoryMood.bandage;
    } else if (distressLevel > 0.46 && energyLevel < 0.5) {
      accessoryMood = MiniMeAccessoryMood.blanket;
    } else if (streakStrength > 0.84 || recoveryLevel > 0.76) {
      accessoryMood = MiniMeAccessoryMood.star;
    }

    MiniMeOutfitMode outfitMode = MiniMeOutfitMode.standard;
    if (wearLevel > 0.58) {
      outfitMode = MiniMeOutfitMode.worn;
    } else if (distressLevel > 0.45 || sleepDebt > 0.42) {
      outfitMode = MiniMeOutfitMode.comfort;
    } else if (energyLevel > 0.72 && consistency > 0.5) {
      outfitMode = MiniMeOutfitMode.active;
    } else if (recoveryLevel > 0.62 || streakStrength > 0.72) {
      outfitMode = MiniMeOutfitMode.polished;
    }

    return MiniMeVisualState(
      wearLevel: wearLevel,
      energyLevel: energyLevel,
      recoveryLevel: recoveryLevel,
      muscleToneLevel: strengtheningTrend,
      symptomLevel: symptomLevel,
      sleepDebtLevel: sleepDebt,
      distressLevel: distressLevel,
      streakLevel: streakStrength,
      messyHairLevel: messyHair,
      postureSlump: postureSlump,
      wateryEyes: wateryEyes,
      ambientEffect: ambientEffect,
      accessoryMood: accessoryMood,
      outfitMode: outfitMode,
      statusText: '',
    );
  }

  double _averageMoodIntensity(List<MoodCheckIn> moods) {
    if (moods.isEmpty) return 0;
    final total = moods.fold<double>(0, (sum, mood) => sum + mood.intensity);
    return total / moods.length;
  }

  double _averageSleepHours(List<Sleep> sleeps) {
    if (sleeps.isEmpty) return 0;
    final total = sleeps.fold<double>(
      0,
      (sum, sleep) => sum + sleep.duration.inMinutes / 60,
    );
    return total / sleeps.length;
  }

  double _trackingConsistency({
    required DateTime now,
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
  }) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final trackedDays = <String>{};
    for (final mood in moodItems) {
      if (mood.createdAt.isBefore(cutoff)) continue;
      trackedDays.add(_dayKey(mood.createdAt));
    }
    for (final sleep in sleepItems) {
      if (sleep.date.isBefore(cutoff)) continue;
      trackedDays.add(_dayKey(sleep.date));
    }
    return (trackedDays.length / 7).clamp(0.0, 1.0);
  }

  double _trackingStreakStrength({
    required DateTime now,
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
  }) {
    final streak = _trackingStreakDays(
      now: now,
      moodItems: moodItems,
      sleepItems: sleepItems,
    );
    return (streak / 7).clamp(0.0, 1.0);
  }

  int _trackingStreakDays({
    required DateTime now,
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
  }) {
    final trackedDays = <String>{};
    for (final mood in moodItems) {
      trackedDays.add(_dayKey(mood.createdAt));
    }
    for (final sleep in sleepItems) {
      trackedDays.add(_dayKey(sleep.date));
    }

    var streak = 0;
    for (var i = 0; i < 10; i++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      if (trackedDays.contains(_dayKey(day))) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  bool _hasPositiveTrendForCelebration() {
    final intelligence = _intelligence;
    if (intelligence == null) {
      return false;
    }

    final animationState =
        (intelligence.miniMeLinkage['animation_state'] as String? ?? '')
            .trim()
            .toLowerCase();
    if (animationState == 'recover_rise') {
      return true;
    }

    final positivePhases = {'improving', 'recovering', 'stable-positive'};
    if (positivePhases.contains(intelligence.userPhase.trim().toLowerCase())) {
      return true;
    }

    for (final value in intelligence.trendClassification.values) {
      final normalized = value.trim().toLowerCase();
      if (normalized.contains('improv') ||
          normalized.contains('positive') ||
          normalized.contains('upward') ||
          normalized.contains('better') ||
          normalized.contains('rising')) {
        return true;
      }
    }

    return false;
  }

  String _dayKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  bool _containsAny(String source, List<String> values) {
    for (final value in values) {
      if (source.contains(value)) {
        return true;
      }
    }
    return false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _expandCoachAndFocus() {
    if (!_isCoachExpanded) {
      setState(() => _isCoachExpanded = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_chatFocusNode.canRequestFocus) return;
      FocusScope.of(context).requestFocus(_chatFocusNode);
    });
  }

  void _toggleCoachExpanded() {
    final next = !_isCoachExpanded;
    setState(() => _isCoachExpanded = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_chatFocusNode.canRequestFocus) return;
        FocusScope.of(context).requestFocus(_chatFocusNode);
      });
      _scrollToBottom();
    } else {
      _chatFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: Selector<AvatarStore, String>(
          selector: (context, avatarStore) => avatarStore.miniMeName,
          builder: (context, miniMeName, _) => Text(miniMeName),
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty
                ? null
                : () async {
                    final shouldClear = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear chat'),
                        content: const Text(
                          'This will remove your current Mini-Me conversation and start fresh.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );

                    if (shouldClear != true || !context.mounted) return;

                    // End current session and start a fresh one.
                    if (_sessionId != null) {
                      _chatSessionService.endSession(_sessionId!);
                    }
                    setState(() {
                      _replaceMessages(const <_MiniMeChatMessage>[]);
                      _isCoachExpanded = false;
                      _isReplying = false;
                      _didLoadOpeningSuggestion = false;
                      _messageSequence = 0;
                    });
                    final moodStore2 = context.read<MoodLogStore>();
                    final moodCtx2 = _buildMoodContext(moodStore2);
                    _sessionId = await _chatSessionService.startSession(
                      moodLabel: moodCtx2.label,
                      moodIntensity: moodCtx2.intensity,
                      moodNotes: moodCtx2.notes.isEmpty ? null : moodCtx2.notes,
                    );
                    if (!context.mounted) return;
                    await _loadOpeningSuggestion();
                  },
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          IconButton(
            tooltip: 'Customize avatar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AvatarCustomizationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: cs.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Selector<MoodLogStore, _MiniMeMoodSelection>(
                  selector: (context, moodStore) =>
                      _MiniMeMoodSelection.fromItems(moodStore.items),
                  builder: (context, moodSelection, _) {
                    return _MiniMeStreakSection(moodLogs: moodSelection.items);
                  },
                ),
              ),
              Expanded(
                child: _MiniMePanelContent(
                  userName: widget.userName,
                  latestAssistantText: _latestAssistantMessageText,
                  dailyLoggingPromptText: _dailyLoggingPromptText,
                  intelligence: _intelligence,
                  resolveAvatarMoodLabel: _avatarMoodFromIntelligence,
                  computeDerivedUiState: _getDerivedUiState,
                  isIntelligenceLoading: _isIntelligenceLoading,
                  chatController: _chatController,
                  chatFocusNode: _chatFocusNode,
                  isReplying: _isReplying,
                  isCoachExpanded: _isCoachExpanded,
                  messages: _messages,
                  scrollController: _scrollController,
                  avatarWaveToken: _avatarWaveToken,
                  onToggleCoachExpanded: _toggleCoachExpanded,
                  onExpandCoach: _expandCoachAndFocus,
                  onOpenFullChat: _openFullChatSheet,
                  onSend: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMePanelContent extends StatelessWidget {
  const _MiniMePanelContent({
    required this.userName,
    required this.latestAssistantText,
    required this.dailyLoggingPromptText,
    required this.intelligence,
    required this.resolveAvatarMoodLabel,
    required this.computeDerivedUiState,
    required this.isIntelligenceLoading,
    required this.chatController,
    required this.chatFocusNode,
    required this.isReplying,
    required this.isCoachExpanded,
    required this.messages,
    required this.scrollController,
    required this.avatarWaveToken,
    required this.onToggleCoachExpanded,
    required this.onExpandCoach,
    required this.onOpenFullChat,
    required this.onSend,
  });

  final String userName;
  final String? latestAssistantText;
  final String? dailyLoggingPromptText;
  final MiniMeIntelligenceReply? intelligence;
  final String? Function(String? baseMoodLabel) resolveAvatarMoodLabel;
  final _MiniMeDerivedUiState Function({
    required List<MoodCheckIn> moodItems,
    required List<Sleep> sleepItems,
    required String? effectiveMoodLabel,
  })
  computeDerivedUiState;
  final bool isIntelligenceLoading;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final bool isReplying;
  final bool isCoachExpanded;
  final List<_MiniMeChatMessage> messages;
  final ScrollController scrollController;
  final int avatarWaveToken;
  final VoidCallback onToggleCoachExpanded;
  final VoidCallback onExpandCoach;
  final VoidCallback onOpenFullChat;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final moodSelection = context.select<MoodLogStore, _MiniMeMoodSelection>(
      (moodStore) => _MiniMeMoodSelection.fromItems(moodStore.items),
    );
    final sleepSelection = context.select<SleepStore, _MiniMeSleepSelection>(
      (sleepStore) => _MiniMeSleepSelection.fromItems(sleepStore.items),
    );
    final avatarSelection = context.select<AvatarStore, _MiniMeAvatarSelection>(
      (avatarStore) => _MiniMeAvatarSelection.fromStore(avatarStore),
    );

    final latest = moodSelection.latest;
    final glow = glowForIntensity(
      Theme.of(context).colorScheme,
      latest?.intensity ?? 0,
    );
    final avatarMoodLabel = resolveAvatarMoodLabel(latest?.moodLabel);
    final avatarAnimationState =
        intelligence?.miniMeLinkage['animation_state'] as String?;
    final derivedUiState = computeDerivedUiState(
      moodItems: moodSelection.items,
      sleepItems: sleepSelection.items,
      effectiveMoodLabel: avatarMoodLabel,
    );

    return _AvatarPanel(
      miniMeName: avatarSelection.miniMeName,
      userName: userName,
      avatarSelection: avatarSelection,
      glow: glow,
      moodLabel: avatarMoodLabel,
      moodEmoji: latest?.emoji,
      avatarAnimationState: avatarAnimationState,
      latestAssistantText: latestAssistantText,
      dailyLoggingPromptText: dailyLoggingPromptText,
      visualState: derivedUiState.visualState,
      avatarWaveToken: avatarWaveToken,
      celebrateOnOpen: derivedUiState.celebrateOnOpen,
      intelligenceState: intelligence?.state,
      intelligenceInsights: intelligence?.insights ?? const <String>[],
      intelligenceAlert: intelligence?.alert,
      intelligenceMessage: intelligence?.message,
      isIntelligenceLoading: isIntelligenceLoading,
      chatController: chatController,
      chatFocusNode: chatFocusNode,
      isReplying: isReplying,
      isCoachExpanded: isCoachExpanded,
      messages: messages,
      scrollController: scrollController,
      onToggleCoachExpanded: onToggleCoachExpanded,
      onExpandCoach: onExpandCoach,
      onOpenFullChat: onOpenFullChat,
      onSend: onSend,
    );
  }
}

class _AvatarPanel extends StatelessWidget {
  const _AvatarPanel({
    required this.miniMeName,
    required this.userName,
    required this.avatarSelection,
    required this.glow,
    required this.moodLabel,
    required this.moodEmoji,
    required this.avatarAnimationState,
    required this.latestAssistantText,
    required this.dailyLoggingPromptText,
    required this.visualState,
    required this.avatarWaveToken,
    required this.celebrateOnOpen,
    required this.intelligenceState,
    required this.intelligenceInsights,
    required this.intelligenceAlert,
    required this.intelligenceMessage,
    required this.isIntelligenceLoading,
    required this.chatController,
    required this.chatFocusNode,
    required this.isReplying,
    required this.isCoachExpanded,
    required this.messages,
    required this.scrollController,
    required this.onToggleCoachExpanded,
    required this.onExpandCoach,
    required this.onOpenFullChat,
    required this.onSend,
  });

  final String miniMeName;
  final String userName;
  final _MiniMeAvatarSelection avatarSelection;
  final Color glow;
  final String? moodLabel;
  final String? moodEmoji;
  final String? avatarAnimationState;
  final String? latestAssistantText;
  final String? dailyLoggingPromptText;
  final MiniMeVisualState visualState;
  final int avatarWaveToken;
  final bool celebrateOnOpen;
  final Map<String, dynamic>? intelligenceState;
  final List<String> intelligenceInsights;
  final String? intelligenceAlert;
  final String? intelligenceMessage;
  final bool isIntelligenceLoading;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final bool isReplying;
  final bool isCoachExpanded;
  final List<_MiniMeChatMessage> messages;
  final ScrollController scrollController;
  final VoidCallback onToggleCoachExpanded;
  final VoidCallback onExpandCoach;
  final VoidCallback onOpenFullChat;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const chatDockHeight = 112.0;
        const collapsedBottomInset = 16.0;
        final showPromptBubble =
            messages.isEmpty || (latestAssistantText?.isNotEmpty ?? false);
        final promptBubbleText = dailyLoggingPromptText != null
            ? dailyLoggingPromptText!
            : messages.isEmpty
            ? 'What do you want to work on today, ${_displayFirstName(userName)}?'
            : _bubblePreviewText(
                latestAssistantText ??
                    'What do you want to work on today, ${_displayFirstName(userName)}?',
              );
        final headTiltBias = isReplying ? -0.12 : 0.0;
        final bubbleMaxHeight = math.min(constraints.maxHeight * 0.18, 118.0);
        const suggestionBubbleReserve = 108.0;
        final availableAvatarHeight =
            constraints.maxHeight -
            chatDockHeight -
            collapsedBottomInset -
            suggestionBubbleReserve;
        final avatarSize = math.max(
          320.0,
          math.min(
            constraints.biggest.shortestSide * 1.3,
            availableAvatarHeight * 1.02,
          ),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (showPromptBubble)
                  Positioned(
                    top: 10,
                    left: 18,
                    right: 18,
                    child: _AvatarSuggestionBubble(
                      text: promptBubbleText,
                      maxHeight: bubbleMaxHeight,
                    ),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      4,
                      suggestionBubbleReserve - 8,
                      4,
                      chatDockHeight + collapsedBottomInset - 18,
                    ),
                    child: Align(
                      alignment: const Alignment(0, -0.2),
                      child: Transform.translate(
                        offset: const Offset(0, -62),
                        child: RepaintBoundary(
                          child: MiniMeAvatar(
                            bodyModel: avatarSelection.bodyModel,
                            hairModel: avatarSelection.hairModel,
                            shirtModel: avatarSelection.shirtModel,
                            bodyWidthScale: avatarSelection.bodyWidthScale,
                            companionId: avatarSelection.companionId,
                            moodLabel: moodLabel,
                            moodEmoji: moodEmoji,
                            animationState: avatarAnimationState,
                            glow: glow,
                            size: avatarSize,
                            degradationLevel: visualState.wearLevel,
                            isHatched: avatarSelection.isMiniMeHatched,
                            visualState: visualState,
                            onHatchComplete: avatarSelection.onHatchComplete,
                            autoWaveToken: avatarWaveToken,
                            lockScreenPosition: true,
                            headTiltBias: headTiltBias,
                            celebrateOnOpen: celebrateOnOpen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: RepaintBoundary(
                child: _CoachComposerCard(
                  miniMeName: miniMeName,
                  chatController: chatController,
                  chatFocusNode: chatFocusNode,
                  isReplying: isReplying,
                  onExpandCoach: onExpandCoach,
                  onOpenFullChat: onOpenFullChat,
                  onSend: onSend,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _bubblePreviewText(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }

  final firstSentence = normalized
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((part) => part.trim())
      .firstWhere((part) => part.isNotEmpty, orElse: () => normalized);

  final candidate = firstSentence.length >= 36 ? firstSentence : normalized;
  if (candidate.length <= 120) {
    return candidate;
  }

  final truncated = candidate.substring(0, 117).trimRight();
  return '$truncated...';
}

class _MainTypingBubble extends StatelessWidget {
  const _MainTypingBubble({required this.miniMeName});

  final String miniMeName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TypingDots(),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$miniMeName is typing...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarSuggestionBubble extends StatelessWidget {
  const _AvatarSuggestionBubble({required this.text, required this.maxHeight});

  final String text;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bubbleColor = cs.surface.withValues(alpha: 0.98);
    final bubbleBorder = cs.outlineVariant.withValues(alpha: 0.62);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: bubbleBorder, width: 1.15),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Scrollbar(
                    thumbVisibility: false,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(34, 18),
                  painter: _SpeechTailPainter(
                    fillColor: bubbleColor,
                    borderColor: bubbleBorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  const _SpeechTailPainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.22, 0)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.16,
        size.width * 0.72,
        0,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.46,
        size.width * 0.52,
        size.height * 0.98,
      )
      ..quadraticBezierTo(
        size.width * 0.47,
        size.height * 0.58,
        size.width * 0.22,
        0,
      )
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechTailPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

String _displayFirstName(String userName) {
  final trimmed = userName.trim();
  if (trimmed.isEmpty) {
    return 'Friend';
  }
  return trimmed.split(RegExp(r'\s+')).first;
}

// ignore: unused_element
class _InlineCoachPanel extends StatelessWidget {
  const _InlineCoachPanel({
    required this.miniMeName,
    required this.userName,
    required this.moodLabel,
    required this.isReplying,
    required this.messages,
    required this.scrollController,
    required this.intelligenceState,
    required this.intelligenceInsights,
    required this.intelligenceAlert,
    required this.intelligenceMessage,
    required this.isIntelligenceLoading,
    required this.onOpenFullChat,
  });

  final String miniMeName;
  final String userName;
  final String moodLabel;
  final bool isReplying;
  final List<_MiniMeChatMessage> messages;
  final ScrollController scrollController;
  final Map<String, dynamic>? intelligenceState;
  final List<String> intelligenceInsights;
  final String? intelligenceAlert;
  final String? intelligenceMessage;
  final bool isIntelligenceLoading;
  final VoidCallback onOpenFullChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final firstName = _displayFirstName(userName);
    final previewMessages = messages.length <= 3
        ? messages
        : messages.sublist(messages.length - 3);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: 220,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primaryContainer,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Icon(
                        Icons.psychology_alt_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            miniMeName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _CoachStatusPill(
                                icon: Icons.favorite_rounded,
                                label: 'Mood $moodLabel',
                                background: cs.secondaryContainer,
                                foreground: cs.onSecondaryContainer,
                              ),
                              _CoachStatusPill(
                                icon: Icons.forum_rounded,
                                label: '${messages.length} messages',
                                background: cs.surface,
                                foreground: cs.onSurfaceVariant,
                              ),
                              if (intelligenceState != null)
                                _CoachStatusPill(
                                  icon: Icons.bedtime_rounded,
                                  label: intelligenceState!['low_sleep'] == true
                                      ? 'Low sleep'
                                      : 'Sleep OK',
                                  background: cs.surface,
                                  foreground: cs.onSurfaceVariant,
                                ),
                              if (intelligenceState != null)
                                _CoachStatusPill(
                                  icon: Icons.directions_run_rounded,
                                  label: intelligenceState!['inactive'] == true
                                      ? 'Inactive'
                                      : 'Active',
                                  background: cs.surface,
                                  foreground: cs.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isReplying)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Thinking',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: onOpenFullChat,
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 18,
                          ),
                          label: const Text('Full chat'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isIntelligenceLoading ||
                  intelligenceInsights.isNotEmpty ||
                  (intelligenceAlert?.isNotEmpty ?? false) ||
                  (intelligenceMessage?.isNotEmpty ?? false))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.insights_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Signals',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (isIntelligenceLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Updating...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if ((intelligenceAlert?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Alert: ${intelligenceAlert!}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if ((intelligenceMessage?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            intelligenceMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.2,
                            ),
                          ),
                        ),
                      if (intelligenceInsights.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: intelligenceInsights
                                .take(2)
                                .map(
                                  (insight) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• $insight',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                    ],
                  ),
                ),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
              Expanded(
                child: messages.isEmpty && !isReplying
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Hello $firstName! Start logging to get started.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        itemCount:
                            previewMessages.length + (isReplying ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isReplying && index == 0) {
                            return _TypingBubble(miniMeName: miniMeName);
                          }

                          final messageIndex = isReplying ? index - 1 : index;
                          final message =
                              previewMessages[previewMessages.length -
                                  1 -
                                  messageIndex];
                          return _ChatBubbleCard(
                            miniMeName: miniMeName,
                            message: message,
                            isUser: message.role == _ChatRole.user,
                            maxBodyLines: 3,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachComposerCard extends StatelessWidget {
  const _CoachComposerCard({
    required this.miniMeName,
    required this.chatController,
    required this.chatFocusNode,
    required this.isReplying,
    required this.onExpandCoach,
    required this.onOpenFullChat,
    required this.onSend,
  });

  final String miniMeName;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final bool isReplying;
  final VoidCallback onExpandCoach;
  final VoidCallback onOpenFullChat;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReplying) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IgnorePointer(
                ignoring: true,
                child: _MainTypingBubble(miniMeName: miniMeName),
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                onPressed: onOpenFullChat,
                tooltip: 'Open full chat',
                icon: const Icon(Icons.open_in_full_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: chatController,
                  focusNode: chatFocusNode,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  onTap: onExpandCoach,
                  decoration: InputDecoration(
                    hintText: 'Message $miniMeName...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: cs.primary,
                        size: 18,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minHeight: 18,
                      minWidth: 34,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isReplying ? null : onSend,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Icon(
                  isReplying
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_upward_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachStatusPill extends StatelessWidget {
  const _CoachStatusPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubbleCard extends StatelessWidget {
  const _ChatBubbleCard({
    required this.miniMeName,
    required this.message,
    required this.isUser,
    this.maxBodyLines,
  });

  final String miniMeName;
  final _MiniMeChatMessage message;
  final bool isUser;
  final int? maxBodyLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final suggestionParts = isUser
        ? const <_SuggestionSection>[]
        : message.suggestionSections;
    final introText = isUser ? null : message.suggestionIntro;
    final bubbleColor = isUser
        ? cs.primaryContainer.withValues(alpha: 0.96)
        : cs.surface.withValues(alpha: 0.92);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUser
                          ? cs.primary.withValues(alpha: 0.12)
                          : cs.secondaryContainer,
                    ),
                    child: Icon(
                      isUser
                          ? Icons.edit_note_rounded
                          : Icons.psychology_alt_rounded,
                      size: 14,
                      color: isUser ? cs.primary : cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isUser ? 'You' : miniMeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isUser
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (suggestionParts.length > 1) ...[
                if (introText != null && introText.isNotEmpty) ...[
                  Text(
                    introText,
                    maxLines: maxBodyLines,
                    overflow: maxBodyLines == null
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ...suggestionParts.map(
                  (part) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SuggestionDetailCard(section: part),
                  ),
                ),
              ] else
                Text(
                  message.text,
                  maxLines: maxBodyLines,
                  overflow: maxBodyLines == null
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isUser ? cs.onPrimaryContainer : cs.onSurface,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    height: 1.42,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionDetailCard extends StatelessWidget {
  const _SuggestionDetailCard({required this.section});

  final _SuggestionSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Suggestion ${section.index}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.miniMeName});

  final String miniMeName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TypingDots(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$miniMeName is shaping your next step...',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + index * 0.18) % 1.0;
            final active = phase < 0.5;
            return Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (active ? cs.primary : cs.outlineVariant).withValues(
                  alpha: active ? 1 : 0.65,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MiniMeFullChatSheet extends StatelessWidget {
  const _MiniMeFullChatSheet({
    required this.miniMeName,
    required this.messages,
    required this.isReplying,
  });

  final String miniMeName;
  final List<_MiniMeChatMessage> messages;
  final bool isReplying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Full chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                itemCount: messages.length + (isReplying ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isReplying && index == 0) {
                    return _TypingBubble(miniMeName: miniMeName);
                  }

                  final messageIndex = isReplying ? index - 1 : index;
                  final message = messages[messages.length - 1 - messageIndex];
                  return _ChatBubbleCard(
                    miniMeName: miniMeName,
                    message: message,
                    isUser: message.role == _ChatRole.user,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _extractSuggestionIntro(
  String message,
  List<_SuggestionSection> sections,
) {
  if (sections.isEmpty) return null;

  final firstMarker = 'Suggestion ${sections.first.index}:';
  final markerIndex = message.indexOf(firstMarker);
  if (markerIndex <= 0) return null;

  final intro = message.substring(0, markerIndex).trim();
  return intro.isEmpty ? null : intro;
}

List<_SuggestionSection> _parseSuggestionSections(String message) {
  final matches = RegExp(
    r'Suggestion\s+(\d+):\s*(.*?)(?=Suggestion\s+\d+:|$)',
    dotAll: true,
  ).allMatches(message);

  if (matches.length <= 1) {
    return const <_SuggestionSection>[];
  }

  return matches
      .map((match) {
        final index = int.tryParse(match.group(1) ?? '') ?? 0;
        final body = (match.group(2) ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return _SuggestionSection(index: index, body: body);
      })
      .where((section) => section.index > 0 && section.body.isNotEmpty)
      .toList(growable: false);
}

class _SuggestionSection {
  const _SuggestionSection({required this.index, required this.body});

  final int index;
  final String body;
}

class _MiniMeDerivedUiState {
  const _MiniMeDerivedUiState({
    required this.visualState,
    required this.celebrateOnOpen,
  });

  final MiniMeVisualState visualState;
  final bool celebrateOnOpen;
}

class _MiniMeMoodSelection {
  const _MiniMeMoodSelection({
    required this.items,
    required this.signature,
    required this.latest,
  });

  factory _MiniMeMoodSelection.fromItems(List<MoodCheckIn> items) {
    final latest = items.isEmpty ? null : items.first;
    final recentSignature = items
        .take(14)
        .map(
          (item) =>
              '${item.createdAt.microsecondsSinceEpoch}:${item.intensity}:${item.moodLabel}:${item.emoji}',
        )
        .join('|');
    final trackedDays = items
        .map(
          (item) =>
              '${item.createdAt.year}-${item.createdAt.month}-${item.createdAt.day}',
        )
        .take(14)
        .join('|');
    return _MiniMeMoodSelection(
      items: items,
      signature: '${items.length}__${recentSignature}__$trackedDays',
      latest: latest,
    );
  }

  final List<MoodCheckIn> items;
  final String signature;
  final MoodCheckIn? latest;

  @override
  bool operator ==(Object other) =>
      other is _MiniMeMoodSelection && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}

class _MiniMeSleepSelection {
  const _MiniMeSleepSelection({required this.items, required this.signature});

  factory _MiniMeSleepSelection.fromItems(List<Sleep> items) {
    final recentSignature = items
        .take(14)
        .map(
          (item) =>
              '${item.date.microsecondsSinceEpoch}:${item.wakeTime.microsecondsSinceEpoch}:${item.duration.inMinutes}',
        )
        .join('|');
    final trackedDays = items
        .map((item) => '${item.date.year}-${item.date.month}-${item.date.day}')
        .take(14)
        .join('|');
    return _MiniMeSleepSelection(
      items: items,
      signature: '${items.length}__${recentSignature}__$trackedDays',
    );
  }

  final List<Sleep> items;
  final String signature;

  @override
  bool operator ==(Object other) =>
      other is _MiniMeSleepSelection && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}

class _MiniMeAvatarSelection {
  const _MiniMeAvatarSelection({
    required this.miniMeName,
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    required this.companionId,
    required this.isMiniMeHatched,
    required this.onHatchComplete,
  });

  factory _MiniMeAvatarSelection.fromStore(AvatarStore avatarStore) {
    return _MiniMeAvatarSelection(
      miniMeName: avatarStore.miniMeName,
      bodyModel: avatarStore.bodyModel,
      hairModel: avatarStore.hairModel,
      shirtModel: avatarStore.shirtModel,
      bodyWidthScale: avatarStore.effectiveBodyWidthScale,
      companionId: avatarStore.companionId,
      isMiniMeHatched: avatarStore.isMiniMeHatched,
      onHatchComplete: avatarStore.hatchMiniMe,
    );
  }

  final String miniMeName;
  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final String companionId;
  final bool isMiniMeHatched;
  final VoidCallback onHatchComplete;

  @override
  bool operator ==(Object other) {
    return other is _MiniMeAvatarSelection &&
        other.miniMeName == miniMeName &&
        other.bodyModel == bodyModel &&
        other.hairModel == hairModel &&
        other.shirtModel == shirtModel &&
        other.bodyWidthScale == bodyWidthScale &&
        other.companionId == companionId &&
        other.isMiniMeHatched == isMiniMeHatched;
  }

  @override
  int get hashCode => Object.hash(
    miniMeName,
    bodyModel,
    hairModel,
    shirtModel,
    bodyWidthScale,
    companionId,
    isMiniMeHatched,
  );
}

final Expando<List<_SuggestionSection>> _messageSuggestionSectionsCache =
    Expando<List<_SuggestionSection>>('messageSuggestionSections');
final Object _nullSuggestionIntro = Object();
final Expando<Object> _messageSuggestionIntroCache = Expando<Object>(
  'messageSuggestionIntro',
);

class _MiniMeStreakSection extends StatefulWidget {
  const _MiniMeStreakSection({required this.moodLogs});

  final List<MoodCheckIn> moodLogs;

  @override
  State<_MiniMeStreakSection> createState() => _MiniMeStreakSectionState();
}

class _MiniMeStreakSectionState extends State<_MiniMeStreakSection> {
  late Future<StreakSnapshot> _future;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _signature = _buildSignature(widget.moodLogs);
    _future = _loadSnapshot();
  }

  @override
  void didUpdateWidget(covariant _MiniMeStreakSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSignature = _buildSignature(widget.moodLogs);
    if (newSignature != _signature) {
      _signature = newSignature;
      _future = _loadSnapshot();
    }
  }

  Future<StreakSnapshot> _loadSnapshot() {
    return StreakService.instance.buildSnapshot(moodLogs: widget.moodLogs);
  }

  String _buildSignature(List<MoodCheckIn> logs) {
    final latest = logs.isEmpty ? '' : logs.first.createdAt.toIso8601String();
    return '${logs.length}|$latest';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<StreakSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _StreakShell(
            title: 'Daily Streak',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(
                7,
                (index) => _DayCircle(
                  label: const Text(''),
                  icon: Icons.circle_outlined,
                  filled: false,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _StreakShell(
            title: 'Daily Streak',
            child: Text(
              'Streak data will update after your next log.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          );
        }

        final streak = snapshot.data!;
        final badgeIcon = _badgeToIcon(streak.badge);

        return _StreakShell(
          title: 'Daily Streak',
          headerTrailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 16, color: cs.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  '${streak.currentStreak} days',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: streak.recentDays.map((day) {
                  final weekday = _weekdayLetter(day.date.weekday);
                  return _DayCircle(
                    label: Text(
                      weekday,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: _levelToIcon(day.runLevel),
                    filled: day.isLogged,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                streak.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Best streak: ${streak.bestStreak} day${streak.bestStreak == 1 ? '' : 's'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _weekdayLetter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[(weekday - 1).clamp(0, 6)];
  }

  IconData _badgeToIcon(String badge) {
    switch (badge) {
      case 'sprout':
        return Icons.spa_rounded;
      case 'leaf':
        return Icons.eco_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'flame':
        return Icons.local_fire_department_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      case 'spark':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  IconData _levelToIcon(int runLevel) {
    if (runLevel <= 0) {
      return Icons.circle_outlined;
    }
    if (runLevel == 1) {
      return Icons.done_rounded;
    }
    if (runLevel == 2) {
      return Icons.spa_rounded;
    }
    if (runLevel == 3) {
      return Icons.eco_rounded;
    }
    if (runLevel == 4) {
      return Icons.bolt_rounded;
    }
    if (runLevel <= 6) {
      return Icons.local_fire_department_rounded;
    }
    return Icons.workspace_premium_rounded;
  }
}

class _StreakShell extends StatelessWidget {
  const _StreakShell({
    required this.title,
    required this.child,
    this.headerTrailing,
  });

  final String title;
  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (headerTrailing != null) headerTrailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.label,
    required this.icon,
    required this.filled,
  });

  final Widget label;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        label,
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? cs.primary : cs.surface,
            border: Border.all(
              color: filled ? cs.primary : cs.outlineVariant,
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: filled ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

enum _ChatRole { user, assistant }

class _MiniMeChatMessage {
  const _MiniMeChatMessage({required this.role, required this.text});

  final _ChatRole role;
  final String text;

  List<_SuggestionSection> get suggestionSections {
    final cached = _messageSuggestionSectionsCache[this];
    if (cached != null) {
      return cached;
    }
    final parsed = role == _ChatRole.assistant
        ? _parseSuggestionSections(text)
        : const <_SuggestionSection>[];
    _messageSuggestionSectionsCache[this] = parsed;
    return parsed;
  }

  String? get suggestionIntro {
    final cached = _messageSuggestionIntroCache[this];
    if (cached != null) {
      return identical(cached, _nullSuggestionIntro) ? null : cached as String;
    }

    final sections = suggestionSections;
    final intro = sections.isNotEmpty
        ? _extractSuggestionIntro(text, sections)
        : null;
    _messageSuggestionIntroCache[this] = intro ?? _nullSuggestionIntro;
    return intro;
  }
}

class _MiniMeMoodContext {
  const _MiniMeMoodContext({
    required this.label,
    required this.intensity,
    required this.notes,
    required this.recentMoodSummary,
  });

  final String label;
  final int intensity;
  final String notes;
  final List<String> recentMoodSummary;
}
