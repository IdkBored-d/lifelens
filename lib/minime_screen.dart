import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart' show PreferredBackend;
import 'package:provider/provider.dart';
import 'package:lifelens/app_services.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';
import 'package:lifelens/utils/minime_helpers.dart';
import 'package:lifelens/services/streak_service.dart';
import 'package:lifelens/services/minime_shop_service.dart';
import 'package:lifelens/services/minime_backend_service.dart';
import 'package:lifelens/services/chat_session_service.dart';
import 'package:lifelens/services/exercise_store.dart';
import 'package:lifelens/services/mini_me_suggestion_aggregator.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/chat_message.dart';
import 'avatar_store.dart';
import 'avatar_customization_screen.dart';

class MiniMeScreen extends StatefulWidget {
  const MiniMeScreen({super.key, required this.userName});

  final String userName;

  @override
  State<MiniMeScreen> createState() => _MiniMeScreenState();
}

class _MiniMeScreenState extends State<MiniMeScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  bool _didLoadOpeningSuggestion = false;
  bool _isCoachExpanded = false;
  bool _isReplying = false;
  bool _isIntelligenceLoading = false;
  final List<_MiniMeChatMessage> _messages = [];
  MiniMeIntelligenceReply? _intelligence;
  final ExerciseStore _exerciseStore = ExerciseStore();

  // Chat session persistence (ISAR-backed, replaces flat-file MiniMeChatStorageService)
  String? _sessionId;
  int _messageSequence = 0;
  late final ChatSessionService _chatSessionService;

  @override
  void initState() {
    super.initState();
    _chatSessionService = ChatSessionService(AppServices.quickTrack, AppServices.gemma);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Intelligence loads first — drives opening message + avatar mood.
      // 3-second timeout so a slow/offline backend doesn't block the screen.
      await _refreshIntelligence().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
      final moodStore = context.read<MoodLogStore>();
      final moodCtx   = _buildMoodContext(moodStore);
      _sessionId = await _chatSessionService.startSession(
        moodLabel:     moodCtx.label,
        moodIntensity: moodCtx.intensity,
        moodNotes:     moodCtx.notes.isEmpty ? null : moodCtx.notes,
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

  // ignore: unused_element
  Future<void> _runDaySummary() async {
    if (_isReplying) return;

    setState(() {
      _isCoachExpanded = true;
      _isReplying = true;
      _messages.add(
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
        _messages.add(
          _MiniMeChatMessage(role: _ChatRole.assistant, text: replyText),
        );
        _isReplying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
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

  Future<void> _loadOpeningSuggestion() async {
    if (_didLoadOpeningSuggestion) return;
    _didLoadOpeningSuggestion = true;

    final moodStore = context.read<MoodLogStore>();
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
        _messages.add(
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
          _messages.add(
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
            final greeting = await AppServices.gemma.generateMiniMeReply(
              userMessage:
                  'Start our conversation with a warm, brief greeting. Keep it to 1-2 sentences.',
              moodLabel: moodContext.label,
              intelligenceSummary: _buildIntelligenceSummary(),
            ).timeout(const Duration(seconds: 20));
            if (!mounted) return;
            setState(() {
              _messages.add(
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
              _messages.add(
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
        _messages.add(
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

  Future<void> _refreshIntelligence() async {
    if (_isIntelligenceLoading || !mounted) return;

    setState(() {
      _isIntelligenceLoading = true;
    });

    try {
      final moodStore = context.read<MoodLogStore>();
      final recentMoods = moodStore.items.take(7).toList().reversed.toList();

      final mood = recentMoods
          .map((item) => item.intensity.clamp(1, 5))
          .toList(growable: false);

      final sleep = recentMoods
          .map((item) => _estimatedSleepHoursFromMood(item.moodLabel))
          .toList(growable: false);

      await _exerciseStore.ensureReady();
      final exercise = _exerciseStore
          .getRecentExerciseActivity(days: 7)
          .reversed
          .toList(growable: false);

      final payloadMood = mood.isEmpty ? const [3, 3, 3] : mood;
      final payloadSleep = sleep.isEmpty ? const [7, 7, 7] : sleep;
      final payloadExercise = exercise.isEmpty ? const [0, 0, 0] : exercise;

      final response = await MiniMeBackendService.instance.analyzeIntelligence(
        sleep: payloadSleep,
        mood: payloadMood,
        exercise: payloadExercise,
      );

      if (!mounted) return;
      setState(() {
        _intelligence = response;
      });
    } catch (_) {
      // Keep UI functional even if backend is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _isIntelligenceLoading = false;
        });
      }
    }
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
    // Load recent messages from ISAR (last session) to restore history.
    final recentSessions = await IsarService.instance.getRecentChatSessions(limit: 1);
    if (!mounted) return;

    if (recentSessions.isNotEmpty) {
      final List<ChatMessage> stored = await IsarService.instance
          .getMessagesForSession(recentSessions.first.sessionId);
      if (stored.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(
              stored.map(
                (m) => _MiniMeChatMessage(
                  role: m.role == 'user' ? _ChatRole.user : _ChatRole.assistant,
                  text: m.text,
                ),
              ),
            );
        });
        _scrollToBottom();
        return;
      }
    }

    await _loadOpeningSuggestion();
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isReplying) return;

    final moodStore = context.read<MoodLogStore>();
    final moodContext = _buildMoodContext(moodStore);
    final moodLabel = moodContext.label;
    final summaryContext = await _buildSummaryContext();

    setState(() {
      _isCoachExpanded = true;
      _messages.add(_MiniMeChatMessage(role: _ChatRole.user, text: text));
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

  Future<void> _requestDailySuggestions() async {
    if (_isReplying) return;

    const userPrompt = 'Give me today\'s daily suggestions.';

    setState(() {
      _isCoachExpanded = true;
      _messages.add(
        const _MiniMeChatMessage(role: _ChatRole.user, text: userPrompt),
      );
      _isReplying = true;
    });
    await _persistMessages();
    _scrollToBottom();

    try {
      final suggestions = await MiniMeSuggestionAggregator.generateDailySuggestions(
        days: 7,
      );

      final nonEmpty = suggestions
          .where(
            (item) =>
                item.action.trim().isNotEmpty || item.reason.trim().isNotEmpty,
          )
          .toList(growable: false);

      if (nonEmpty.isEmpty) {
        await _appendAssistantReplyInChunks(
          'I could not build suggestions yet. Add one quick check-in and ask again.',
        );
        await _refreshIntelligence();
        return;
      }

      final buffer = StringBuffer(
        'I reviewed your recent logs, symptoms, and chat history. Here are your daily suggestions.',
      );

      for (var i = 0; i < nonEmpty.length && i < 3; i++) {
        final action = nonEmpty[i].action.trim();
        final reason = nonEmpty[i].reason.trim();
        buffer.write(' Suggestion ${i + 1}: ');
        if (action.isNotEmpty) {
          buffer.write('$action ');
        }
        if (reason.isNotEmpty) {
          buffer.write('($reason) ');
        }
      }

      await _appendAssistantReplyInChunks(buffer.toString().trim());
    } catch (_) {
      await _appendAssistantReplyInChunks(
        'I could not fetch your daily suggestions right now, but I can still help if you tell me your focus for today.',
      );
    }

    await _refreshIntelligence();
  }

  List<String> _splitAssistantReply(String reply) {
    final normalized = reply.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final chunks = normalized
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    if (chunks.isEmpty) {
      return <String>[normalized];
    }

    final result = <String>[];
    for (final chunk in chunks) {
      if (chunk.length <= 85) {
        result.add(chunk);
        continue;
      }

      final subParts = chunk
          .split(RegExp(r'(?<=[,;:])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      if (subParts.isEmpty || subParts.length == 1) {
        result.add(chunk);
      } else {
        result.addAll(subParts);
      }
    }

    final condensed = <String>[];
    for (final part in result) {
      if (part.length <= 72) {
        condensed.add(part);
        continue;
      }

      final words = part.split(RegExp(r'\s+'));
      final buffer = StringBuffer();
      for (final word in words) {
        final candidate = buffer.isEmpty ? word : '${buffer.toString()} $word';
        if (candidate.length > 72 && buffer.isNotEmpty) {
          condensed.add(buffer.toString());
          buffer
            ..clear()
            ..write(word);
        } else {
          if (buffer.isNotEmpty) {
            buffer.write(' ');
          }
          buffer.write(word);
        }
      }
      if (buffer.isNotEmpty) {
        condensed.add(buffer.toString());
      }
    }

    return condensed;
  }

  int _assistantChunkDelayMs(String chunk, int index, int total) {
    final base = 420 + (chunk.length * 9).clamp(0, 420);
    final gap = index == 0 ? 280 : 0;
    final tail = index == total - 1 ? 220 : 0;
    return (base + gap + tail).clamp(520, 1700).toInt();
  }

  Future<void> _appendAssistantReplyInChunks(String reply) async {
    final chunks = _splitAssistantReply(reply);
    final safeChunks = chunks.isEmpty ? <String>[reply.trim()] : chunks;

    if (safeChunks.isEmpty || (safeChunks.length == 1 && safeChunks.first.isEmpty)) {
      if (mounted) {
        setState(() => _isReplying = false);
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 420));

    for (var i = 0; i < safeChunks.length; i++) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _MiniMeChatMessage(role: _ChatRole.assistant, text: safeChunks[i]),
        );
      });
      _scrollToBottom();
      await _persistMessages();

      if (i < safeChunks.length - 1) {
        await Future<void>.delayed(
          Duration(
            milliseconds: _assistantChunkDelayMs(
              safeChunks[i],
              i,
              safeChunks.length,
            ),
          ),
        );
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
        final symptomContext = await _buildSymptomContext();
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
          return await AppServices.gemma.generateMiniMeReply(
            userMessage: userText,
            moodLabel: moodContext.label,
            intelligenceSummary: _buildIntelligenceSummary(),
          ).timeout(const Duration(seconds: 20));
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
    final actions = i.selectedActions.map((a) => a.replaceAll('_', ' ')).join(', ');
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
      sessionId:      _sessionId!,
      role:           last.role == _ChatRole.user ? 'user' : 'assistant',
      text:           last.text,
      sequenceNumber: _messageSequence++,
    );
  }

  _MiniMeMoodContext _buildMoodContext(MoodLogStore moodStore) {
    final latest = moodStore.items.isEmpty ? null : moodStore.items.first;
    final recent = moodStore.items
        .take(5)
        .map((e) => e.moodLabel)
        .toList();

    return _MiniMeMoodContext(
      label: latest?.moodLabel ?? 'Neutral',
      intensity: latest?.intensity ?? 0,
      notes: latest?.notes ?? '',
      recentMoodSummary: recent,
    );
  }

  Future<String> _buildSummaryContext() async {
    try {
      final moodSummary = await AppServices.quickTrack.buildMoodContext();
      final symptomSummary = await AppServices.quickTrack.buildSymptomContext();
      final conversationSummary = await AppServices.quickTrack.buildConversationContext();
      final parts = <String>[
        if (moodSummary.trim().isNotEmpty) 'Mood summary:\n$moodSummary',
        if (symptomSummary.trim().isNotEmpty) 'Symptom summary:\n$symptomSummary',
        if (conversationSummary.trim().isNotEmpty) 'Conversation summary:\n$conversationSummary',
      ];
      return parts.join('\n\n');
    } catch (_) {
      return '';
    }
  }

  String _latestSuggestionText() {
    for (final message in _messages.reversed) {
      if (message.role == _ChatRole.assistant &&
          message.text.trim().isNotEmpty) {
        return message.text;
      }
    }
    return 'Preparing your daily suggestion...';
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

  Future<void> _openShop({
    required MoodLogStore moodStore,
    required AvatarStore avatarStore,
  }) async {
    final streak = await StreakService.instance.buildSnapshot(
      moodLogs: moodStore.items,
    );
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MiniMeShopSheet(
          avatarStore: avatarStore,
          streakSnapshot: streak,
        );
      },
    );
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
        title: Consumer<AvatarStore>(
          builder: (context, avatarStore, _) => Text(avatarStore.miniMeName),
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
                      _messages.clear();
                      _isCoachExpanded = false;
                      _isReplying = false;
                      _didLoadOpeningSuggestion = false;
                      _messageSequence = 0;
                    });
                    final moodStore2 = context.read<MoodLogStore>();
                    final moodCtx2   = _buildMoodContext(moodStore2);
                    _sessionId = await _chatSessionService.startSession(
                      moodLabel:     moodCtx2.label,
                      moodIntensity: moodCtx2.intensity,
                      moodNotes:     moodCtx2.notes.isEmpty ? null : moodCtx2.notes,
                    );
                    if (!context.mounted) return;
                    await _loadOpeningSuggestion();
                  },
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          IconButton(
            tooltip: 'Mini-Me shop',
            onPressed: () {
              final moodStore = context.read<MoodLogStore>();
              final avatarStore = context.read<AvatarStore>();
              _openShop(moodStore: moodStore, avatarStore: avatarStore);
            },
            icon: const Icon(Icons.storefront_rounded),
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
      body: Consumer2<MoodLogStore, AvatarStore>(
        builder: (context, moodStore, avatarStore, _) {
          final miniMeName = avatarStore.miniMeName;
          final latest = moodStore.items.isEmpty ? null : moodStore.items.first;
          final intensity = latest?.intensity ?? 0;
          final glow = glowForIntensity(theme.colorScheme, intensity);
          final latestSuggestion = _latestSuggestionText();
          final avatarMoodLabel = _avatarMoodFromIntelligence(
            latest?.moodLabel,
          );
          final avatarAnimationState =
              _intelligence?.miniMeLinkage['animation_state'] as String?;

          return Container(
            width: double.infinity,
            height: double.infinity,
            color: cs.surface,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _MiniMeStreakSection(moodLogs: moodStore.items),
                  ),
                  Expanded(
                    child: _AvatarPanel(
                      miniMeName: miniMeName,
                      userName: widget.userName,
                      avatarStore: avatarStore,
                      glow: glow,
                      moodLabel: avatarMoodLabel,
                      moodEmoji: latest?.emoji,
                      suggestionText: latestSuggestion,
                      intelligenceState: _intelligence?.state,
                      intelligenceInsights:
                          _intelligence?.insights ?? const <String>[],
                      intelligenceAlert: _intelligence?.alert,
                      intelligenceMessage: _intelligence?.message,
                      isIntelligenceLoading: _isIntelligenceLoading,
                      chatController: _chatController,
                      chatFocusNode: _chatFocusNode,
                      isReplying: _isReplying,
                      isCoachExpanded: _isCoachExpanded,
                      messages: _messages,
                      scrollController: _scrollController,
                      onToggleCoachExpanded: () {
                        _toggleCoachExpanded();
                      },
                      onExpandCoach: _expandCoachAndFocus,
                      onOpenFullChat: _openFullChatSheet,
                      onRequestDailySuggestions: _requestDailySuggestions,
                      onSend: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AvatarPanel extends StatelessWidget {
  const _AvatarPanel({
    required this.miniMeName,
    required this.userName,
    required this.avatarStore,
    required this.glow,
    required this.moodLabel,
    required this.moodEmoji,
    required this.suggestionText,
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
    required this.onRequestDailySuggestions,
    required this.onSend,
  });

  final String miniMeName;
  final String userName;
  final AvatarStore avatarStore;
  final Color glow;
  final String? moodLabel;
  final String? moodEmoji;
  final String suggestionText;
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
  final VoidCallback onRequestDailySuggestions;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const chatDockHeight = 132.0;
        const collapsedBottomInset = 16.0;
        String? latestAssistantText;
        for (final message in messages.reversed) {
          if (message.role == _ChatRole.assistant &&
              message.text.trim().isNotEmpty) {
            latestAssistantText = message.text.trim();
            break;
          }
        }
        final showPromptBubble =
          messages.isEmpty || (latestAssistantText?.isNotEmpty ?? false);
        final promptBubbleText = messages.isEmpty
          ? 'What do you want to work on today, ${_displayFirstName(userName)}?'
            : (latestAssistantText ??
                  'What do you want to work on today, ${_displayFirstName(userName)}?');
        final suggestionBubbleReserve = showPromptBubble ? 72.0 : 16.0;
        final availableAvatarHeight =
            constraints.maxHeight -
            chatDockHeight -
            collapsedBottomInset -
            suggestionBubbleReserve;
        final avatarSize = math.min(
          constraints.biggest.shortestSide * 1.04,
          availableAvatarHeight.clamp(320.0, 820.0),
        );

        return Stack(
          children: [
            Stack(
              children: [
                if (showPromptBubble)
                  Positioned(
                    top: 10,
                    left: 18,
                    right: 18,
                    child: _AvatarSuggestionBubble(
                      text: promptBubbleText,
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
                      alignment: const Alignment(0, -0.06),
                      child: MiniMeAvatar(
                        bodyModel: avatarStore.bodyModel,
                        hairModel: avatarStore.hairModel,
                        shirtModel: avatarStore.shirtModel,
                        bodyWidthScale: avatarStore.bodyWidthScale,
                        moodLabel: moodLabel,
                        moodEmoji: moodEmoji,
                        animationState: avatarAnimationState,
                        glow: glow,
                        size: avatarSize,
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
              child: _CoachComposerCard(
                miniMeName: miniMeName,
                chatController: chatController,
                chatFocusNode: chatFocusNode,
                isReplying: isReplying,
                onExpandCoach: onExpandCoach,
                onOpenFullChat: onOpenFullChat,
                onRequestDailySuggestions: onRequestDailySuggestions,
                onSend: onSend,
              ),
            ),
          ],
        );
      },
    );
  }
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
  const _AvatarSuggestionBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bubbleColor = cs.surface.withValues(alpha: 0.98);
    final bubbleBorder = cs.outlineVariant.withValues(alpha: 0.62);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
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
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
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
                          icon: const Icon(Icons.open_in_full_rounded, size: 18),
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
                            'Start the conversation below and $miniMeName will build on your latest check-ins.',
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
                        itemCount: previewMessages.length + (isReplying ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isReplying && index == 0) {
                            return _TypingBubble(miniMeName: miniMeName);
                          }

                          final messageIndex = isReplying ? index - 1 : index;
                          final message =
                              previewMessages[previewMessages.length - 1 - messageIndex];
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
    required this.onRequestDailySuggestions,
    required this.onSend,
  });

  final String miniMeName;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final bool isReplying;
  final VoidCallback onExpandCoach;
  final VoidCallback onOpenFullChat;
  final VoidCallback onRequestDailySuggestions;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: isReplying ? null : onRequestDailySuggestions,
                tooltip: 'Daily suggestions',
                icon: const Icon(Icons.tips_and_updates_rounded),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
          const SizedBox(height: 12),
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

class _MiniMeShopSheet extends StatefulWidget {
  const _MiniMeShopSheet({
    required this.avatarStore,
    required this.streakSnapshot,
  });

  final AvatarStore avatarStore;
  final StreakSnapshot streakSnapshot;

  @override
  State<_MiniMeShopSheet> createState() => _MiniMeShopSheetState();
}

class _MiniMeShopSheetState extends State<_MiniMeShopSheet> {
  final MiniMeShopService _shopService = MiniMeShopService.instance;
  late Future<MiniMeShopState> _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = _loadState();
  }

  Future<MiniMeShopState> _loadState() async {
    final rewarded = await _shopService.grantDailyRewards(
      streak: widget.streakSnapshot,
    );

    if (rewarded.lastReward.rewarded) {
      return rewarded;
    }

    return _shopService.loadState();
  }

  Future<void> _unlock(String itemId) async {
    setState(() {
      _stateFuture = _shopService.unlockItem(itemId: itemId);
    });
  }

  void _equip(MiniMeShopItem item) {
    switch (item.type) {
      case MiniMeItemType.hair:
        widget.avatarStore.setHairModel(item.assetPath ?? '');
        break;
      case MiniMeItemType.shirt:
        widget.avatarStore.setShirtModel(item.assetPath ?? '');
        break;
      case MiniMeItemType.bodyScale:
        widget.avatarStore.setBodyWidthScale(item.bodyScale ?? 1.0);
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} equipped.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isEquipped(MiniMeShopItem item) {
    switch (item.type) {
      case MiniMeItemType.hair:
        return widget.avatarStore.hairModel == (item.assetPath ?? '');
      case MiniMeItemType.shirt:
        return widget.avatarStore.shirtModel == (item.assetPath ?? '');
      case MiniMeItemType.bodyScale:
        return widget.avatarStore.bodyWidthScale == (item.bodyScale ?? 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.surfaceContainerHighest, cs.surface, cs.surface],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: FutureBuilder<MiniMeShopState>(
          future: _stateFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final state = snapshot.data!;
            final featuredItem = state.items.isEmpty ? null : state.items.first;

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primaryContainer,
                              cs.secondaryContainer,
                              cs.surfaceContainerHighest,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surface.withValues(alpha: 0.36),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.videogame_asset_rounded,
                                        size: 16,
                                        color: cs.onSurface,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Loadout Shop',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                _ShopHudPill(
                                  icon: Icons.monetization_on_rounded,
                                  label: '${state.coins}',
                                  background: cs.primary,
                                  foreground: cs.onPrimary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Upgrade your Mini-Me like a main character.',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Collect coins from daily check-ins, unlock cosmetics, and equip a stronger look for your next streak.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _ShopStatCard(
                                    title: 'Streak Power',
                                    value:
                                        '${widget.streakSnapshot.currentStreak}',
                                    suffix: 'days',
                                    icon: Icons.local_fire_department_rounded,
                                    accent: cs.tertiary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _ShopStatCard(
                                    title: 'Unlocked',
                                    value: '${state.unlockedIds.length}',
                                    suffix: 'items',
                                    icon: Icons.auto_awesome_rounded,
                                    accent: cs.secondary,
                                  ),
                                ),
                              ],
                            ),
                            if (featuredItem != null) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cs.surface.withValues(alpha: 0.44),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.38,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            _itemAccent(
                                              featuredItem,
                                              cs,
                                            ).withValues(alpha: 0.34),
                                            cs.surface.withValues(alpha: 0.2),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: _itemAccent(
                                            featuredItem,
                                            cs,
                                          ).withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Icon(
                                        _itemIcon(featuredItem),
                                        color: _itemAccent(featuredItem, cs),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Featured Drop',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            featuredItem.name,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _rarityLabel(featuredItem),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (state.lastReward.message.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: state.lastReward.rewarded
                                  ? [cs.tertiaryContainer, cs.primaryContainer]
                                  : [
                                      cs.surfaceContainerHighest,
                                      cs.surfaceContainer,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: state.lastReward.rewarded
                                  ? cs.tertiary.withValues(alpha: 0.35)
                                  : cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: state.lastReward.rewarded
                                      ? cs.tertiary.withValues(alpha: 0.14)
                                      : cs.surface.withValues(alpha: 0.5),
                                ),
                                child: Icon(
                                  state.lastReward.rewarded
                                      ? Icons.workspace_premium_rounded
                                      : Icons.event_repeat_rounded,
                                  color: state.lastReward.rewarded
                                      ? cs.tertiary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  state.lastReward.rewarded
                                      ? '+${state.lastReward.amount} coins unlocked. ${state.lastReward.message}'
                                      : state.lastReward.message,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: state.lastReward.rewarded
                                        ? cs.onTertiaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            'Inventory',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${state.items.length} unlockables',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...state.items.map<Widget>((item) {
                        final unlocked = state.unlockedIds.contains(item.id);
                        final equipped = unlocked && _isEquipped(item);
                        final canBuy = state.coins >= item.cost;
                        final accent = _itemAccent(item, cs);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accent.withValues(alpha: 0.18),
                                  cs.surfaceContainerHighest,
                                  cs.surfaceContainer,
                                ],
                              ),
                              border: Border.all(
                                color: equipped
                                    ? accent
                                    : cs.outlineVariant.withValues(alpha: 0.34),
                                width: equipped ? 1.6 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.12),
                                  blurRadius: 22,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            accent.withValues(alpha: 0.34),
                                            accent.withValues(alpha: 0.08),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Icon(
                                        _itemIcon(item),
                                        color: accent,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: accent.withValues(
                                                    alpha: 0.14,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  _itemTypeLabel(item.type),
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: accent,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: cs.surface.withValues(
                                                    alpha: 0.56,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  _rarityLabel(item),
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: cs.onSurface,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.name,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.surface.withValues(
                                          alpha: 0.52,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: cs.outlineVariant.withValues(
                                            alpha: 0.24,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.monetization_on_rounded,
                                            size: 18,
                                            color: cs.primary,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.cost}',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        equipped
                                            ? 'Currently in loadout'
                                            : unlocked
                                            ? 'Owned and ready to equip'
                                            : canBuy
                                            ? 'Available for unlock'
                                            : 'Need ${item.cost - state.coins} more coins',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: equipped
                                                  ? accent
                                                  : cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (equipped)
                                      FilledButton(
                                        onPressed: null,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: accent.withValues(
                                            alpha: 0.9,
                                          ),
                                          disabledBackgroundColor: accent
                                              .withValues(alpha: 0.9),
                                          disabledForegroundColor: cs.onPrimary,
                                        ),
                                        child: const Text('Equipped'),
                                      )
                                    else if (unlocked)
                                      FilledButton.icon(
                                        onPressed: () => _equip(item),
                                        icon: const Icon(
                                          Icons.flash_on_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Equip'),
                                      )
                                    else
                                      FilledButton.tonalIcon(
                                        onPressed: canBuy
                                            ? () => _unlock(item.id)
                                            : null,
                                        icon: const Icon(
                                          Icons.lock_open_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          canBuy
                                              ? 'Unlock for ${item.cost}'
                                              : 'Locked',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _itemIcon(MiniMeShopItem item) {
    switch (item.type) {
      case MiniMeItemType.hair:
        return Icons.face_4_rounded;
      case MiniMeItemType.shirt:
        return Icons.checkroom_rounded;
      case MiniMeItemType.bodyScale:
        return Icons.accessibility_new_rounded;
    }
  }

  String _itemTypeLabel(MiniMeItemType type) {
    switch (type) {
      case MiniMeItemType.hair:
        return 'Headgear';
      case MiniMeItemType.shirt:
        return 'Outfit';
      case MiniMeItemType.bodyScale:
        return 'Stance';
    }
  }

  String _rarityLabel(MiniMeShopItem item) {
    if (item.cost >= 30) return 'Epic Drop';
    if (item.cost >= 20) return 'Rare Skin';
    return 'Starter Gear';
  }

  Color _itemAccent(MiniMeShopItem item, ColorScheme cs) {
    switch (item.type) {
      case MiniMeItemType.hair:
        return cs.secondary;
      case MiniMeItemType.shirt:
        return cs.primary;
      case MiniMeItemType.bodyScale:
        return cs.tertiary;
    }
  }
}

class _ShopHudPill extends StatelessWidget {
  const _ShopHudPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopStatCard extends StatelessWidget {
  const _ShopStatCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      TextSpan(
                        text: ' $suffix',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
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

enum _ChatRole { user, assistant }

class _MiniMeChatMessage {
  const _MiniMeChatMessage({required this.role, required this.text});

  final _ChatRole role;
  final String text;
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
