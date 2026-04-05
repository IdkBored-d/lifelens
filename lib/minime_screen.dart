import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lifelens/app_services.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';
import 'package:lifelens/utils/minime_helpers.dart';
import 'package:lifelens/services/streak_service.dart';
import 'package:lifelens/services/minime_shop_service.dart';
import 'package:lifelens/services/minime_backend_service.dart';
import 'package:lifelens/database/isar_service.dart';
import 'package:lifelens/database/mood_entry.dart';
import 'avatar_store.dart';
import 'avatar_customization_screen.dart';

class MiniMeScreen extends StatefulWidget {
  const MiniMeScreen({Key? key}) : super(key: key);
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
      _loadOpeningSuggestion();
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
    }
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
      _messages.add(_MiniMeChatMessage(role: _ChatRole.assistant, text: reply));
      _isReplying = false;
    });
    _scrollToBottom();
  }

  /// Tier 2: Gemini if online, else Tier 3: offline template.
  Future<String> _geminiOrOffline(String text, String moodLabel) async {
    if (await _isOnline()) {
      try {
        final response = await AppServices.gemini.generateMiniMeReply(
          userMessage: text,
          moodLabel: moodLabel,
        );
        // Gemini returns its fallback message on HTTP errors — treat as failure
        if (!response.startsWith('Unable to reach Gemini')) return response;
      } catch (_) {}
    }
    return _buildOfflineReply(userText: text, moodLabel: moodLabel);
  }

  static Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup(
        'generativelanguage.googleapis.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _buildOfflineReply({
    required String userText,
    required String moodLabel,
  }) {
    final q = userText.toLowerCase();

    if (q.contains('anx') || q.contains('stress')) {
      return 'Today\'s calming plan:\n1) 60-second body reset (jaw, shoulders, breath).\n2) Name one stress trigger in one sentence.\n3) Take one small action in the next 10 minutes.';
    }

    if (q.contains('sleep') || q.contains('tired')) {
      return 'Tonight\'s sleep plan:\n1) Set a 20-minute wind-down reminder.\n2) Reduce light and screens.\n3) Write one thought to clear your mind before bed.';
    }

    if (q.contains('plan') || q.contains('routine') || q.contains('organize')) {
      return 'Your structure for today:\n1) One mood check-in.\n2) One movement block.\n3) One sleep-support action.\nKeep it simple and repeatable.';
    }

    return 'Model connection is not live yet. Based on your latest mood ($moodLabel), tell me your focus area (mood, sleep, symptoms, or exercise) and I will draft a short plan.';
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
            tooltip: 'Day summary',
            onPressed: _isReplying ? null : _runDaySummary,
            icon: const Icon(Icons.insights_rounded),
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
        final avatarSize = (constraints.biggest.shortestSide * 0.82).clamp(
          260.0,
          700.0,
        );

        return Stack(
          children: [
            Positioned(
              top: 6,
              left: 18,
              right: 18,
              child: _AvatarSuggestionBubble(text: suggestionText),
            ),
            Center(
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
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              left: 16,
              right: 16,
              bottom: isCoachExpanded ? 106 : 12,
              height: isCoachExpanded ? 252 : 0,
              child: IgnorePointer(
                ignoring: !isCoachExpanded,
                child: Opacity(
                  opacity: isCoachExpanded ? 1 : 0,
                  child: _InlineCoachPanel(
                    miniMeName: miniMeName,
                    messages: messages,
                    isReplying: isReplying,
                    scrollController: scrollController,
                    moodLabel: moodLabel ?? 'Neutral',
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withOpacity(0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onToggleCoachExpanded,
                      icon: Icon(
                        isCoachExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                      ),
                      tooltip: isCoachExpanded
                          ? 'Hide guidance'
                          : 'Show guidance',
                    ),
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
                          hintText: 'Type to $miniMeName...',
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: isReplying ? null : onSend,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                  ],
                ),
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
    final bubbleColor = cs.primaryContainer.withOpacity(0.92);
    final bubbleBorder = cs.primary.withOpacity(0.32);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: bubbleBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        textScaleFactor: 0.95,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 2,
                left: 36,
                child: CustomPaint(
                  size: const Size(20, 14),
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
      ..moveTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..lineTo(7, size.height)
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
        color: cs.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.psychology_alt_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$miniMeName Guidance • Mood: $moodLabel',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              itemCount: messages.length + (isReplying ? 1 : 0),
              itemBuilder: (context, index) {
                if (isReplying && index == messages.length) {
                  return _TypingBubble(miniMeName: miniMeName);
                }

                final message = messages[index];
                final isUser = message.role == _ChatRole.user;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? cs.primaryContainer.withOpacity(0.85)
                        : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUser
                          ? cs.primary.withOpacity(0.22)
                          : cs.outlineVariant.withOpacity(0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isUser
                                ? Icons.edit_note_rounded
                                : Icons.psychology_alt_rounded,
                            size: 16,
                            color: isUser
                                ? cs.onTertiaryContainer
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isUser ? 'Your note' : '$miniMeName guidance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isUser
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.text,
                        maxLines: null,
                        softWrap: true,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser ? cs.onPrimaryContainer : cs.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
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

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.miniMeName});

  final String miniMeName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$miniMeName is preparing your next step...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
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
        color: cs.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
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
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: FutureBuilder<MiniMeShopState>(
          future: _stateFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final state = snapshot.data!;

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Mini-Me Shop',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.monetization_on_rounded,
                              size: 16,
                              color: cs.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${state.coins}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.lastReward.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: state.lastReward.rewarded
                            ? cs.tertiaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.lastReward.rewarded
                              ? cs.tertiary.withOpacity(0.35)
                              : cs.outlineVariant.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        state.lastReward.rewarded
                            ? '+${state.lastReward.amount} coins • ${state.lastReward.message}'
                            : state.lastReward.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: state.lastReward.rewarded
                              ? cs.onTertiaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      final unlocked = state.unlockedIds.contains(item.id);
                      final equipped = unlocked && _isEquipped(item);
                      final canBuy = state.coins >= item.cost;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.surfaceContainerHighest,
                              cs.surfaceContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: equipped
                                ? cs.primary
                                : cs.outlineVariant.withOpacity(0.4),
                            width: equipped ? 1.4 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.shadow.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _itemAccent(item, cs).withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _itemIcon(item),
                                color: _itemAccent(item, cs),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _itemAccent(
                                            item,
                                            cs,
                                          ).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _itemTypeLabel(item.type),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: _itemAccent(item, cs),
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (equipped)
                              FilledButton(
                                onPressed: null,
                                child: const Text('Equipped'),
                              )
                            else if (unlocked)
                              FilledButton(
                                onPressed: () => _equip(item),
                                child: const Text('Equip'),
                              )
                            else
                              FilledButton.tonal(
                                onPressed: canBuy
                                    ? () => _unlock(item.id)
                                    : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.monetization_on_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${item.cost}'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
        return 'Hair';
      case MiniMeItemType.shirt:
        return 'Outfit';
      case MiniMeItemType.bodyScale:
        return 'Stance';
    }
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
