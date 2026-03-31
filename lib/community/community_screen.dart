import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sphere.dart';
import 'sphere_chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static Future<void>? _bootstrapFuture;

  static const Map<String, Map<String, String>> _sphereUiDemo = {
    'Mental Health': {
      'status': 'Peer support is strong this evening',
      'preview': '"Small win: I got outside for 10 minutes and it helped."',
    },
    'Diabetes': {
      'status': 'Meal and glucose tips trending',
      'preview': '"Post-meal walk lowered my afternoon spike today."',
    },
    'Sleep': {
      'status': 'Wind-down routine check-ins are trending',
      'preview': '"No screens for 20 mins before bed actually worked."',
    },
    'Exercise': {
      'status': 'Mobility streaks are heating up',
      'preview': '"15-minute mobility challenge day 6 complete."',
    },
    'General': {
      'status': 'Daily accountability thread is active',
      'preview': '"One goal today: move, hydrate, and check in."',
    },
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

        if (sphereRef == null) {
          sphereRef = await spheresRef.add({
            'name': name,
            'description': description,
            'memberCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'isPremade': true,
          });
        }

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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search spheres...',
                        prefixIcon: Icon(Icons.search, color: cs.primary),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    heroTag: 'community_add_sphere_fab',
                    tooltip: 'Create sphere',
                    onPressed: _showCreateSphereDialog,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.add, color: cs.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('spheres')
                    .orderBy('memberCount', descending: true)
                    .snapshots(),
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
                            _searchQuery.isEmpty ||
                            sphere.name.toLowerCase().contains(_searchQuery),
                      )
                      .toList();

                  if (spheres.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: cs.outline),
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
                      return _buildSphereCard(context, sphere);
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

  Widget _buildSphereCard(BuildContext context, Sphere sphere) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final demo =
        _sphereUiDemo[sphere.name] ??
        const {
          'status': 'Community updates available',
          'preview': '"New check-ins are coming in for this sphere."',
        };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          if (userId == null) return;

          final memberDoc = await FirebaseFirestore.instance
              .collection('spheres')
              .doc(sphere.id)
              .collection('members')
              .doc(userId)
              .get();

          if (!memberDoc.exists) {
            _showNicknamePrompt(context, sphere);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SphereChatScreen(sphere: sphere),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 32,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sphere.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        if (sphere.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            sphere.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(Icons.people, color: cs.primary, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        '${sphere.memberCount}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (!sphere.isPremade && sphere.creatorId == userId) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      onPressed: () => _confirmDeleteSphere(context, sphere),
                      tooltip: 'Delete sphere',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                demo['status'] ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  demo['preview'] ?? '',
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

    try {
      final sphereRef = FirebaseFirestore.instance
          .collection('spheres')
          .doc(sphere.id);

      await sphereRef.collection('members').doc(userId).set({
        'nickname': nickname,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await sphereRef.update({'memberCount': FieldValue.increment(1)});

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

      final members = await sphereRef.collection('members').get();
      for (final doc in members.docs) {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
