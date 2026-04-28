import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:lifelens/shared_widgets/mini_me_avatar_badge.dart';
import 'package:provider/provider.dart';

import '../avatar_store.dart';
import '../models/sphere.dart';
import '../services/content_moderation_service.dart';
import '../services/exercise_store.dart';
import '../sleep_store.dart';

class SphereChatScreen extends StatefulWidget {
  const SphereChatScreen({super.key, required this.sphere});

  final Sphere sphere;

  @override
  State<SphereChatScreen> createState() => _SphereChatScreenState();
}

class _SphereChatScreenState extends State<SphereChatScreen>
    with SingleTickerProviderStateMixin {
  static const int _fallbackChatSeedVersion = 7;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ExerciseStore _exerciseStore = ExerciseStore();

  String? _userNickname;
  bool _isBootstrapping = true;
  bool _isSendingPost = false;
  _ReplyTarget? _composerReplyTarget;
  int _activeChatSeedVersion = 0;
  static const double _maxTimeRevealOffset = 76.0;
  double _timeRevealOffset = 0.0;
  late final AnimationController _timeRevealController;

  DocumentReference<Map<String, dynamic>> get _sphereRef =>
      FirebaseFirestore.instance.collection('spheres').doc(widget.sphere.id);

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _sphereRef.collection('posts');

  CollectionReference<Map<String, dynamic>> get _membersRef =>
      _sphereRef.collection('members');

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream =
      _postsRef.orderBy('createdAt', descending: true).snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream =
      _membersRef.snapshots();

  bool get _isSleepSphere {
    final normalized = widget.sphere.name.trim().toLowerCase();
    return normalized == 'sleep' || normalized.contains('sleep');
  }

  bool get _isExerciseSphere {
    final normalized = widget.sphere.name.trim().toLowerCase();
    return normalized == 'exercise' || normalized.contains('exercise');
  }

  String? get _bannerUrl {
    final raw = widget.sphere.bannerUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isDataImageUrl(raw)) return raw;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    final isWeb = parsed.scheme == 'http' || parsed.scheme == 'https';
    if (!isWeb || parsed.host.isEmpty) return null;
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _timeRevealController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final next = _timeRevealController.value
            .clamp(0.0, _maxTimeRevealOffset)
            .toDouble();
        if (next == _timeRevealOffset || !mounted) return;
        setState(() {
          _timeRevealOffset = next;
        });
      });
    _bootstrapSphere();
  }

  Future<void> _bootstrapSphere() async {
    try {
      await _exerciseStore.ensureReady();
      await _loadSphereSeedConfig();
      await _loadUserNickname();
      await _syncMemberMiniMe();
      await _ensureSphereStarterContent();
      await _markSphereSeen();
    } catch (e) {
      if (e is! FirebaseException || e.code != 'permission-denied') {
        rethrow;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some sphere updates are restricted by permissions. Loading available content.',
            ),
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => _isBootstrapping = false);
    }
  }

  Future<void> _loadSphereSeedConfig() async {
    final sphereDoc = await _sphereRef.get();
    final data = sphereDoc.data();
    final configuredSeed =
        (data?['chatSeedVersion'] as num?)?.toInt() ??
        (data?['dummySeedVersion'] as num?)?.toInt() ??
        _fallbackChatSeedVersion;

    if (!mounted) return;
    setState(() {
      _activeChatSeedVersion = configuredSeed;
    });
  }

  Future<void> _loadUserNickname() async {
    final userId = _userId;
    if (userId == null) return;

    final memberDoc = await _membersRef.doc(userId).get();
    if (!memberDoc.exists || !mounted) return;

    setState(() {
      _userNickname = memberDoc.data()?['nickname'] as String?;
    });
  }

  void _handleTimelineRevealDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    if (delta == 0) return;

    if (_timeRevealController.isAnimating) {
      _timeRevealController.stop();
    }

    final adjustment = -delta;
    final next = (_timeRevealOffset + adjustment).clamp(
      0.0,
      _maxTimeRevealOffset,
    );
    if (next == _timeRevealOffset) return;
    _timeRevealController.value = next;
  }

  void _resetTimelineReveal() {
    if (_timeRevealOffset == 0.0) return;
    if (_timeRevealController.isAnimating) {
      _timeRevealController.stop();
    }
    final spring = SpringSimulation(
      const SpringDescription(mass: 1.0, stiffness: 320.0, damping: 28.0),
      _timeRevealOffset,
      0.0,
      -6.0,
    );
    _timeRevealController.animateWith(spring);
  }

  Future<void> _ensureSphereStarterContent() async {
    // Keep sphere chats empty by default unless users post manually.
    return;
  }

  Future<void> _markSphereSeen() async {
    final userId = _userId;
    if (userId == null) return;
    final doc = await _membersRef.doc(userId).get();
    if (!doc.exists) return;
    await _membersRef.doc(userId).update({
      'lastReadAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _touchMemberActivity() async {
    final userId = _userId;
    if (userId == null) return;
    final doc = await _membersRef.doc(userId).get();
    if (!doc.exists) return;
    await _membersRef.doc(userId).update({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'lastReadAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _syncMemberMiniMe() async {
    final userId = _userId;
    if (userId == null) return;
    final doc = await _membersRef.doc(userId).get();
    if (!doc.exists) return;
    final avatarStore = context.read<AvatarStore>();
    await _membersRef.doc(userId).update({
      'miniMe': avatarStore.toCommunityAvatarMap(),
      'miniMeName': avatarStore.miniMeName,
    });
  }

  Future<void> _createPost({
    required String type,
    required String text,
    _ReplyTarget? replyTarget,
    Map<String, dynamic>? extraData,
  }) async {
    final userId = _userId;
    final nickname = _userNickname;
    final avatarStore = context.read<AvatarStore>();
    if (userId == null || nickname == null) return;

    final moderationResult = ContentModerationService.checkMessage(text);
    if (moderationResult.isViolation) {
      await _handleContentViolation(
        userId,
        text,
        moderationResult.detectedWords,
      );
      return;
    }

    await _postsRef.add({
      'type': type,
      'text': text,
      'userId': userId,
      'nickname': nickname,
      'seedVersion': _activeChatSeedVersion,
      'miniMe': avatarStore.toCommunityAvatarMap(),
      'miniMeName': avatarStore.miniMeName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'latestActivityAt': FieldValue.serverTimestamp(),
      'replyCount': 0,
      'reactionCounts': <String, int>{},
      'isPinned': false,
      if (extraData != null) ...extraData,
      if (replyTarget != null) ...{
        'replyToPostId': replyTarget.postId,
        'replyToUserId': replyTarget.userId,
        'replyToUserName': replyTarget.userName,
        'replyToText': _trimForReplyPreview(replyTarget.text),
      },
    });

    await _sphereRef.set({
      'lastActivityText': text,
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _touchMemberActivity();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared with the sphere')),
    );
  }

  void _focusInlineComposer() {
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_composerFocusNode);
  }

  Future<void> _submitInlinePost() async {
    if (_isSendingPost) return;

    final message = _composerController.text.trim();
    if (message.isEmpty) return;

    if (_userNickname == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join with a nickname to post.')),
      );
      return;
    }

    setState(() => _isSendingPost = true);
    try {
      await _createPost(
        type: 'check_in',
        text: message,
        replyTarget: _composerReplyTarget,
      );
      if (!mounted) return;
      setState(() {
        _composerController.clear();
        _composerReplyTarget = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isSendingPost = false);
      }
    }
  }

  Future<void> _showQuickShareOptions() async {
    if (_isSendingPost) return;
    if (_userNickname == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join with a nickname to post.')),
      );
      return;
    }

    final action = await showModalBottomSheet<_QuickShareAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Milestone'),
                subtitle: const Text('Share a personal win'),
                onTap: () => Navigator.of(context).pop(_QuickShareAction.milestone),
              ),
              if (_isSleepSphere)
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Sleep help request'),
                  subtitle: const Text('Only for rough nights (under 6 hours)'),
                  onTap: () => Navigator.of(context).pop(_QuickShareAction.sleepHelp),
                ),
              if (_isExerciseSphere)
                ListTile(
                  leading: const Icon(Icons.fitness_center_outlined),
                  title: const Text('Share exercise log'),
                  subtitle: const Text('Post your latest exercise entry'),
                  onTap: () => Navigator.of(context).pop(_QuickShareAction.exercise),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _QuickShareAction.milestone:
        await _showMilestoneAchievementModal();
      case _QuickShareAction.sleepHelp:
        await _shareSleepHelpRequest();
      case _QuickShareAction.exercise:
        await _shareLatestExerciseLog();
    }
  }

  Future<void> _showMilestoneAchievementModal() async {
    String title = '';
    String description = '';
    String? errorText;

    final draft = await showModalBottomSheet<_MilestoneCardDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievement card',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fill out each box, then post your milestone to the sphere.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 14),
                      _MilestoneInputField(
                        label: 'Achievement title',
                        hint: 'Ex: 7-day mood logging streak',
                        maxLines: 1,
                        onChanged: (value) => title = value,
                      ),
                      const SizedBox(height: 10),
                      _MilestoneInputField(
                        label: 'Short description',
                        hint: 'What made this achievement meaningful?',
                        onChanged: (value) => description = value,
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            final safeTitle = title.trim();
                            final safeDescription = description.trim();
                            if (safeTitle.isEmpty || safeDescription.isEmpty) {
                              setModalState(() {
                                errorText = 'Please fill out all boxes before sharing.';
                              });
                              return;
                            }
                            Navigator.of(modalContext).pop(
                              _MilestoneCardDraft(
                                title: safeTitle,
                                description: safeDescription,
                              ),
                            );
                          },
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: const Text('Share achievement card'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || draft == null) return;

    final text = 'Achievement unlocked: ${draft.title}';
    await _postQuickShare(
      type: 'milestone_card',
      text: text,
      extraData: {
        'milestoneCardKind': 'achievement',
        'milestoneTitle': draft.title,
        'milestoneDescription': draft.description,
      },
    );
  }

  Future<void> _shareSleepHelpRequest() async {
    if (!_isSleepSphere) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep help requests can only be shared in the Sleep sphere.')),
      );
      return;
    }

    final sleepStore = context.read<SleepStore>();
    if (sleepStore.items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sleep logs yet for a help request.')),
      );
      return;
    }

    final latest = sleepStore.items.first;
    final bedLabel = TimeOfDay.fromDateTime(latest.bedTime).format(context);
    final wakeLabel = TimeOfDay.fromDateTime(latest.wakeTime).format(context);
    final durationHours = latest.duration.inMinutes / 60.0;
    if (durationHours >= 6.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sleep help request is only for short sleep nights (under 6 hours).'),
        ),
      );
      return;
    }
    final ask = durationHours < 6.0
        ? 'Any tips to fall asleep earlier without feeling wired?'
        : 'Any tips to make sleep deeper and less interrupted?';
    final text =
        'Sleep help request: I slept ${latest.durationFormatted} (${latest.quality.label.toLowerCase()}) '
        'from $bedLabel to $wakeLabel. $ask';

    await _postQuickShare(
      type: 'sleep_help_request',
      text: text,
      extraData: {
        'sleepCardKind': 'help',
        'restDuration': latest.durationFormatted,
        'restQuality': latest.quality.label,
        'restBedTime': bedLabel,
        'restWakeTime': wakeLabel,
        'restHours': durationHours,
        'restAsk': ask,
      },
    );
  }

  Future<void> _shareLatestExerciseLog() async {
    if (!_isExerciseSphere) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise logs can only be shared in the Exercise sphere.')),
      );
      return;
    }

    await _exerciseStore.ensureReady();
    final history = _exerciseStore.getRecentExerciseHistory(limit: 1);
    if (history.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exercise logs yet to share.')),
      );
      return;
    }

    final latest = history.first;
    final noExercise = (latest['noExercise'] ?? '').trim() == 'true';
    final name = (latest['exerciseName'] ?? '').trim();
    final duration = (latest['durationMinutes'] ?? '').trim();
    final sets = (latest['sets'] ?? '').trim();
    final reps = (latest['reps'] ?? '').trim();
    final workoutItems = _decodeExerciseWorkoutItems(
      (latest['workoutItemsJson'] ?? '').trim(),
    );
    final exerciseItems = workoutItems
        .map(
          (item) => <String, dynamic>{
            'name': item.name,
            'sets': item.sets,
            'reps': item.reps,
            'durationMinutes': item.durationMinutes,
          },
        )
        .toList(growable: false);

    final detail = noExercise
        ? 'No workout today, focusing on recovery.'
        : workoutItems.isNotEmpty
        ? workoutItems
              .take(3)
              .map(
                (item) =>
                    '${item.name}${item.sets > 0 && item.reps > 0 ? ' (${item.sets}x${item.reps})' : ''}',
              )
              .join(' • ')
        : [
            if (name.isNotEmpty) name,
            if (duration.isNotEmpty) '$duration min',
            if (sets.isNotEmpty && reps.isNotEmpty) '$sets sets x $reps reps',
          ].join(' • ');

    final text = workoutItems.isNotEmpty
      ? detail
      : detail.isEmpty
      ? 'Exercise log: Completed a workout session.'
      : 'Exercise log: $detail';

    await _postQuickShare(
      type: 'exercise_log',
      text: text,
      extraData: {
        'exerciseCardKind': 'log',
        'exerciseItems': workoutItems.isNotEmpty
            ? exerciseItems
            : [
                {
                  'name': name,
                  'sets': int.tryParse(sets) ?? 0,
                  'reps': int.tryParse(reps) ?? 0,
                  'durationMinutes': int.tryParse(duration) ?? 0,
                },
              ],
        'exerciseCount': workoutItems.isNotEmpty ? workoutItems.length : 1,
        'noExercise': noExercise,
      },
    );
  }

  Future<void> _postQuickShare({
    required String type,
    required String text,
    Map<String, dynamic>? extraData,
  }) async {
    if (_isSendingPost || text.trim().isEmpty) return;
    setState(() => _isSendingPost = true);
    try {
      await _createPost(type: type, text: text.trim(), extraData: extraData);
    } finally {
      if (mounted) {
        setState(() => _isSendingPost = false);
      }
    }
  }

  Future<void> _reportPost({
    required String postId,
    required String text,
    required String reason,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await _sphereRef.collection('reports').add({
      'postId': postId,
      'sphereId': widget.sphere.id,
      'reportedBy': userId,
      'reason': reason,
      'textPreview': text.length > 140 ? '${text.substring(0, 140)}...' : text,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report submitted')));
  }

  Future<void> _deletePost(String postId) async {
    final postRef = _postsRef.doc(postId);
    final postSnapshot = await postRef.get();
    final sphereSnapshot = await _sphereRef.get();
    final pinnedPostId = sphereSnapshot.data()?['pinnedPostId'] as String?;

    final replies = await postRef.collection('replies').get();
    for (final reply in replies.docs) {
      await reply.reference.delete();
    }

    final reactions = await postRef.collection('reactions').get();
    for (final reaction in reactions.docs) {
      await reaction.reference.delete();
    }

    await postRef.delete();
    if (pinnedPostId == postId || postSnapshot.data()?['isPinned'] == true) {
      await _sphereRef.set({
        'pinnedTitle': 'Community focus',
        'pinnedBody':
            widget.sphere.pinnedBody ??
            'Introduce yourself, protect your privacy, and keep replies practical and kind.',
        'pinnedPostId': null,
      }, SetOptions(merge: true));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post deleted')));
  }

  Future<void> _handleContentViolation(
    String userId,
    String messageContent,
    List<String> detectedWords,
  ) async {
    try {
      final memberRef = _membersRef.doc(userId);
      final memberDoc = await memberRef.get();
      final currentWarnings = memberDoc.data()?['warningCount'] ?? 0;
      final newWarningCount = currentWarnings + 1;

      await _sphereRef.collection('warnings').add({
        'userId': userId,
        'sphereId': widget.sphere.id,
        'timestamp': FieldValue.serverTimestamp(),
        'reason': 'Inappropriate content: ${detectedWords.join(", ")}',
        'messageContent': messageContent,
        'warningNumber': newWarningCount,
      });

      if (newWarningCount >= 3) {
        await _kickUserFromSphere(userId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ContentModerationService.getViolationMessage(newWarningCount),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      } else {
        await memberRef.set({
          'warningCount': newWarningCount,
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ContentModerationService.getViolationMessage(newWarningCount),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing moderation: $e')),
      );
    }
  }

  Future<void> _kickUserFromSphere(String userId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final sphereDoc = await transaction.get(_sphereRef);
        final memberRef = _membersRef.doc(userId);
        final memberDoc = await transaction.get(memberRef);
        if (!memberDoc.exists) return;
        final currentCount = (sphereDoc.data()?['memberCount'] as int?) ?? 0;
        transaction.delete(memberRef);
        transaction.update(_sphereRef, {
          'memberCount': currentCount > 0 ? currentCount - 1 : 0,
        });
      });
      await _sphereRef.collection('moderation_actions').add({
        'action': 'kicked',
        'userId': userId,
        'reason': 'Exceeded warning limit (3 warnings)',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error kicking user: $e');
    }
  }

  void _showReportDialog({required String postId, required String text}) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason for report...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              await _reportPost(postId: postId, text: text, reason: reason);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showMembersSheet() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.62,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.sphere.name} members',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _membersRef.orderBy('joinedAt').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final memberId = members[index].id;
                        final isMe = memberId == _userId;
                        final member = members[index].data();
                        final memberNickname = member['nickname'] as String?;
                        final displayNickname = isMe ? 'You' : (memberNickname ?? 'Anonymous');
                        final miniMe = Map<String, dynamic>.from(
                          member['miniMe'] as Map? ?? {},
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: MiniMeAvatarBadge(
                            size: 52,
                            padding: 4,
                            backgroundColor: cs.primaryContainer,
                            borderColor: cs.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                            bodyModel: miniMe['bodyModel'] as String?,
                            hairModel: miniMe['hairModel'] as String?,
                            shirtModel: miniMe['shirtModel'] as String?,
                            bodyWidthScale: (miniMe['bodyWidthScale'] as num?)
                                ?.toDouble(),
                            companionId: miniMe['companionId'] as String?,
                            isHatched: miniMe['isHatched'] as bool? ?? true,
                            degradationLevel:
                                (miniMe['degradationLevel'] as num?)
                                    ?.toDouble() ??
                                0,
                            fallbackLabel: memberNickname,
                          ),
                          title: Text(displayNickname),
                          subtitle: Text(
                            'Joined ${_timeLabel((member['joinedAt'] as Timestamp?)?.toDate())}',
                          ),
                          trailing: (member['role'] ?? 'member') == 'owner'
                              ? const Text('Owner')
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangeNicknameDialog() {
    final nicknameController = TextEditingController(text: _userNickname);
    final cs = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Nickname'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: $_userNickname',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'DO NOT use your real name',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(
                hintText: 'Enter new nickname...',
              ),
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newNickname = nicknameController.text.trim();
              if (newNickname.isEmpty) return;
              Navigator.pop(context);
              await _changeNickname(newNickname);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeNickname(String newNickname) async {
    final userId = _userId;
    if (userId == null) return;

    final avatarStore = context.read<AvatarStore>();
    await _membersRef.doc(userId).update({
      'nickname': newNickname,
      'miniMe': avatarStore.toCommunityAvatarMap(),
      'miniMeName': avatarStore.miniMeName,
    });
    if (!mounted) return;
    setState(() => _userNickname = newNickname);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nickname updated successfully')),
    );
  }

  void _showLeaveSphereDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Sphere'),
        content: Text(
          'Are you sure you want to leave "${widget.sphere.name}"? You can rejoin anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveSphere();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveSphere() async {
    final userId = _userId;
    if (userId == null) return;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final sphereDoc = await transaction.get(_sphereRef);
      final memberRef = _membersRef.doc(userId);
      final memberDoc = await transaction.get(memberRef);
      if (!memberDoc.exists) return;
      final currentCount = (sphereDoc.data()?['memberCount'] as int?) ?? 0;
      transaction.delete(memberRef);
      transaction.update(_sphereRef, {
        'memberCount': currentCount > 0 ? currentCount - 1 : 0,
      });
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Left sphere successfully')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sphere.name),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _membersStream,
              builder: (context, snapshot) {
                final count =
                    snapshot.data?.docs.length ?? widget.sphere.memberCount;
                return Text(
                  '$count members',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Members',
            onPressed: _showMembersSheet,
            icon: const Icon(Icons.groups_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'change_nickname') {
                _showChangeNicknameDialog();
              } else if (value == 'leave_sphere') {
                _showLeaveSphereDialog();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'change_nickname',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 12),
                    Text('Change Nickname'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'leave_sphere',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app_outlined),
                    SizedBox(width: 12),
                    Text('Leave Sphere'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_bannerUrl != null || _defaultChatBannerPaletteForSphere(widget.sphere.name) != null)
                  SizedBox(
                    width: double.infinity,
                    height: 170,
                    child: _bannerUrl != null
                        ? _SphereChatBannerImage(imageSource: _bannerUrl!)
                        : _DefaultSphereChatBanner(sphereName: widget.sphere.name),
                  ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _handleTimelineRevealDragUpdate,
                    onHorizontalDragEnd: (_) => _resetTimelineReveal(),
                    onHorizontalDragCancel: _resetTimelineReveal,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _postsStream,
                      builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final seededPosts = snapshot.data!.docs.where((doc) {
                        final data = doc.data();
                        final seedVersion =
                            (data['seedVersion'] as num?)?.toInt() ?? -1;
                        if (_activeChatSeedVersion > 0 &&
                            seedVersion != _activeChatSeedVersion) {
                          return false;
                        }
                        return true;
                      }).toList(growable: false);
                        final posts = seededPosts;
                      if (posts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                          child: _EmptyCommunityState(
                            sphereName: widget.sphere.name,
                            onCreatePost: _focusInlineComposer,
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final postDoc = posts[index];
                          final postData = postDoc.data();
                          final postType =
                              (postData['type'] ?? 'check_in').toString();

                          if (postType == 'system_join') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SystemEventNotice(
                                text: (postData['text'] ?? '').toString(),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChatMessageTile(
                              postDoc: postDoc,
                              currentUserId: _userId,
                              timeRevealOffset: _timeRevealOffset,
                              onReply: () {
                                final postData = postDoc.data();
                                final replyTargetName =
                                    (postData['nickname'] ??
                                            postData['miniMeName'] ??
                                            'friend')
                                        .toString();
                                final replyTarget = _ReplyTarget(
                                  postId: postDoc.id,
                                  userId:
                                      (postData['userId'] ?? '').toString(),
                                  userName: replyTargetName,
                                  text: (postData['text'] ?? '').toString(),
                                );
                                setState(
                                  () => _composerReplyTarget = replyTarget,
                                );
                                _focusInlineComposer();
                              },
                              onReport: () => _showReportDialog(
                                postId: postDoc.id,
                                text: postDoc.data()['text'] ?? '',
                              ),
                              onDelete: () => _deletePost(postDoc.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ),
                ),
                _ComposerDock(
                  userNickname: _userNickname,
                  controller: _composerController,
                  focusNode: _composerFocusNode,
                  replyTarget: _composerReplyTarget,
                  isSending: _isSendingPost,
                  onChanged: (_) => setState(() {}),
                  onOpenQuickShare: _showQuickShareOptions,
                  onSend: _submitInlinePost,
                  onCancelReply: () {
                    setState(() => _composerReplyTarget = null);
                  },
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _timeRevealController.dispose();
    _scrollController.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }
}

class _EmptyCommunityState extends StatelessWidget {
  const _EmptyCommunityState({
    required this.sphereName,
    required this.onCreatePost,
  });

  final String sphereName;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'No posts yet in $sphereName',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with a simple message.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreatePost,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Send First Message'),
          ),
        ],
      ),
    );
  }
}

class _ComposerDock extends StatelessWidget {
  const _ComposerDock({
    required this.userNickname,
    required this.controller,
    required this.focusNode,
    required this.replyTarget,
    required this.isSending,
    required this.onChanged,
    required this.onOpenQuickShare,
    required this.onSend,
    required this.onCancelReply,
  });

  final String? userNickname;
  final TextEditingController controller;
  final FocusNode focusNode;
  final _ReplyTarget? replyTarget;
  final bool isSending;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenQuickShare;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canType = userNickname != null;
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyTarget != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ReplyReferenceSnippet(
                            title: 'Replying to ${replyTarget!.userName}',
                            text: _trimForReplyPreview(replyTarget!.text),
                            lineColor: cs.primary,
                            compact: true,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: onCancelReply,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        tooltip: 'Share options',
                        onPressed: (isSending || !canType)
                            ? null
                            : onOpenQuickShare,
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: canType ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: canType && !isSending,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: onChanged,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: canType
                                ? 'Write a message...'
                                : 'Join with a nickname to post',
                            border: InputBorder.none,
                            isDense: true,
                            hintStyle: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          style: TextStyle(color: cs.onSurface),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 170),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                        child: hasText
                            ? IconButton.filled(
                                key: const ValueKey('send_button'),
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    (isSending || !canType) ? null : onSend,
                                icon: isSending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                              )
                            : const SizedBox(
                                key: ValueKey('send_placeholder'),
                                width: 8,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemEventNotice extends StatelessWidget {
  const _SystemEventNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.postDoc,
    required this.currentUserId,
    required this.timeRevealOffset,
    required this.onReply,
    required this.onReport,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> postDoc;
  final String? currentUserId;
  final double timeRevealOffset;
  final VoidCallback onReply;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  static const List<String> _quickReactionEmojis = <String>[
    '❤️',
    '👍',
    '👏',
    '🙏',
    '💪',
    '🔥',
    '😊',
    '😮',
    '😢',
    '🤝',
  ];

  Future<void> _showMessageActions(
    BuildContext context, {
    required bool isMine,
    required String text,
  }) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () => Navigator.of(context).pop(_MessageAction.reply),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () => Navigator.of(context).pop(_MessageAction.copy),
              ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Delete'),
                  onTap: () =>
                      Navigator.of(context).pop(_MessageAction.delete),
                ),
              if (!isMine)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report'),
                  onTap: () =>
                      Navigator.of(context).pop(_MessageAction.report),
                ),
            ],
          ),
        );
      },
    );

    if (action == null) return;

    switch (action) {
      case _MessageAction.reply:
        onReply();
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message copied')),
          );
        }
      case _MessageAction.delete:
        onDelete();
      case _MessageAction.report:
        onReport();
    }
  }

  Future<void> _showReactionPicker(
    BuildContext context, {
    required String? activeEmoji,
  }) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final platform = Theme.of(context).platform;
        final isApple =
            platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

        final categoryIcons = isApple
            ? const CategoryIcons(
                recentIcon: CupertinoIcons.clock,
                smileyIcon: CupertinoIcons.smiley,
                animalIcon: CupertinoIcons.paw,
                foodIcon: CupertinoIcons.flame,
                activityIcon: CupertinoIcons.sportscourt,
                travelIcon: CupertinoIcons.car_detailed,
                objectIcon: CupertinoIcons.lightbulb,
                symbolIcon: CupertinoIcons.number,
                flagIcon: CupertinoIcons.flag,
              )
            : const CategoryIcons();

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: Container(
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'React with an emoji',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Browse all emojis or tap a quick reaction.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickReactionEmojis.map((emoji) {
                          final selected = emoji == activeEmoji;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).pop(emoji),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: selected
                                      ? cs.primaryContainer.withValues(alpha: 0.7)
                                      : cs.surfaceContainerHighest.withValues(
                                          alpha: 0.55,
                                        ),
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: EmojiPicker(
                        onEmojiSelected: (_, selected) {
                          Navigator.of(context).pop(selected.emoji);
                        },
                        config: Config(
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 7,
                            emojiSizeMax: 28,
                            backgroundColor: cs.surface,
                            noRecents: Text(
                              'No recents',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                          categoryViewConfig: CategoryViewConfig(
                            backgroundColor: cs.surface,
                            indicatorColor: cs.primary,
                            iconColor: cs.onSurfaceVariant,
                            iconColorSelected: cs.primary,
                            backspaceColor: cs.primary,
                            categoryIcons: categoryIcons,
                          ),
                          searchViewConfig: SearchViewConfig(
                            backgroundColor: cs.surface,
                            buttonIconColor: cs.onSurfaceVariant,
                            hintTextStyle: TextStyle(
                              color: cs.onSurfaceVariant,
                            ),
                            inputTextStyle: TextStyle(color: cs.onSurface),
                          ),
                          bottomActionBarConfig: BottomActionBarConfig(
                            backgroundColor: cs.surface,
                            buttonColor: cs.surfaceContainerHighest,
                            buttonIconColor: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (emoji == null || currentUserId == null) return;

    final postRef = postDoc.reference;
    final reactionRef = postRef.collection('reactions').doc(currentUserId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final postSnapshot = await tx.get(postRef);
        final reactionSnapshot = await tx.get(reactionRef);

        if (!postSnapshot.exists) return;

        final postData = postSnapshot.data() ?? <String, dynamic>{};
        final rawCounts = Map<String, dynamic>.from(
          postData['reactionCounts'] as Map? ?? {},
        );
        final counts = rawCounts.map(
          (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
        );

        final previousEmoji =
            (reactionSnapshot.data()?['emoji'] as String?)?.trim();

        if (previousEmoji == emoji) {
          tx.delete(reactionRef);
          final previousCount = (counts[emoji] ?? 0) - 1;
          if (previousCount <= 0) {
            counts.remove(emoji);
          } else {
            counts[emoji] = previousCount;
          }
        } else {
          tx.set(reactionRef, {
            'emoji': emoji,
            'userId': currentUserId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (previousEmoji != null && previousEmoji.isNotEmpty) {
            final previousCount = (counts[previousEmoji] ?? 0) - 1;
            if (previousCount <= 0) {
              counts.remove(previousEmoji);
            } else {
              counts[previousEmoji] = previousCount;
            }
          }

          counts[emoji] = (counts[emoji] ?? 0) + 1;
        }

        tx.update(postRef, {
          'reactionCounts': counts,
          'updatedAt': FieldValue.serverTimestamp(),
          'latestActivityAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update reaction right now')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.7;
    final data = postDoc.data();
    final isMine = data['userId'] == currentUserId;
    final miniMe = Map<String, dynamic>.from(data['miniMe'] as Map? ?? {});
    final postType = (data['type'] ?? 'check_in').toString();
    final rawDisplayName = (data['nickname'] ?? data['miniMeName'] ?? 'Anonymous')
        .toString();
    final displayName = isMine ? 'You' : rawDisplayName;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final text = (data['text'] ?? '').toString();
    final replyToUserName = (data['replyToUserName'] ?? '').toString().trim();
    final replyToText = (data['replyToText'] ?? '').toString().trim();
    final reactionCounts = Map<String, int>.fromEntries(
      Map<String, dynamic>.from(data['reactionCounts'] as Map? ?? {}).entries
          .map(
            (entry) => MapEntry(entry.key, (entry.value as num?)?.toInt() ?? 0),
          )
          .where((entry) => entry.value > 0),
    );

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMine ? 20 : 8),
          bottomRight: Radius.circular(isMine ? 8 : 20),
        ),
        onLongPress: () => _showMessageActions(
          context,
          isMine: isMine,
          text: text,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isMine
                ? cs.primaryContainer
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 8),
              bottomRight: Radius.circular(isMine ? 8 : 20),
            ),
            border: Border.all(
              color: isMine
                  ? cs.primary.withValues(alpha: 0.16)
                  : cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (replyToText.isNotEmpty)
                _ReplyReferenceSnippet(
                  title: replyToUserName.isEmpty
                      ? 'Reply'
                      : 'Reply to $replyToUserName',
                  text: replyToText,
                  lineColor: isMine
                      ? cs.primary.withValues(alpha: 0.8)
                      : cs.tertiary.withValues(alpha: 0.75),
                  compact: true,
                ),
              if (replyToText.isNotEmpty) const SizedBox(height: 8),
              if (postType == 'sleep_log' ||
                  postType == 'rest_check_in' ||
                  postType == 'sleep_help_request')
                _SleepLogPostContent(data: data, isMine: isMine)
              else if (postType == 'exercise_log')
                _ExerciseLogPostContent(data: data, isMine: isMine, fallbackText: text)
              else if (postType == 'milestone_card')
                _MilestoneAchievementCard(data: data, isMine: isMine)
              else
                Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.3,
                    color: isMine ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final reactionsRow = reactionCounts.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: reactionCounts.entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text('${entry.key} ${entry.value}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          );

    final metaRow = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: currentUserId == null
          ? null
          : postDoc.reference
                .collection('reactions')
                .doc(currentUserId)
                .snapshots(),
      builder: (context, snapshot) {
        final selectedEmoji =
            (snapshot.data?.data()?['emoji'] as String?)?.trim();
        final hasActiveReaction =
            selectedEmoji != null && selectedEmoji.isNotEmpty;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              tooltip: 'React',
              icon: Icon(
                hasActiveReaction
                    ? Icons.emoji_emotions_rounded
                    : Icons.add_reaction_outlined,
                size: 18,
                color: hasActiveReaction ? cs.primary : cs.onSurfaceVariant,
              ),
              onPressed: () => _showReactionPicker(
                context,
                activeEmoji: selectedEmoji,
              ),
            ),
          ],
        );
      },
    );

    final messageContent = isMine
        ? SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Spacer(),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      bubble,
                      reactionsRow,
                      const SizedBox(height: 2),
                      metaRow,
                    ],
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: MiniMeAvatarBadge(
                    size: 46,
                    padding: 3,
                    backgroundColor: cs.primaryContainer,
                    borderColor: cs.outlineVariant.withValues(alpha: 0.35),
                    bodyModel: miniMe['bodyModel'] as String?,
                    hairModel: miniMe['hairModel'] as String?,
                    shirtModel: miniMe['shirtModel'] as String?,
                    bodyWidthScale:
                        (miniMe['bodyWidthScale'] as num?)?.toDouble(),
                    companionId: miniMe['companionId'] as String?,
                    isHatched: miniMe['isHatched'] as bool? ?? true,
                    degradationLevel:
                        (miniMe['degradationLevel'] as num?)?.toDouble() ?? 0,
                    fallbackLabel: displayName,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 3),
                        child: Text(
                          displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      bubble,
                      reactionsRow,
                      const SizedBox(height: 2),
                      metaRow,
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          );

    final revealOpacity = (timeRevealOffset / 48).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Opacity(
                  opacity: revealOpacity,
                  child: Text(
                    _timeLabel(createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-timeRevealOffset, 0),
            child: messageContent,
          ),
        ],
      ),
    );
  }
}

class _SleepLogPostContent extends StatelessWidget {
  const _SleepLogPostContent({required this.data, required this.isMine});

  final Map<String, dynamic> data;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final duration =
      (data['restDuration'] ?? data['sleepDuration'] ?? '').toString().trim();
    final quality =
      (data['restQuality'] ?? data['sleepQuality'] ?? '').toString().trim();
    final bed =
      (data['restBedTime'] ?? data['sleepBedTime'] ?? '').toString().trim();
    final wake =
      (data['restWakeTime'] ?? data['sleepWakeTime'] ?? '').toString().trim();
    final energy = (data['restEnergy'] ?? '').toString().trim();
    final blocker = (data['restBlocker'] ?? '').toString().trim();
    final helped = (data['restHelped'] ?? '').toString().trim();
    final plan = (data['restPlan'] ?? '').toString().trim();
    final win = (data['restWin'] ?? '').toString().trim();
    final ask = (data['restAsk'] ?? '').toString().trim();
    final hoursRaw = data['restHours'];
    final restHours = hoursRaw is num ? hoursRaw.toDouble() : null;
    final note =
      (data['restNote'] ?? data['sleepNote'] ?? '').toString().trim();
    final kind = (data['sleepCardKind'] ?? 'checkin').toString().trim();
    final title = switch (kind) {
      'help' => 'Sleep help request',
      _ => 'Rest check-in',
    };
    final isHelpCard = kind == 'help';

    final primaryTextColor = isMine ? cs.onPrimaryContainer : cs.onSurface;
    final secondaryTextColor = isMine
      ? cs.onPrimaryContainer.withValues(alpha: 0.86)
      : cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bedtime_outlined, size: 16, color: primaryTextColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: primaryTextColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isHelpCard)
          _SleepHelpRequestChart(
            duration: duration,
            quality: quality,
            bed: bed,
            wake: wake,
            ask: ask,
            note: note,
            hours: restHours,
            isMine: isMine,
          )
        else ...[
          if (duration.isNotEmpty)
            _SleepMetricLine(
              label: 'Duration',
              value: duration,
              isMine: isMine,
            ),
          if (quality.isNotEmpty)
            _SleepMetricLine(label: 'Quality', value: quality, isMine: isMine),
          if (bed.isNotEmpty || wake.isNotEmpty)
            _SleepMetricLine(
              label: 'Time',
              value:
                  bed.isEmpty || wake.isEmpty ? '$bed$wake' : '$bed to $wake',
              isMine: isMine,
            ),
          if (energy.isNotEmpty)
            _SleepMetricLine(label: 'Energy', value: energy, isMine: isMine),
          if (blocker.isNotEmpty)
            _SleepMetricLine(label: 'Blocker', value: blocker, isMine: isMine),
          if (helped.isNotEmpty)
            _SleepMetricLine(
              label: 'What helped',
              value: helped,
              isMine: isMine,
            ),
          if (plan.isNotEmpty)
            _SleepMetricLine(label: 'Small plan', value: plan, isMine: isMine),
          if (win.isNotEmpty)
            _SleepMetricLine(label: 'Win', value: win, isMine: isMine),
          if (ask.isNotEmpty)
            _SleepMetricLine(
              label: 'Ask community',
              value: ask,
              isMine: isMine,
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Note: $note',
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondaryTextColor,
                height: 1.25,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SleepHelpRequestChart extends StatelessWidget {
  const _SleepHelpRequestChart({
    required this.duration,
    required this.quality,
    required this.bed,
    required this.wake,
    required this.ask,
    required this.note,
    required this.hours,
    required this.isMine,
  });

  final String duration;
  final String quality;
  final String bed;
  final String wake;
  final String ask;
  final String note;
  final double? hours;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.35);
    final panelBg = cs.surfaceContainerHighest.withValues(alpha: 0.42);
    final safeDuration = duration.isEmpty ? '-' : duration;
    final safeQuality = quality.isEmpty ? '-' : quality;
    final safeBed = bed.isEmpty ? '-' : bed;
    final safeWake = wake.isEmpty ? '-' : wake;
    final safeAsk = ask.isEmpty ? 'Any practical sleep tips?' : ask;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hours != null) ...[
          _SleepAmountChart(hours: hours!, isMine: isMine),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FlexColumnWidth(),
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: borderColor),
              verticalInside: BorderSide(color: borderColor),
            ),
            children: [
              TableRow(
                children: [
                  _SleepTableCell(label: 'Duration', value: safeDuration),
                  _SleepTableCell(label: 'Quality', value: safeQuality),
                ],
              ),
              TableRow(
                children: [
                  _SleepTableCell(label: 'Bedtime', value: safeBed),
                  _SleepTableCell(label: 'Wake', value: safeWake),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SleepMetricLine(label: 'Ask community', value: safeAsk, isMine: isMine),
        if (note.isNotEmpty)
          _SleepMetricLine(label: 'Context', value: note, isMine: isMine),
      ],
    );
  }
}

