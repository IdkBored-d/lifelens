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

  @override
  void initState() {
    super.initState();
    _initializePremadeSpheres();
  }

  Future<void> _initializePremadeSpheres() async {
    final spheresRef = FirebaseFirestore.instance.collection('spheres');

    final premade = [
      {
        'name': 'Mental Health',
        'description': 'Share and discuss mental health topics',
      },
      {'name': 'Diabetes', 'description': 'Support for diabetes management'},
      {'name': 'Sleep', 'description': 'Discuss sleep patterns and tips'},
      {'name': 'Exercise', 'description': 'Fitness and exercise motivation'},
      {'name': 'General', 'description': 'General health discussions'},
    ];

    for (var sphere in premade) {
      final query = await spheresRef
          .where('name', isEqualTo: sphere['name'])
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        await spheresRef.add({
          'name': sphere['name'],
          'description': sphere['description'],
          'memberCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // Search bar and add button
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                  onPressed: () => _showCreateSphereDialog(context),
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.add, color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),

          // Spheres list
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
    );
  }

  Widget _buildSphereCard(BuildContext context, Sphere sphere) {
    final cs = Theme.of(context).colorScheme;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          if (userId == null) return;

          // Check if user is already a member
          final memberDoc = await FirebaseFirestore.instance
              .collection('spheres')
              .doc(sphere.id)
              .collection('members')
              .doc(userId)
              .get();

          if (!memberDoc.exists) {
            // Show nickname prompt
            _showNicknamePrompt(context, sphere);
          } else {
            // Navigate to chat
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
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.groups_rounded, size: 32, color: cs.primary),
              ),
              const SizedBox(width: 16),

              // Sphere info
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

              // Member count
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

      // Add user to members
      await sphereRef.collection('members').doc(userId).set({
        'nickname': nickname,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Increment member count
      await sphereRef.update({'memberCount': FieldValue.increment(1)});

      if (mounted) {
        // Navigate to chat
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

  void _showCreateSphereDialog(BuildContext context) {
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
    try {
      await FirebaseFirestore.instance.collection('spheres').add({
        'name': name,
        'description': description.isEmpty ? null : description,
        'memberCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
