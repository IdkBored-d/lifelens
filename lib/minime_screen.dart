import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'moodlog_store.dart';
import './assets/minime/minime_avatar.dart';
import 'package:lifelens/utils/minime_helpers.dart';
import 'package:lifelens/services/daily_suggestions_service.dart';
import 'avatar_store.dart';
import 'avatar_customization_screen.dart';

class MiniMeScreen extends StatefulWidget {
  const MiniMeScreen({super.key});

  @override
  State<MiniMeScreen> createState() => _MiniMeScreenState();
}

class _MiniMeScreenState extends State<MiniMeScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  bool _isCoachExpanded = false;
  bool _isReplying = false;
  final List<_MiniMeChatMessage> _messages = [
    _MiniMeChatMessage(
      role: _ChatRole.assistant,
      text: 'Daily guidance is ready. Share what you want to improve and I will build a simple plan.',
    ),
  ];

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String moodLabel) async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isReplying) return;

    setState(() {
      _isCoachExpanded = true;
      _messages.add(_MiniMeChatMessage(role: _ChatRole.user, text: text));
      _isReplying = true;
    });
    _chatController.clear();
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 520));

    if (!mounted) return;

    final reply = _buildOfflineReply(userText: text, moodLabel: moodLabel);

    setState(() {
      _messages.add(_MiniMeChatMessage(role: _ChatRole.assistant, text: reply));
      _isReplying = false;
    });
    _scrollToBottom();
  }

  String _buildOfflineReply({required String userText, required String moodLabel}) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      appBar: AppBar(
        leading: canPop ? const BackButton() : null,
        title: const Text("Mini-Me"),
        actions: [
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
          final latest = moodStore.items.isEmpty ? null : moodStore.items.first;
          final intensity = latest?.intensity ?? 0;
          final moodLabel = latest?.moodLabel ?? 'Neutral';
          final glow = glowForIntensity(theme.colorScheme, intensity);

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surface,
                  cs.surfaceContainerHighest,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: FutureBuilder<List<DailySuggestion>>(
                      key: const ValueKey('avatar-panel'),
                      future: DailySuggestionsService.instance
                          .getDailySuggestions(moodLogs: moodStore.items),
                      builder: (context, snapshot) {
                        final defaultSuggestion = snapshot.connectionState ==
                                ConnectionState.waiting
                            ? 'I am preparing your suggestion...'
                            : 'Model not connected yet. Placeholder guidance is active.';

                        final suggestion = snapshot.data?.isNotEmpty == true
                            ? snapshot.data!.first.action
                            : defaultSuggestion;

                        return _AvatarPanel(
                          avatarStore: avatarStore,
                          glow: glow,
                          moodLabel: latest?.moodLabel,
                          moodEmoji: latest?.emoji,
                          suggestionText: suggestion,
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
                          onSend: () => _sendMessage(moodLabel),
                        );
                      },
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
        final avatarSize = (constraints.biggest.shortestSide * 0.82)
            .clamp(260.0, 700.0);

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
              bottom: isCoachExpanded ? 92 : 10,
              height: isCoachExpanded ? 220 : 0,
              child: IgnorePointer(
                ignoring: !isCoachExpanded,
                child: Opacity(
                  opacity: isCoachExpanded ? 1 : 0,
                  child: _InlineCoachPanel(
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
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withOpacity(0.45),
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
                          hintText: 'Type to Mini-Me...',
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mini-Me says',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            text,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ],
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
  const _SpeechTailPainter({required this.fillColor, required this.borderColor});

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
    required this.moodLabel,
    required this.isReplying,
    required this.messages,
    required this.scrollController,
  });

  final String moodLabel;
  final bool isReplying;
  final List<_MiniMeChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(Icons.psychology_alt_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guidance Center • Mood: $moodLabel',
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
              padding: const EdgeInsets.all(12),
              itemCount: messages.length + (isReplying ? 1 : 0),
              itemBuilder: (context, index) {
                if (isReplying && index == messages.length) {
                  return const _TypingBubble();
                }

                final message = messages[index];
                final isUser = message.role == _ChatRole.user;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? cs.tertiaryContainer.withOpacity(0.55)
                        : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUser
                          ? cs.tertiary.withOpacity(0.26)
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
                          Text(
                            isUser ? 'Your note' : 'Mini-Me guidance',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isUser
                                  ? cs.onTertiaryContainer
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser
                              ? cs.onTertiaryContainer
                              : cs.onSurface,
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
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

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
          Text(
            'Mini-Me is preparing your next step...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
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