class _MilestoneAchievementCard extends StatelessWidget {
  const _MilestoneAchievementCard({required this.data, required this.isMine});

  final Map<String, dynamic> data;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = (data['milestoneTitle'] ?? '').toString().trim();
    final description = (data['milestoneDescription'] ?? '').toString().trim();

    final cardBg = isMine
        ? cs.primary.withValues(alpha: 0.12)
        : cs.tertiaryContainer.withValues(alpha: 0.38);
    final cardBorder = isMine
        ? cs.primary.withValues(alpha: 0.34)
        : cs.tertiary.withValues(alpha: 0.3);
    final headerColor = isMine ? cs.onPrimaryContainer : cs.onSurface;
    final captionColor = isMine
      ? cs.onPrimaryContainer.withValues(alpha: 0.76)
      : cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.workspace_premium_rounded, size: 18, color: headerColor),
            const SizedBox(width: 6),
            Text(
              'Achievement card',
              style: theme.textTheme.labelLarge?.copyWith(
                color: headerColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              if (title.isNotEmpty && description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cardBorder.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
              ],
              if (description.isNotEmpty)
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: captionColor,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseLogPostContent extends StatelessWidget {
  const _ExerciseLogPostContent({
    required this.data,
    required this.isMine,
    required this.fallbackText,
  });

  final Map<String, dynamic> data;
  final bool isMine;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final noExercise = data['noExercise'] == true;
    final items = _exerciseItemsFromPostData(data);
    final titleColor = isMine ? cs.onPrimaryContainer : cs.onSurface;
    final borderColor = cs.outlineVariant.withValues(alpha: 0.35);
    final panelBg = cs.surfaceContainerHighest.withValues(alpha: 0.42);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fitness_center_rounded, size: 16, color: titleColor),
            const SizedBox(width: 8),
            Text(
              'Exercise log',
              style: theme.textTheme.labelLarge?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (noExercise)
          Text(
            'No workout today, focusing on recovery.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMine ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (items.isNotEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => _ExerciseWorkoutChip(
                      item: item,
                      isMine: isMine,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
        else
          Text(
            fallbackText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMine ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _ExerciseWorkoutChip extends StatelessWidget {
  const _ExerciseWorkoutChip({required this.item, required this.isMine});

  final _ExerciseWorkoutShareItem item;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chipBg = isMine
        ? cs.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.56);
    final chipBorder = isMine
        ? cs.primary.withValues(alpha: 0.28)
        : cs.outlineVariant.withValues(alpha: 0.28);

    return Container(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isMine ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.sets > 0 && item.reps > 0
                ? '${item.sets} sets x ${item.reps} reps'
                : item.durationMinutes > 0
                ? '${item.durationMinutes} min'
                : 'Logged',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMine
                  ? cs.onPrimaryContainer.withValues(alpha: 0.84)
                  : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
class _MilestoneInputField extends StatelessWidget {
  const _MilestoneInputField({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.maxLines = 2,
  });

  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        border: const OutlineInputBorder(),
        filled: true,
      ),
    );
  }
}

class _SleepTableCell extends StatelessWidget {
  const _SleepTableCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepMetricLine extends StatelessWidget {
  const _SleepMetricLine({
    required this.label,
    required this.value,
    required this.isMine,
  });

  final String label;
  final String value;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = isMine
        ? cs.onPrimaryContainer.withValues(alpha: 0.78)
        : cs.onSurfaceVariant;
    final valueColor = isMine ? cs.onPrimaryContainer : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: labelColor, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageAction { reply, copy, delete, report }

class _SleepAmountChart extends StatelessWidget {
  const _SleepAmountChart({required this.hours, required this.isMine});

  final double hours;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (hours / 8.0).clamp(0.0, 1.0).toDouble();
    final fillColor = hours < 6.0
        ? cs.error
        : (isMine ? cs.onPrimaryContainer : cs.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sleep amount',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isMine
                    ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                    : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${hours.toStringAsFixed(1)}h / 8h',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isMine ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation<Color>(fillColor),
          ),
        ),
      ],
    );
  }
}

enum _QuickShareAction {
  milestone,
  sleepHelp,
  exercise,
}

class _MilestoneCardDraft {
  const _MilestoneCardDraft({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class _ReplyTarget {
  const _ReplyTarget({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.text,
  });

  final String postId;
  final String userId;
  final String userName;
  final String text;
}

List<_ExerciseWorkoutShareItem> _decodeExerciseWorkoutItems(String encoded) {
  if (encoded.trim().isEmpty) return const <_ExerciseWorkoutShareItem>[];
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const <_ExerciseWorkoutShareItem>[];
    return decoded
        .whereType<Map>()
        .map(
          (item) => _ExerciseWorkoutShareItem(
            name: (item['exerciseName'] ?? '').toString().trim(),
            sets: int.tryParse((item['sets'] ?? '').toString()) ?? 0,
            reps: int.tryParse((item['reps'] ?? '').toString()) ?? 0,
            durationMinutes:
                int.tryParse((item['durationMinutes'] ?? '').toString()) ?? 0,
          ),
        )
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const <_ExerciseWorkoutShareItem>[];
  }
}

class _ExerciseWorkoutShareItem {
  const _ExerciseWorkoutShareItem({
    required this.name,
    required this.sets,
    required this.reps,
    required this.durationMinutes,
  });

  final String name;
  final int sets;
  final int reps;
  final int durationMinutes;
}

List<_ExerciseWorkoutShareItem> _exerciseItemsFromPostData(
  Map<String, dynamic> data,
) {
  final raw = data['exerciseItems'];
  if (raw is! List) return const <_ExerciseWorkoutShareItem>[];
  return raw
      .whereType<Map>()
      .map(
        (item) => _ExerciseWorkoutShareItem(
          name: (item['name'] ?? '').toString().trim(),
          sets: (item['sets'] as num?)?.toInt() ??
              int.tryParse((item['sets'] ?? '').toString()) ??
              0,
          reps: (item['reps'] as num?)?.toInt() ??
              int.tryParse((item['reps'] ?? '').toString()) ??
              0,
          durationMinutes: (item['durationMinutes'] as num?)?.toInt() ??
              int.tryParse((item['durationMinutes'] ?? '').toString()) ??
              0,
        ),
      )
      .where((item) => item.name.isNotEmpty)
      .toList(growable: false);
}

bool _isDataImageUrl(String raw) {
  return raw.startsWith('data:image/');
}

Uint8List? _decodeDataImageBytes(String raw) {
  if (!_isDataImageUrl(raw)) return null;
  final commaIndex = raw.indexOf(',');
  if (commaIndex <= 0 || commaIndex >= raw.length - 1) return null;
  final payload = raw.substring(commaIndex + 1);
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

_ChatBannerPalette? _defaultChatBannerPaletteForSphere(String sphereName) {
  final normalized = sphereName.trim().toLowerCase();
  switch (normalized) {
    case 'general':
      return const _ChatBannerPalette(
        title: 'General',
        subtitle: 'Daily encouragement',
        icon: Icons.favorite_rounded,
        startColor: Color(0xFFFFCF8D),
        endColor: Color(0xFFFF8A80),
        accentColor: Color(0xFFFFF3E0),
      );
    case 'sleep':
      return const _ChatBannerPalette(
        title: 'Sleep',
        subtitle: 'Rest and reset',
        icon: Icons.bedtime_rounded,
        startColor: Color(0xFF4B5D9B),
        endColor: Color(0xFF9A8FE0),
        accentColor: Color(0xFFE8EAFD),
      );
    case 'exercise':
      return const _ChatBannerPalette(
        title: 'Exercise',
        subtitle: 'Move with purpose',
        icon: Icons.fitness_center_rounded,
        startColor: Color(0xFFFF9A62),
        endColor: Color(0xFFFF5A6A),
        accentColor: Color(0xFFFFE9D6),
      );
    default:
      return null;
  }
}

class _DefaultSphereChatBanner extends StatelessWidget {
  const _DefaultSphereChatBanner({required this.sphereName});

  final String sphereName;

  @override
  Widget build(BuildContext context) {
    final palette = _defaultChatBannerPaletteForSphere(sphereName);
    if (palette == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.startColor, palette.endColor],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -18,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accentColor.withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            left: -26,
            bottom: -34,
            child: Container(
              width: 170,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                color: palette.accentColor.withValues(alpha: 0.22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(palette.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        palette.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        palette.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
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

class _ChatBannerPalette {
  const _ChatBannerPalette({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final Color accentColor;
}

class _SphereChatBannerImage extends StatelessWidget {
  const _SphereChatBannerImage({required this.imageSource});

  final String imageSource;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final memoryBytes = _decodeDataImageBytes(imageSource);
    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      );
    }

    return Image.network(
      imageSource,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, __) {
        return Container(
          color: cs.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: cs.onSurfaceVariant,
          ),
        );
      },
    );
  }
}

class _ReplyReferenceSnippet extends StatelessWidget {
  const _ReplyReferenceSnippet({
    required this.title,
    required this.text,
    required this.lineColor,
    required this.compact,
  });

  final String title;
  final String text;
  final Color lineColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: compact ? 1 : 2, right: compact ? 1 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.only(top: 1, right: 8),
            height: compact ? 30 : 38,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.92),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.95),
                    height: 1.22,
                  ),
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _trimForReplyPreview(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= 180) return normalized;
  return '${normalized.substring(0, 180)}...';
}

String _timeLabel(DateTime? time) {
  if (time == null) return 'Just now';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.month}/${time.day}/${time.year}';
}
