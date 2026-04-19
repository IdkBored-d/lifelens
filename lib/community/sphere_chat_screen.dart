import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  bool _isBootstrapping = true;

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

  @override
  void initState() {
    super.initState();
    _bootstrapSphere();
  }

  Future<void> _bootstrapSphere() async {
    await _loadUserNickname();
    await _syncMemberMiniMe();
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
    });
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
    }, SetOptions(merge: true));

    await _touchMemberActivity();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared with the sphere')),
    );
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
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _postsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final posts = snapshot.data!.docs;
                      if (posts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                          child: _EmptyCommunityState(
                            sphereName: widget.sphere.name,
                            onCreatePost: _showCreatePostSheet,
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChatMessageTile(
                              postDoc: postDoc,
                              currentUserId: _userId,
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
                            : 'Write a message...',
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

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.postDoc,
    required this.currentUserId,
    required this.onReport,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> postDoc;
  final String? currentUserId;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.68;
    final data = postDoc.data();
    final isMine = data['userId'] == currentUserId;
    final miniMe = Map<String, dynamic>.from(data['miniMe'] as Map? ?? {});
    final displayName = (data['nickname'] ?? data['miniMeName'] ?? 'Anonymous')
        .toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final text = (data['text'] ?? '').toString();

    final bubble = Container(
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
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.3,
          color: isMine ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );

    final metaRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _timeLabel(createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 2),
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
          onSelected: (value) {
            if (value == 'report') {
              onReport();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
            if (!isMine)
              const PopupMenuItem(value: 'report', child: Text('Report')),
            if (isMine)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );

    if (isMine) {
      return SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [bubble, const SizedBox(height: 4), metaRow],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MiniMeAvatarBadge(
            size: 64,
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
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    displayName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                bubble,
                const SizedBox(height: 4),
                metaRow,
              ],
            ),
          ),
          const Spacer(),
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
