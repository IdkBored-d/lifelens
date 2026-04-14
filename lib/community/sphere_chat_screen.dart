import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifelens/community/community_prompt_service.dart';
import 'package:lifelens/shared_widgets/mini_me_avatar_badge.dart';
import 'package:provider/provider.dart';

import '../avatar_store.dart';
import '../models/sphere.dart';
import '../services/content_moderation_service.dart';

class SphereChatScreen extends StatefulWidget {
  const SphereChatScreen({super.key, required this.sphere});

  final Sphere sphere;

  @override
  State<SphereChatScreen> createState() => _SphereChatScreenState();
}

class _SphereChatScreenState extends State<SphereChatScreen> {
  final ScrollController _scrollController = ScrollController();

  String? _userNickname;
  String _userRole = 'member';
  bool _isBootstrapping = true;

  DocumentReference<Map<String, dynamic>> get _sphereRef =>
      FirebaseFirestore.instance.collection('spheres').doc(widget.sphere.id);

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _sphereRef.collection('posts');

  CollectionReference<Map<String, dynamic>> get _membersRef =>
      _sphereRef.collection('members');

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _bootstrapSphere();
  }

  Future<void> _bootstrapSphere() async {
    await _loadUserNickname();
    await _syncMemberMiniMe();
    await _refreshDailyPromptIfNeeded();
    await _ensureSphereStarterContent();
    await _markSphereSeen();
    if (!mounted) return;
    setState(() => _isBootstrapping = false);
  }

  Future<void> _loadUserNickname() async {
    final userId = _userId;
    if (userId == null) return;

    final memberDoc = await _membersRef.doc(userId).get();
    if (!memberDoc.exists || !mounted) return;

    setState(() {
      _userNickname = memberDoc.data()?['nickname'] as String?;
      _userRole = (memberDoc.data()?['role'] as String?) ?? 'member';
    });
  }

  Future<void> _refreshDailyPromptIfNeeded() async {
    final snapshot = await _sphereRef.get();
    final data = snapshot.data();
    final nextPrompt = CommunityPromptService.promptForSphere(
      widget.sphere.name,
    );
    final nextDateKey = CommunityPromptService.dateKeyFor(DateTime.now());

    if (CommunityPromptService.isCurrentPrompt(
      storedPrompt: data?['dailyPrompt'] as String?,
      sphereName: widget.sphere.name,
      storedDateKey: data?['dailyPromptDateKey'] as String?,
    )) {
      return;
    }

    await _sphereRef.set({
      'dailyPrompt': nextPrompt,
      'dailyPromptDateKey': nextDateKey,
    }, SetOptions(merge: true));
  }

  Future<void> _ensureSphereStarterContent() async {
    final postsSnapshot = await _postsRef.limit(1).get();
    if (postsSnapshot.docs.isNotEmpty) return;

    final legacyMessages = await _sphereRef
        .collection('messages')
        .orderBy('timestamp')
        .limit(8)
        .get();

    if (legacyMessages.docs.isEmpty) {
      await _postsRef.add({
        'type': 'check_in',
        'text':
            'Welcome to ${widget.sphere.name}. Share one win, one challenge, or one question to get support started.',
        'userId': 'system',
        'nickname': 'LifeLens',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'latestActivityAt': FieldValue.serverTimestamp(),
        'replyCount': 0,
        'reactionCounts': <String, int>{},
        'isPinned': false,
      });
      return;
    }

    for (final doc in legacyMessages.docs) {
      final data = doc.data();
      await _postsRef.add({
        'type': 'check_in',
        'text': data['text'] ?? '',
        'userId': data['userId'] ?? 'legacy',
        'nickname': data['nickname'] ?? 'Anonymous',
        'createdAt': data['timestamp'] ?? FieldValue.serverTimestamp(),
        'updatedAt': data['timestamp'] ?? FieldValue.serverTimestamp(),
        'latestActivityAt': data['timestamp'] ?? FieldValue.serverTimestamp(),
        'replyCount': 0,
        'reactionCounts': <String, int>{},
        'isPinned': false,
      });
    }
  }

  Future<void> _markSphereSeen() async {
    final userId = _userId;
    if (userId == null) return;

    await _membersRef.doc(userId).set({
      'lastReadAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _touchMemberActivity() async {
    final userId = _userId;
    if (userId == null) return;

    await _membersRef.doc(userId).set({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncMemberMiniMe() async {
    final userId = _userId;
    if (userId == null) return;

    final avatarStore = context.read<AvatarStore>();
    await _membersRef.doc(userId).set({
      'miniMe': avatarStore.toCommunityAvatarMap(),
      'miniMeName': avatarStore.miniMeName,
    }, SetOptions(merge: true));
  }

  Future<void> _createPost({required String type, required String text}) async {
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
      'miniMe': avatarStore.toCommunityAvatarMap(),
      'miniMeName': avatarStore.miniMeName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'latestActivityAt': FieldValue.serverTimestamp(),
      'replyCount': 0,
      'reactionCounts': <String, int>{},
      'isPinned': false,
    });

    await _sphereRef.set({
      'lastActivityText': text,
      'lastActivityAt': FieldValue.serverTimestamp(),
      'dailyPrompt': CommunityPromptService.promptForSphere(widget.sphere.name),
      'dailyPromptDateKey': CommunityPromptService.dateKeyFor(DateTime.now()),
    }, SetOptions(merge: true));

    await _touchMemberActivity();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared with the sphere')),
    );
  }

  Future<void> _addReply({required String postId, required String text}) async {
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

    final postRef = _postsRef.doc(postId);
    await postRef.collection('replies').add({
      'text': text,
      'userId': userId,
      'nickname': nickname,
      'miniMe': avatarStore.toCommunityAvatarMap(),
      'miniMeName': avatarStore.miniMeName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await postRef.update({
      'replyCount': FieldValue.increment(1),
      'latestActivityAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _sphereRef.set({
      'lastActivityText': text,
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _touchMemberActivity();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reply added')));
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

  Future<void> _toggleLike(String postId) async {
    final userId = _userId;
    if (userId == null) return;

    final reactionRef = _postsRef
        .doc(postId)
        .collection('reactions')
        .doc(userId);
    final snapshot = await reactionRef.get();

    if (!snapshot.exists) {
      await reactionRef.set({
        'type': 'like',
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _postsRef.doc(postId).set({
        'reactionCounts.like': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } else {
      final currentReaction = snapshot.data()?['type'] as String?;
      if (currentReaction == 'like') {
        await reactionRef.delete();
        await _postsRef.doc(postId).set({
          'reactionCounts.like': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      } else {
        await reactionRef.set({'type': 'like'}, SetOptions(merge: true));
        if (currentReaction != null && currentReaction.isNotEmpty) {
          await _postsRef.doc(postId).set({
            'reactionCounts.$currentReaction': FieldValue.increment(-1),
            'reactionCounts.like': FieldValue.increment(1),
          }, SetOptions(merge: true));
        } else {
          await _postsRef.doc(postId).set({
            'reactionCounts.like': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      }
    }
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

  Future<void> _pinPost(String postId, String text) async {
    final preview = text.trim();
    final existingPinnedId =
        (await _sphereRef.get()).data()?['pinnedPostId'] as String?;

    await _sphereRef.set({
      'pinnedTitle': 'Community focus',
      'pinnedBody': preview.length > 220
          ? '${preview.substring(0, 220)}...'
          : preview,
      'pinnedPostId': postId,
    }, SetOptions(merge: true));

    if (existingPinnedId != null && existingPinnedId != postId) {
      await _postsRef.doc(existingPinnedId).set({
        'isPinned': false,
      }, SetOptions(merge: true));
    }
    await _postsRef.doc(postId).set({
      'isPinned': true,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pinned to sphere header')));
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

  void _showCreatePostSheet() {
    final controller = TextEditingController();
    String selectedType = 'check_in';
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share with ${widget.sphere.name}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _postTypes.entries.map((entry) {
                        final selected = selectedType == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value.label),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() => selectedType = entry.key);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      maxLines: 6,
                      minLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _postTypes[selectedType]!.hint,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Keep posts practical, kind, and privacy-safe.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            Navigator.pop(sheetContext);
                            await _createPost(type: selectedType, text: text);
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Post'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRepliesSheet({
    required String postId,
    required String postText,
    required String nickname,
  }) {
    final controller = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replies',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(postText),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _postsRef
                        .doc(postId)
                        .collection('replies')
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final replies = snapshot.data!.docs;
                      if (replies.isEmpty) {
                        return Center(
                          child: Text(
                            'No replies yet. Start the support thread.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final reply = replies[index].data();
                          final miniMe = Map<String, dynamic>.from(
                            reply['miniMe'] as Map? ?? {},
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.32,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MiniMeAvatarBadge(
                                  size: 48,
                                  padding: 4,
                                  backgroundColor: cs.primaryContainer,
                                  borderColor: cs.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                  bodyModel: miniMe['bodyModel'] as String?,
                                  hairModel: miniMe['hairModel'] as String?,
                                  shirtModel: miniMe['shirtModel'] as String?,
                                  bodyWidthScale:
                                      (miniMe['bodyWidthScale'] as num?)
                                          ?.toDouble(),
                                  companionId: miniMe['companionId'] as String?,
                                  isHatched:
                                      miniMe['isHatched'] as bool? ?? true,
                                  degradationLevel:
                                      (miniMe['degradationLevel'] as num?)
                                          ?.toDouble() ??
                                      0,
                                  fallbackLabel: reply['nickname'] as String?,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reply['nickname'] ?? 'Anonymous',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(reply['text'] ?? ''),
                                      const SizedBox(height: 6),
                                      Text(
                                        _timeLabel(
                                          (reply['createdAt'] as Timestamp?)
                                              ?.toDate(),
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Add a practical or supportive reply...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        controller.clear();
                        await _addReply(postId: postId, text: text);
                      },
                      child: const Icon(Icons.reply_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                        final member = members[index].data();
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
                            fallbackLabel: member['nickname'] as String?,
                          ),
                          title: Text(member['nickname'] ?? 'Anonymous'),
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
              stream: _membersRef.snapshots(),
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
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _sphereRef.snapshots(),
                    builder: (context, sphereSnapshot) {
                      final sphereData = sphereSnapshot.data?.data() ?? {};
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _postsRef
                            .orderBy('latestActivityAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final posts = snapshot.data!.docs;
                          return ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                            children: [
                              _PromptCard(
                                prompt:
                                    CommunityPromptService.isCurrentPrompt(
                                      storedPrompt:
                                          sphereData['dailyPrompt'] as String?,
                                      sphereName: widget.sphere.name,
                                      storedDateKey:
                                          sphereData['dailyPromptDateKey']
                                              as String?,
                                    )
                                    ? ((sphereData['dailyPrompt'] as String?) ??
                                          widget.sphere.dailyPrompt ??
                                          CommunityPromptService.promptForSphere(
                                            widget.sphere.name,
                                          ))
                                    : CommunityPromptService.promptForSphere(
                                        widget.sphere.name,
                                      ),
                                onPost: _showCreatePostSheet,
                              ),
                              const SizedBox(height: 12),
                              if (posts.isEmpty)
                                _EmptyCommunityState(
                                  sphereName: widget.sphere.name,
                                  onCreatePost: _showCreatePostSheet,
                                )
                              else
                                ...posts.map(
                                  (postDoc) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _PostCard(
                                      postDoc: postDoc,
                                      currentUserId: _userId,
                                      canPin: _userRole == 'owner',
                                      onReply: () => _showRepliesSheet(
                                        postId: postDoc.id,
                                        postText: postDoc.data()['text'] ?? '',
                                        nickname:
                                            postDoc.data()['nickname'] ??
                                            'Anonymous',
                                      ),
                                      onReport: () => _showReportDialog(
                                        postId: postDoc.id,
                                        text: postDoc.data()['text'] ?? '',
                                      ),
                                      onLike: () => _toggleLike(postDoc.id),
                                      onDelete: () => _deletePost(postDoc.id),
                                      onPin: () => _pinPost(
                                        postDoc.id,
                                        postDoc.data()['text'] ?? '',
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                _ComposerDock(
                  userNickname: _userNickname,
                  onTap: _showCreatePostSheet,
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt, required this.onPost});

  final String prompt;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Today\'s prompt',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onPost,
              child: const Text('Write a post'),
            ),
          ),
        ],
      ),
    );
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
            'Start with a simple check-in or question.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreatePost,
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Create First Post'),
          ),
        ],
      ),
    );
  }
}

class _ComposerDock extends StatelessWidget {
  const _ComposerDock({required this.userNickname, required this.onTap});

  final String? userNickname;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        userNickname == null
                            ? 'Join with a nickname to post'
                            : 'Write a post...',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.postDoc,
    required this.currentUserId,
    required this.canPin,
    required this.onReply,
    required this.onLike,
    required this.onReport,
    required this.onDelete,
    required this.onPin,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> postDoc;
  final String? currentUserId;
  final bool canPin;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final data = postDoc.data();
    final isMine = data['userId'] == currentUserId;
    final type = (data['type'] as String?) ?? 'check_in';
    final reactionCounts = Map<String, dynamic>.from(
      data['reactionCounts'] as Map? ?? {},
    );
    final miniMe = Map<String, dynamic>.from(data['miniMe'] as Map? ?? {});
    final String displayName = (data['nickname'] ?? data['miniMeName']) ?? 'Anonymous';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiniMeAvatarBadge(
                size: 52,
                padding: 4,
                backgroundColor: cs.primaryContainer,
                borderColor: cs.outlineVariant.withValues(alpha: 0.35),
                bodyModel: miniMe['bodyModel'] as String?,
                hairModel: miniMe['hairModel'] as String?,
                shirtModel: miniMe['shirtModel'] as String?,
                bodyWidthScale: (miniMe['bodyWidthScale'] as num?)?.toDouble(),
                companionId: miniMe['companionId'] as String?,
                isHatched: miniMe['isHatched'] as bool? ?? true,
                degradationLevel:
                    (miniMe['degradationLevel'] as num?)?.toDouble() ?? 0,
                fallbackLabel: displayName,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeLabel((data['createdAt'] as Timestamp?)?.toDate()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'reply') {
                    onReply();
                  } else if (value == 'report') {
                    onReport();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'pin') {
                    onPin();
                  }
                },
                itemBuilder: (context) => [
                  if (type != 'system_join')
                    const PopupMenuItem(value: 'reply', child: Text('Reply')),
                  if (!isMine && type != 'system_join')
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                  if (isMine && type != 'system_join')
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  if (canPin && type != 'system_join')
                    const PopupMenuItem(
                      value: 'pin',
                      child: Text('Pin to header'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data['text'] ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
          if (type != 'system_join') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onReply,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            color: cs.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${data['replyCount'] ?? 0} replies',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _LikeButton(
                  postRef: postDoc.reference,
                  currentUserId: currentUserId,
                  count: (reactionCounts['like'] ?? 0) as int,
                  onTap: onLike,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
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

class _PostTypeMeta {
  const _PostTypeMeta({required this.label, required this.hint});

  final String label;
  final String hint;
}

final Map<String, _PostTypeMeta> _postTypes = {
  'check_in': const _PostTypeMeta(
    label: 'Check-in',
    hint: 'Share a quick update on how you are doing.',
  ),
  'question': const _PostTypeMeta(
    label: 'Question',
    hint: 'Ask the sphere something simple and specific.',
  ),
  'win': const _PostTypeMeta(
    label: 'Win',
    hint: 'Share a small win from today or this week.',
  ),
  'tip': const _PostTypeMeta(
    label: 'Tip',
    hint: 'Share something that helped you.',
  ),
  'support': const _PostTypeMeta(
    label: 'Support',
    hint: 'Tell the sphere what support you need.',
  ),
};

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.postRef,
    required this.currentUserId,
    required this.count,
    required this.onTap,
  });

  final DocumentReference<Map<String, dynamic>> postRef;
  final String? currentUserId;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (currentUserId == null) {
      return InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, color: cs.primary, size: 18),
              if (count > 0) ...[const SizedBox(width: 6), Text('$count')],
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: postRef.collection('reactions').doc(currentUserId).snapshots(),
      builder: (context, snapshot) {
        final liked = snapshot.data?.data()?['type'] == 'like';
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: liked
                  ? cs.primaryContainer.withValues(alpha: 0.8)
                  : cs.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked ? cs.primary : cs.onSurfaceVariant,
                  size: 18,
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: liked ? cs.primary : cs.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
