import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../avatar_store.dart';
import '../models/sphere.dart';
import 'sphere_chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  static Future<void>? _bootstrapFuture;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _spheresStream =
      FirebaseFirestore.instance
          .collection('spheres')
          .orderBy('memberCount', descending: true)
          .snapshots();

  static const Map<String, String> _defaultPinnedBodies = {
    'Mental Health':
        'Share what is helping, ask for support, and avoid giving medical advice. If you are in immediate danger, contact local emergency support.',
    'Diabetes':
        'Share routines, food swaps, and pattern observations. Use this space for peer support, not diagnosis or medication changes.',
    'Sleep':
        'Post what helped your wind-down, bedtime, or wake consistency. Keep replies practical and kind.',
    'Exercise':
        'Celebrate progress, ask beginner-friendly questions, and share routines people can actually follow.',
    'General':
        'Use this sphere for check-ins, support, and realistic habit tips that help you feel better this week.',
  };

  @override
  void initState() {
    super.initState();
    _bootstrapFuture ??= _initializePremadeSpheres();
    unawaited(_bootstrapFuture);
  }

  Future<void> _initializePremadeSpheres() async {
    final CollectionReference<Map<String, dynamic>> spheresRef =
        FirebaseFirestore.instance.collection('spheres');

    final premade = <Map<String, String>>[
      {
        'name': 'Mental Health',
        'description': 'Share and discuss mental health topics',
      },
      {'name': 'Diabetes', 'description': 'Support for diabetes management'},
      {'name': 'Sleep', 'description': 'Discuss sleep patterns and tips'},
      {'name': 'Exercise', 'description': 'Fitness and exercise motivation'},
      {'name': 'General', 'description': 'General health discussions'},
    ];

    try {
      final existingDocs = await spheresRef
          .where('isPremade', isEqualTo: true)
          .get();
      final existingByName = <String, DocumentReference<Map<String, dynamic>>>{
        for (final doc in existingDocs.docs)
          ((doc.data()['name'] as String?) ?? ''): doc.reference,
      };

      final seedTasks = <Future<void>>[];

      for (final sphere in premade) {
        final name = sphere['name']!;
        final description = sphere['description']!;
        var sphereRef = existingByName[name];

        sphereRef ??= await spheresRef.add({
          'name': name,
          'description': description,
          'memberCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'isPremade': true,
          'pinnedTitle': 'Welcome to $name',
          'pinnedBody':
              _defaultPinnedBodies[name] ??
              'Support each other with kindness, practical tips, and privacy in mind.',
          'lastActivityText': 'Fresh support threads are ready to start.',
          'lastActivityAt': FieldValue.serverTimestamp(),
        });

        seedTasks.add(_seedDummySphereData(sphereRef, name));
      }

      await Future.wait(seedTasks);
    } catch (_) {
      // Keep the community UI responsive even if bootstrap seeding fails.
    }
  }

  Future<void> _seedDummySphereData(
    DocumentReference<Map<String, dynamic>> sphereRef,
    String sphereName,
  ) async {
    final sphereSnapshot = await sphereRef.get();
    final existing = sphereSnapshot.data();

    if (existing?['dummySeedVersion'] == 1) {
      return;
    }

    final now = DateTime.now();
    final members = [
      {'id': 'demo_member_alex', 'nickname': 'AlexPulse'},
      {'id': 'demo_member_river', 'nickname': 'RiverMind'},
      {'id': 'demo_member_sam', 'nickname': 'SamBalance'},
      {'id': 'demo_member_jo', 'nickname': 'JoSpark'},
    ];

    final messagesBySphere = {
      'Mental Health': [
        'Small win today: I took a 10-minute walk before work and felt less overwhelmed.',
        'Sharing a grounding trick: name 5 things you can see, 4 you can feel, 3 you can hear.',
        'Anyone else trying to reduce doom-scrolling before bed?',
      ],
      'Diabetes': [
        'Reminder: hydrated + short walk after meals has helped my afternoon numbers.',
        'What low-prep snacks are working for everyone this week?',
        'I started logging meals with mood and energy. Patterns are finally making sense.',
      ],
      'Sleep': [
        'Last night I set a wind-down alarm and actually fell asleep faster.',
        'Trying to keep wake-up time consistent even on weekends. Hard but helping.',
        'Drop your favorite no-screen routine for the last 20 minutes before bed.',
      ],
      'Exercise': [
        'Did a 15-minute mobility session today and my back feels better already.',
        'Anyone doing beginner-friendly strength plans at home?',
        'Stacking movement with music has made it easier to stay consistent.',
      ],
      'General': [
        'Goal for today: one healthy meal, one walk, one check-in.',
        'What is one habit that gave you the biggest boost this month?',
        'Keeping this thread for quick daily accountability check-ins.',
      ],
    };

    final seededMessages =
        messagesBySphere[sphereName] ??
        [
          'Welcome to the sphere. Share what you are working on this week.',
          'Daily check-in: one win and one challenge.',
          'Use this space to support each other with practical tips.',
        ];

    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final memberRef = sphereRef.collection('members').doc(member['id']);
      batch.set(memberRef, {
        'nickname': member['nickname'],
        'joinedAt': Timestamp.fromDate(now.subtract(Duration(days: 10 - i))),
        'warningCount': 0,
      }, SetOptions(merge: true));
    }

    for (int i = 0; i < seededMessages.length; i++) {
      final messageRef = sphereRef
          .collection('messages')
          .doc('demo_msg_${i + 1}');
      final author = members[i % members.length];
      batch.set(messageRef, {
        'text': seededMessages[i],
        'userId': author['id'],
        'nickname': author['nickname'],
        'timestamp': Timestamp.fromDate(
          now.subtract(Duration(minutes: (i + 1) * 18)),
        ),
      }, SetOptions(merge: true));
    }

    batch.set(sphereRef, {
      'memberCount': members.length,
      'dummySeedVersion': 1,
      'lastDummySeedAt': FieldValue.serverTimestamp(),
      'pinnedTitle': 'Welcome to $sphereName',
      'pinnedBody':
          _defaultPinnedBodies[sphereName] ??
          'Support each other with kindness, practical tips, and privacy in mind.',
      'lastActivityText': seededMessages.first,
      'lastActivityAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find a sphere and jump into the conversation.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search spheres',
                            prefixIcon: Icon(Icons.search, color: cs.primary),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(
                              alpha: 0.32,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            final normalized = value.trim().toLowerCase();
                            if (_searchQuery.value == normalized) return;
                            _searchQuery.value = normalized;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Create sphere',
                        onPressed: _showCreateSphereDialog,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _searchQuery,
                builder: (context, searchQuery, _) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _spheresStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final spheres = snapshot.data!.docs
                          .map((doc) => Sphere.fromFirestore(doc))
                          .where(
                            (sphere) =>
                                searchQuery.isEmpty ||
                                sphere.name.toLowerCase().contains(searchQuery),
                          )
                          .toList(growable: false);

                      if (spheres.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: cs.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No spheres found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: spheres.length,
                        itemBuilder: (context, index) {
                          final sphere = spheres[index];
                          return _SphereCard(
                            sphere: sphere,
                            onJoinRequired: () =>
                                _showNicknamePrompt(context, sphere),
                            onOpen: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SphereChatScreen(sphere: sphere),
                                ),
                              );
                            },
                            onDelete: sphere.isPremade
                                ? null
                                : () => _confirmDeleteSphere(context, sphere),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }
}

class _SphereCard extends StatelessWidget {
  const _SphereCard({
    required this.sphere,
    required this.onJoinRequired,
    required this.onOpen,
    this.onDelete,
  });

  final Sphere sphere;
  final VoidCallback onJoinRequired;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    final sphereRef = FirebaseFirestore.instance
        .collection('spheres')
        .doc(sphere.id);
    final memberStream = userId == null
        ? null
        : sphereRef.collection('members').doc(userId).snapshots();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () async {
          if (userId == null) return;

          final memberDoc = await sphereRef
              .collection('members')
              .doc(userId)
              .get();
          if (!context.mounted) return;

          if (!memberDoc.exists) {
            onJoinRequired();
          } else {
            onOpen();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: memberStream,
            builder: (context, memberSnapshot) {
              final memberData = memberSnapshot.data?.data();
              final lastReadAt = (memberData?['lastReadAt'] as Timestamp?)
                  ?.toDate();
              final hasUnread =
                  lastReadAt == null ||
                  (sphere.lastActivityAt?.isAfter(lastReadAt) ?? false);
              final isJoined = memberSnapshot.data?.exists ?? false;
              final lastActivityLabel = sphere.lastActivityAt == null
                  ? 'No recent activity'
                  : _communityRelativeTimeLabel(sphere.lastActivityAt!);
              final previewText =
                  sphere.lastActivityText ??
                  'Open the sphere to see the latest post.';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          size: 24,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sphere.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                                if (isJoined) ...[
                                  const SizedBox(width: 8),
                                  _InfoPill(
                                    icon: Icons.check_circle_rounded,
                                    label: 'Joined',
                                    background: cs.secondaryContainer,
                                    foreground: cs.onSecondaryContainer,
                                  ),
                                ],
                                if (hasUnread && isJoined) ...[
                                  const SizedBox(width: 8),
                                  _InfoPill(
                                    icon: Icons.mark_chat_unread_rounded,
                                    label: 'New',
                                    background: cs.primaryContainer,
                                    foreground: cs.onPrimaryContainer,
                                  ),
                                ],
                              ],
                            ),
                            if (sphere.description != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                sphere.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sphere.memberCount}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onDelete != null &&
                          !sphere.isPremade &&
                          sphere.creatorId == userId) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          onPressed: onDelete,
                          tooltip: 'Delete sphere',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.schedule_rounded,
                        label: lastActivityLabel,
                        background: cs.surfaceContainerHighest,
                        foreground: cs.onSurfaceVariant,
                      ),
                      _InfoPill(
                        icon: Icons.people_alt_outlined,
                        label: '${sphere.memberCount} members',
                        background: cs.surfaceContainerHighest,
                        foreground: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

extension on _CommunityScreenState {
  void _showNicknamePrompt(BuildContext context, Sphere sphere) {
    final nicknameController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Sphere'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a nickname for ${sphere.name}',
              style: TextStyle(color: cs.onSurfaceVariant),
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
              decoration: InputDecoration(
                hintText: 'Enter nickname...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
              final nickname = nicknameController.text.trim();
              if (nickname.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a nickname')),
                );
                return;
              }

              Navigator.pop(context);
              await _joinSphere(sphere, nickname);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinSphere(Sphere sphere, String nickname) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final avatarStore = context.read<AvatarStore>();
    final miniMeData = avatarStore.toCommunityAvatarMap();

    try {
      final sphereRef = FirebaseFirestore.instance
          .collection('spheres')
          .doc(sphere.id);
      final memberRef = sphereRef.collection('members').doc(userId);
      var createdJoinPost = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final sphereDoc = await transaction.get(sphereRef);
        final memberDoc = await transaction.get(memberRef);
        final currentCount = (sphereDoc.data()?['memberCount'] as int?) ?? 0;

        transaction.set(memberRef, {
          'nickname': nickname,
          'joinedAt': memberDoc.exists
              ? (memberDoc.data()?['joinedAt'] ?? FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
          'lastReadAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'warningCount': memberDoc.data()?['warningCount'] ?? 0,
          'role': sphere.creatorId == userId ? 'owner' : 'member',
          'miniMe': miniMeData,
          'miniMeName': nickname,
        }, SetOptions(merge: true));

        if (!memberDoc.exists) {
          transaction.update(sphereRef, {'memberCount': currentCount + 1});
          createdJoinPost = true;
          final joinPostRef = sphereRef.collection('posts').doc();
          transaction.set(joinPostRef, {
            'type': 'system_join',
            'text': '$nickname has joined the sphere',
            'userId': 'system',
            'nickname': nickname,
            'miniMe': miniMeData,
            'miniMeName': nickname,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'latestActivityAt': FieldValue.serverTimestamp(),
            'replyCount': 0,
            'reactionCounts': <String, int>{},
            'isPinned': false,
          });
        }
      });

      if (createdJoinPost) {
        await sphereRef.set({
          'lastActivityText': '$nickname has joined the sphere',
          'lastActivityAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SphereChatScreen(sphere: sphere),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error joining sphere: $e')));
      }
    }
  }

  void _showCreateSphereDialog() {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a sphere.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Sphere'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Sphere Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLength: 100,
              maxLines: 2,
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a sphere name')),
                );
                return;
              }

              Navigator.pop(context);
              await _createSphere(name, descController.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSphere(String name, String description) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('spheres').add({
        'name': name,
        'description': description.isEmpty ? null : description,
        'memberCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': userId,
        'isPremade': false,
        'pinnedTitle': 'Start here',
        'pinnedBody':
            'Introduce yourself with a nickname, share what you are working on, and keep replies practical, kind, and privacy-safe.',
        'lastActivityText': 'This sphere is ready for its first check-in.',
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sphere created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating sphere: $e')));
      }
    }
  }

  void _confirmDeleteSphere(BuildContext context, Sphere sphere) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sphere'),
        content: Text(
          'Are you sure you want to delete "${sphere.name}"? This will remove all messages and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSphere(sphere);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSphere(Sphere sphere) async {
    try {
      final sphereRef = FirebaseFirestore.instance
          .collection('spheres')
          .doc(sphere.id);

      final messages = await sphereRef.collection('messages').get();
      for (final doc in messages.docs) {
        await doc.reference.delete();
      }

      final posts = await sphereRef.collection('posts').get();
      for (final doc in posts.docs) {
        final replies = await doc.reference.collection('replies').get();
        for (final reply in replies.docs) {
          await reply.reference.delete();
        }

        final reactions = await doc.reference.collection('reactions').get();
        for (final reaction in reactions.docs) {
          await reaction.reference.delete();
        }

        await doc.reference.delete();
      }

      final members = await sphereRef.collection('members').get();
      for (final doc in members.docs) {
        await doc.reference.delete();
      }

      final reports = await sphereRef.collection('reports').get();
      for (final doc in reports.docs) {
        await doc.reference.delete();
      }

      final warnings = await sphereRef.collection('warnings').get();
      for (final doc in warnings.docs) {
        await doc.reference.delete();
      }

      await sphereRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sphere deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting sphere: $e')));
      }
    }
  }
}

String _communityRelativeTimeLabel(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Active now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return 'Earlier this week';
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
