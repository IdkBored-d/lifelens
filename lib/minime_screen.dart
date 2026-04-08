import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lifelens/app_services.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';
import 'package:lifelens/utils/minime_helpers.dart';
import 'package:lifelens/services/streak_service.dart';
import 'package:lifelens/services/minime_shop_service.dart';
import 'package:lifelens/services/minime_backend_service.dart';
import 'package:lifelens/services/minime_chat_storage_service.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
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
  final List<_MiniMeChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapMiniMe();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _runDaySummary() async {
    if (_isReplying) return;

    setState(() {
      _isCoachExpanded = true;
      _isReplying = true;
      _messages.add(const _MiniMeChatMessage(
        role: _ChatRole.user,
        text: 'Generate my day summary',
      ));
    });
    _scrollToBottom();

    try {
      // TODO: replace `true` with a real connectivity check (connectivity_plus).
      final result = await AppServices.eodPipeline.runEndOfDay(isOnline: await AppServices.isOnline());

      if (!mounted) return;

      final flagNote = result.flagged && (result.flagReason?.isNotEmpty ?? false)
          ? '\n\n⚠ ${result.flagReason}'
          : '';
      final replyText = result.summary.isNotEmpty
          ? '${result.summary}$flagNote'
          : 'Day summary complete. No significant patterns detected today.';

      setState(() {
        _messages.add(_MiniMeChatMessage(role: _ChatRole.assistant, text: replyText));
        _isReplying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const _MiniMeChatMessage(
          role: _ChatRole.assistant,
          text: 'Could not generate day summary right now. Please try again later.',
        ));
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
    final symptomContext = await _buildSymptomContext();

    try {
      final response = await MiniMeBackendService.instance.chat(
        userMessage: '',
        moodLabel: moodContext.label,
        moodIntensity: moodContext.intensity,
        moodNotes: moodContext.notes,
        recentMoods: moodContext.recentMoodSummary,
        activeSymptoms: symptomContext,
        history: const [],
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _MiniMeChatMessage(
            role: _ChatRole.assistant,
            text:
                'Mini-Me backend is unavailable right now. Start your backend server and try again.',
          ),
        );
      });
      await _persistMessages();
    }
  }

  Future<void> _bootstrapMiniMe() async {
    final stored = await MiniMeChatStorageService.instance.loadMessages();
    if (!mounted) return;

    if (stored.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(
            stored.map(
              (message) => _MiniMeChatMessage(
                role: message.role == 'user'
                    ? _ChatRole.user
                    : _ChatRole.assistant,
                text: message.text,
              ),
            ),
          );
      });
      _scrollToBottom();
      return;
    }

    await _loadOpeningSuggestion();
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isReplying) return;

    final moodStore = context.read<MoodLogStore>();
    final moodContext = _buildMoodContext(moodStore);
    final moodLabel = moodContext.label;

    setState(() {
      _isCoachExpanded = true;
      _messages.add(_MiniMeChatMessage(role: _ChatRole.user, text: text));
      _isReplying = true;
    });
    await _persistMessages();
    _chatController.clear();
    _scrollToBottom();

    String reply;

    try {
      // Tier 1: Gemma (on-device, no network required)
      if (AppServices.isGemmaLoaded) {
        try {
          reply = await AppServices.gemma.generateMiniMeReply(
            userMessage: text,
            moodLabel: moodLabel,
          );
        } catch (_) {
          reply = await _geminiOrOffline(text, moodLabel);
        }
      } else {
        reply = await _geminiOrOffline(text, moodLabel);
      }
    } catch (_) {
      reply = _buildOfflineReply(userText: text, moodLabel: moodLabel);
    }

      if (!mounted) return;
      setState(() {
        _messages.add(
          _MiniMeChatMessage(role: _ChatRole.assistant, text: response.reply),
        );
        _isReplying = false;
      });
      await _persistMessages();
      _scrollToBottom();

  /// Tier 2: Gemini if online, else Tier 3: offline template.
  Future<String> _geminiOrOffline(String text, String moodLabel) async {
    if (await _isOnline()) {
      try {
        final now = DateTime.now();
        final dateStr = now.toIso8601String().split('T').first;
        // Use reply if non-empty, else openingSuggestion
        final suggestion = (response.reply.trim().isNotEmpty)
            ? response.reply.trim()
            : response.openingSuggestion.trim();
        final moodEntry = MoodEntry()
          ..date = dateStr
          ..rawLog = text
          ..condensedLog = text.length > 60
              ? '${text.substring(0, 60)}...'
              : text
          ..resolvedMood = moodContext.label
          ..resolvedBy = 'minime'
          ..mobileBertPrediction = null
          ..mobileBertTopProb = null
          ..userConfirmed = null
          ..responseText = suggestion
          ..fitnessScoreSnapshot = 0.0
          ..timestamp = now;
        await IsarService.instance.writeMoodEntry(moodEntry);

        if (!mounted) return;
        await context.read<MoodLogStore>().refreshFromPersistence();
      } catch (e) {
        // Optionally log error
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _MiniMeChatMessage(
            role: _ChatRole.assistant,
            text:
                'I could not reach your Mini-Me backend, so I cannot generate a response yet. Please verify the backend is running on port 8000 and send again.',
          ),
        );
        _isReplying = false;
      });
      await _persistMessages();
      _scrollToBottom();
    }

    if (q.contains('sleep') || q.contains('tired')) {
      return 'Tonight\'s sleep plan:\n1) Set a 20-minute wind-down reminder.\n2) Reduce light and screens.\n3) Write one thought to clear your mind before bed.';
    }

    if (q.contains('plan') || q.contains('routine') || q.contains('organize')) {
      return 'Your structure for today:\n1) One mood check-in.\n2) One movement block.\n3) One sleep-support action.\nKeep it simple and repeatable.';
    }

    return 'Model connection is not live yet. Based on your latest mood ($moodLabel), tell me your focus area (mood, sleep, symptoms, or exercise) and I will draft a short plan.';
  }

  Future<void> _persistMessages() {
    return MiniMeChatStorageService.instance.saveMessages(
      _messages
          .map(
            (message) => MiniMeStoredMessage(
              role: message.role == _ChatRole.user ? 'user' : 'assistant',
              text: message.text,
            ),
          )
          .toList(growable: false),
    );
  }

  _MiniMeMoodContext _buildMoodContext(MoodLogStore moodStore) {
    final latest = moodStore.items.isEmpty ? null : moodStore.items.first;
    final recent = moodStore.items
        .take(5)
        .map((e) => '${e.moodLabel} (${e.intensity}/5)')
        .toList();

    return _MiniMeMoodContext(
      label: latest?.moodLabel ?? 'Neutral',
      intensity: latest?.intensity ?? 0,
      notes: latest?.notes ?? '',
      recentMoodSummary: recent,
    );
  }

  Future<List<String>> _buildSymptomContext() async {
    try {
      final entries = await IsarService.instance.getActiveSymptomEntries();
      return entries.take(6).map((e) {
        final symptoms = e.symptomList.take(3).join(', ');
        return '${e.predictedAilment}: $symptoms';
      }).toList();
    } catch (_) {
      return const [];
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
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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

                    setState(() {
                      _messages.clear();
                      _isCoachExpanded = false;
                      _isReplying = false;
                      _didLoadOpeningSuggestion = false;
                    });
                    await MiniMeChatStorageService.instance.clear();
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

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.surface, cs.surfaceContainerHighest],
              ),
            ),
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
                      moodLabel: latest?.moodLabel,
                      moodEmoji: latest?.emoji,
                      suggestionText: latestSuggestion,
                      chatController: _chatController,
                      chatFocusNode: _chatFocusNode,
                      isReplying: _isReplying,
                      isCoachExpanded: _isCoachExpanded,
                      messages: _messages,
                      scrollController: _scrollController,
                      onToggleCoachExpanded: () {
                        setState(() {
                          _isCoachExpanded = !_isCoachExpanded;
                        });
                        if (_isCoachExpanded) {
                          _scrollToBottom();
                        }
                      },
                      onExpandCoach: () {
                        if (!_isCoachExpanded) {
                          setState(() => _isCoachExpanded = true);
                        }
                      },
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
    required this.chatController,
    required this.chatFocusNode,
    required this.isReplying,
    required this.isCoachExpanded,
    required this.messages,
    required this.scrollController,
    required this.onToggleCoachExpanded,
    required this.onExpandCoach,
    required this.onSend,
  });

  final String miniMeName;
  final String userName;
  final AvatarStore avatarStore;
  final Color glow;
  final String? moodLabel;
  final String? moodEmoji;
  final String suggestionText;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final bool isReplying;
  final bool isCoachExpanded;
  final List<_MiniMeChatMessage> messages;
  final ScrollController scrollController;
  final VoidCallback onToggleCoachExpanded;
  final VoidCallback onExpandCoach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const collapsedComposerHeight = 96.0;
        const collapsedBottomInset = 20.0;
        const suggestionBubbleReserve = 72.0;
        final availableAvatarHeight =
            constraints.maxHeight -
            collapsedComposerHeight -
            collapsedBottomInset -
            suggestionBubbleReserve;
        final avatarSize = math.min(
          constraints.biggest.shortestSide * 1.04,
          availableAvatarHeight.clamp(320.0, 820.0),
        );

        return Stack(
          children: [
            IgnorePointer(
              ignoring: isCoachExpanded,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                opacity: isCoachExpanded ? 0 : 1,
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 18,
                      right: 18,
                      child: _AvatarSuggestionBubble(
                        text: 'Hi, ${_displayFirstName(userName)}',
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          4,
                          suggestionBubbleReserve - 8,
                          4,
                          collapsedComposerHeight + collapsedBottomInset - 10,
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
                            glow: glow,
                            size: avatarSize,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              top: isCoachExpanded ? 8 : constraints.maxHeight - 120,
              bottom: 12,
              child: IgnorePointer(
                ignoring: !isCoachExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isCoachExpanded ? 1 : 0,
                  child: Column(
                    children: [
                      Expanded(
                        child: _InlineCoachPanel(
                          miniMeName: miniMeName,
                          messages: messages,
                          isReplying: isReplying,
                          scrollController: scrollController,
                          moodLabel: moodLabel ?? 'Neutral',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CoachComposerCard(
                        miniMeName: miniMeName,
                        chatController: chatController,
                        chatFocusNode: chatFocusNode,
                        isCoachExpanded: isCoachExpanded,
                        isReplying: isReplying,
                        messageCount: messages.length,
                        onExpandCoach: onExpandCoach,
                        onSend: onSend,
                        onToggleCoachExpanded: onToggleCoachExpanded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isCoachExpanded)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: _CoachComposerCard(
                  miniMeName: miniMeName,
                  chatController: chatController,
                  chatFocusNode: chatFocusNode,
                  isCoachExpanded: isCoachExpanded,
                  isReplying: isReplying,
                  messageCount: messages.length,
                  onExpandCoach: onExpandCoach,
                  onSend: onSend,
                  onToggleCoachExpanded: onToggleCoachExpanded,
                ),
              ),
          ],
        );
      },
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
        constraints: const BoxConstraints(maxWidth: 260),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _InlineCoachPanel extends StatelessWidget {
  const _InlineCoachPanel({
    required this.miniMeName,
    required this.moodLabel,
    required this.isReplying,
    required this.messages,
    required this.scrollController,
  });

  final String miniMeName;
  final String moodLabel;
  final bool isReplying;
  final List<_MiniMeChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface.withValues(alpha: 0.98),
            cs.surfaceContainerHighest.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
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
                        ],
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
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
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    itemCount: messages.length + (isReplying ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isReplying && index == messages.length) {
                        return _TypingBubble(miniMeName: miniMeName);
                      }

                      final message = messages[index];
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
      ),
    );
  }
}

class _CoachComposerCard extends StatelessWidget {
  const _CoachComposerCard({
    required this.miniMeName,
    required this.chatController,
    required this.chatFocusNode,
    required this.isCoachExpanded,
    required this.isReplying,
    required this.messageCount,
    required this.onExpandCoach,
    required this.onSend,
    required this.onToggleCoachExpanded,
  });

  final String miniMeName;
  final TextEditingController chatController;
  final FocusNode chatFocusNode;
  final bool isCoachExpanded;
  final bool isReplying;
  final int messageCount;
  final VoidCallback onExpandCoach;
  final VoidCallback onSend;
  final VoidCallback onToggleCoachExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      miniMeName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      messageCount == 0
                          ? 'Ask for support, reflection, or your next step.'
                          : 'Continue the thread with $miniMeName.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CoachStatusPill(
                icon: Icons.forum_rounded,
                label: '$messageCount',
                background: cs.primaryContainer,
                foreground: cs.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onToggleCoachExpanded,
                tooltip: isCoachExpanded ? 'Hide guidance' : 'Show guidance',
                icon: Icon(
                  isCoachExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                    isDense: true,
                    filled: true,
                    fillColor: cs.surface.withValues(alpha: 0.72),
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
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isReplying ? null : onSend,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(54, 54),
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
  });

  final String miniMeName;
  final _MiniMeChatMessage message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bubbleColor = isUser
        ? cs.primaryContainer.withValues(alpha: 0.96)
        : cs.surface.withValues(alpha: 0.92);
    final borderColor = isUser
        ? cs.primary.withValues(alpha: 0.24)
        : cs.outlineVariant.withValues(alpha: 0.5);

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
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 6),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser ? cs.onPrimaryContainer : cs.onSurface,
                  height: 1.35,
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
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
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
