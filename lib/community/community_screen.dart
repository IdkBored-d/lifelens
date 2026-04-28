import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _spheresStream =
      FirebaseFirestore.instance
          .collection('spheres')
          .orderBy('memberCount', descending: true)
          .snapshots();

  static const List<String> _defaultSphereOrder = ['General', 'Sleep', 'Exercise'];

  static const Map<String, String> _defaultDescriptions = {
    'General': 'Heartwarming daily support, gratitude, and steady progress.',
    'Sleep': 'Better nights through calm routines, gentle accountability, and rest tips.',
    'Exercise': 'Small consistent workouts, motivation boosts, and progress celebrations.',
  };

  static const Map<String, String> _defaultPinnedBodies = {
    'General': 'Use this sphere for check-ins, gentle motivation, and practical support for this week.',
    'Sleep': 'Share bedtime wins, wind-down routines, and kind tips for better rest tonight.',
    'Exercise': 'Celebrate every rep, encourage beginners, and share realistic workout routines.',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_initializePremadeSpheres());
  }

  Future<void> _initializePremadeSpheres() async {
    final spheresRef = FirebaseFirestore.instance.collection('spheres');
    try {
      final existing = await spheresRef
          .where('isPremade', isEqualTo: true)
          .get();
      final existingNames = existing.docs
          .map((d) => _normalizedSphereName((d.data()['name'] as String?) ?? ''))
          .toSet();

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'system';
      for (final name in _defaultSphereOrder) {
        if (existingNames.contains(_normalizedSphereName(name))) continue;
        await spheresRef.add({
          'name': name,
          'description': _defaultDescriptions[name],
          'memberCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'isPremade': true,
          'creatorId': userId,
          'pinnedTitle': 'Welcome to $name',
          'pinnedBody': _defaultPinnedBodies[name] ??
              'Support each other with kindness, practical tips, and privacy in mind.',
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Keep the UI responsive even if bootstrap fails.
    }
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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

                      final spheres = _visibleUniqueSpheres(
                        snapshot.data!.docs
                            .map((doc) => Sphere.fromFirestore(doc))
                            .where(
                              (sphere) =>
                                  searchQuery.isEmpty ||
                                  sphere.name.toLowerCase().contains(
                                    searchQuery,
                                  ),
                            ),
                      );

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
                            onDelete: (!sphere.isPremade &&
                                    sphere.creatorId ==
                                        FirebaseAuth.instance.currentUser?.uid)
                                ? () => _confirmDeleteSphere(context, sphere)
                                : null,
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

String _normalizedSphereName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

List<Sphere> _visibleUniqueSpheres(Iterable<Sphere> spheres) {
  const defaultOrder = <String, int>{
    'general': 0,
    'sleep': 1,
    'exercise': 2,
  };

  final seenNames = <String>{};
  final uniqueSpheres = <Sphere>[];

  for (final sphere in spheres) {
    final normalizedName = _normalizedSphereName(sphere.name);
    if (seenNames.add(normalizedName)) {
      uniqueSpheres.add(sphere);
    }
  }

  uniqueSpheres.sort((a, b) {
    final aOrder = defaultOrder[_normalizedSphereName(a.name)] ?? 999;
    final bOrder = defaultOrder[_normalizedSphereName(b.name)] ?? 999;
    return aOrder.compareTo(bOrder);
  });

  return uniqueSpheres;
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
              final hasNewPostsForVisitor =
                  !isJoined && sphere.lastActivityAt != null;
              final highlightPreview =
                  (isJoined && hasUnread) || hasNewPostsForVisitor;
              final lastActivityLabel = sphere.lastActivityAt == null
                  ? 'No recent activity'
                  : _communityRelativeTimeLabel(sphere.lastActivityAt!);
              final previewText = sphere.lastActivityText;
              final previewShadow = highlightPreview
                  ? [
                      Shadow(
                        color: cs.primary.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null;
              final bannerUrl = sphere.bannerUrl?.trim();
              final hasBanner =
                  bannerUrl != null &&
                  bannerUrl.isNotEmpty &&
                  (_isHttpImageUrl(bannerUrl) || _isDataImageUrl(bannerUrl));
              final bannerTemplate = sphere.bannerTemplate?.trim() ?? '';
              final hasTemplateBanner =
                  !hasBanner &&
                  bannerTemplate.isNotEmpty &&
                  _paletteForTemplateKey(bannerTemplate) != null;
              final hasDefaultBanner =
                  !hasBanner &&
                  !hasTemplateBanner &&
                  _defaultBannerPaletteForSphere(sphere.name) != null;
              final showBanner = hasBanner || hasTemplateBanner || hasDefaultBanner;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasBanner || hasTemplateBanner || hasDefaultBanner) ...[
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 170,
                        child: hasBanner
                            ? _SphereBannerImage(imageSource: bannerUrl)
                            : _DefaultSphereBanner(
                                sphereName: sphere.name,
                                templateKey: hasTemplateBanner ? bannerTemplate : null,
                              ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      showBanner ? 12 : 16,
                      16,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 0,
                                          maxWidth: 180,
                                        ),
                                        child: Text(
                                          sphere.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: cs.onSurface,
                                                letterSpacing: 0.1,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isJoined) ...[
                                        _InfoPill(
                                          icon: Icons.check_circle_rounded,
                                          label: 'Joined',
                                          background: cs.secondaryContainer,
                                          foreground: cs.onSecondaryContainer,
                                        ),
                                      ],
                                      if (hasUnread && isJoined) ...[
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
                                    const SizedBox(height: 6),
                                    Text(
                                      sphere.description!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.25,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (onDelete != null) ...[
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
                        if (previewText != null) Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  previewText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: highlightPreview
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                    fontWeight: highlightPreview
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    shadows: previewShadow,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (highlightPreview) ...[
                                const SizedBox(width: 10),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withValues(alpha: 0.55),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
}

extension on _CommunityScreenState {
  void _showNicknamePrompt(BuildContext context, Sphere sphere) {
    final nicknameController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String? errorText;

          return AlertDialog(
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
                StatefulBuilder(
                  builder: (context, setFieldState) {
                    return TextField(
                      controller: nicknameController,
                      decoration: InputDecoration(
                        hintText: 'Enter nickname...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: errorText,
                        errorStyle: TextStyle(color: cs.error),
                      ),
                      maxLength: 20,
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() => errorText = null);
                        }
                      },
                    );
                  },
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
                    setDialogState(() => errorText = 'Please enter a nickname');
                    return;
                  }

                  // Check for duplicate nickname in this sphere.
                  final sphereRef = FirebaseFirestore.instance
                      .collection('spheres')
                      .doc(sphere.id);
                  final taken = await sphereRef
                      .collection('members')
                      .where('nickname', isEqualTo: nickname)
                      .limit(1)
                      .get();
                  if (taken.docs.isNotEmpty) {
                    setDialogState(() => errorText = 'Nickname already taken');
                    return;
                  }

                  if (context.mounted) Navigator.pop(context);
                  await _joinSphere(sphere, nickname);
                },
                child: const Text('Join'),
              ),
            ],
          );
        },
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
      await memberRef.set({
        'nickname': nickname,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'warningCount': 0,
        'role': (!sphere.isPremade && sphere.creatorId == userId) ? 'owner' : 'member',
        'miniMe': miniMeData,
        'miniMeName': nickname,
      });

      await sphereRef.set({
        'memberCount': FieldValue.increment(1),
        'lastActivityText': '$nickname has joined the sphere',
        'lastActivityAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await sphereRef.collection('posts').add({
        'type': 'system_join',
        'text': '$nickname has joined the sphere',
        'userId': userId,
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
      builder: (context) {
        String? selectedTemplate;
        Uint8List? pickedBytes;
        XFile? pickedFile;
        bool isUploading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Sphere'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 16),
                    Text(
                      'Banner',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Template swatches ───────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < _allBannerTemplates.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Builder(builder: (context) {
                              final t = _allBannerTemplates[i];
                              final isSelected = selectedTemplate == t.key;
                              return Tooltip(
                                message: t.label,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    selectedTemplate = isSelected ? null : t.key;
                                    pickedBytes = null;
                                    pickedFile = null;
                                  }),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [t.startColor, t.endColor],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Camera roll button ──────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1200,
                          maxHeight: 420,
                          imageQuality: 85,
                        );
                        if (file != null) {
                          final bytes = await file.readAsBytes();
                          setState(() {
                            pickedFile = file;
                            pickedBytes = bytes;
                            selectedTemplate = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Choose from camera roll'),
                    ),
                    // ── Image preview ───────────────────────────────────
                    if (pickedBytes != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Image.memory(
                              pickedBytes!,
                              height: 90,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  pickedBytes = null;
                                  pickedFile = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a sphere name'),
                              ),
                            );
                            return;
                          }

                          setState(() => isUploading = true);

                          String uploadedBannerUrl = '';
                          if (pickedFile != null && pickedBytes != null) {
                            try {
                              final uid = FirebaseAuth.instance.currentUser!.uid;
                              final ref = FirebaseStorage.instance.ref(
                                'sphere_banners/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                              );
                              await ref.putData(
                                pickedBytes!,
                                SettableMetadata(contentType: 'image/jpeg'),
                              );
                              uploadedBannerUrl = await ref.getDownloadURL();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to upload banner image'),
                                  ),
                                );
                              }
                              setState(() => isUploading = false);
                              return;
                            }
                          }

                          if (context.mounted) Navigator.pop(context);
                          await _createSphere(
                            name,
                            descController.text.trim(),
                            bannerUrl: uploadedBannerUrl,
                            bannerTemplate: selectedTemplate ?? '',
                          );
                        },
                  child: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createSphere(String name, String description, {String bannerUrl = '', String bannerTemplate = ''}) async {
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
        if (bannerUrl.isNotEmpty) 'bannerUrl': bannerUrl,
        if (bannerTemplate.isNotEmpty) 'bannerTemplate': bannerTemplate,
        'pinnedTitle': 'Start here',
        'pinnedBody':
            'Introduce yourself with a nickname, share what you are working on, and keep replies practical, kind, and privacy-safe.',
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

bool _isHttpImageUrl(String raw) {
  final parsed = Uri.tryParse(raw);
  return parsed != null &&
      (parsed.scheme == 'http' || parsed.scheme == 'https') &&
      parsed.host.isNotEmpty;
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

_DefaultBannerPalette? _defaultBannerPaletteForSphere(String sphereName) {
  final normalized = _normalizedSphereName(sphereName);
  switch (normalized) {
    case 'general':
      return const _DefaultBannerPalette(
        title: 'General',
        subtitle: 'Daily encouragement',
        icon: Icons.favorite_rounded,
        startColor: Color(0xFFFFCF8D),
        endColor: Color(0xFFFF8A80),
        accentColor: Color(0xFFFFF3E0),
      );
    case 'sleep':
      return const _DefaultBannerPalette(
        title: 'Sleep',
        subtitle: 'Rest and reset',
        icon: Icons.bedtime_rounded,
        startColor: Color(0xFF4B5D9B),
        endColor: Color(0xFF9A8FE0),
        accentColor: Color(0xFFE8EAFD),
      );
    case 'exercise':
      return const _DefaultBannerPalette(
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

// ── Banner templates available when creating a sphere ──────────────────────

class _BannerTemplate {
  const _BannerTemplate({
    required this.key,
    required this.label,
    required this.startColor,
    required this.endColor,
    required this.accentColor,
    required this.icon,
    required this.subtitle,
  });

  final String key;
  final String label;
  final Color startColor;
  final Color endColor;
  final Color accentColor;
  final IconData icon;
  final String subtitle;
}

const List<_BannerTemplate> _allBannerTemplates = [
  _BannerTemplate(
    key: 'sunrise',
    label: 'Sunrise',
    startColor: Color(0xFFFFCF8D),
    endColor: Color(0xFFFF8A80),
    accentColor: Color(0xFFFFF3E0),
    icon: Icons.wb_sunny_rounded,
    subtitle: 'Warm & uplifting',
  ),
  _BannerTemplate(
    key: 'night',
    label: 'Night',
    startColor: Color(0xFF4B5D9B),
    endColor: Color(0xFF9A8FE0),
    accentColor: Color(0xFFE8EAFD),
    icon: Icons.bedtime_rounded,
    subtitle: 'Calm & restful',
  ),
  _BannerTemplate(
    key: 'energy',
    label: 'Energy',
    startColor: Color(0xFFFF9A62),
    endColor: Color(0xFFFF5A6A),
    accentColor: Color(0xFFFFE9D6),
    icon: Icons.bolt_rounded,
    subtitle: 'Bold & active',
  ),
  _BannerTemplate(
    key: 'ocean',
    label: 'Ocean',
    startColor: Color(0xFF2196F3),
    endColor: Color(0xFF4ECDC4),
    accentColor: Color(0xFFE3F2FD),
    icon: Icons.waves_rounded,
    subtitle: 'Fresh & flowing',
  ),
  _BannerTemplate(
    key: 'forest',
    label: 'Forest',
    startColor: Color(0xFF56AB2F),
    endColor: Color(0xFF43C6AC),
    accentColor: Color(0xFFE8F5E9),
    icon: Icons.forest_rounded,
    subtitle: 'Natural & grounded',
  ),
  _BannerTemplate(
    key: 'cosmic',
    label: 'Cosmic',
    startColor: Color(0xFF6B48FF),
    endColor: Color(0xFFE040FB),
    accentColor: Color(0xFFEDE7F6),
    icon: Icons.auto_awesome_rounded,
    subtitle: 'Bold & creative',
  ),
  _BannerTemplate(
    key: 'rose',
    label: 'Rose',
    startColor: Color(0xFFFF6B9D),
    endColor: Color(0xFFFFB347),
    accentColor: Color(0xFFFCE4EC),
    icon: Icons.favorite_rounded,
    subtitle: 'Warm & caring',
  ),
  _BannerTemplate(
    key: 'midnight',
    label: 'Midnight',
    startColor: Color(0xFF1A1A2E),
    endColor: Color(0xFF16213E),
    accentColor: Color(0xFF533483),
    icon: Icons.nightlight_rounded,
    subtitle: 'Dark & focused',
  ),
];

_DefaultBannerPalette? _paletteForTemplateKey(String key) {
  for (final t in _allBannerTemplates) {
    if (t.key == key) {
      return _DefaultBannerPalette(
        title: t.label,
        subtitle: t.subtitle,
        icon: t.icon,
        startColor: t.startColor,
        endColor: t.endColor,
        accentColor: t.accentColor,
      );
    }
  }
  return null;
}

// ── Palette class ───────────────────────────────────────────────────────────

class _DefaultBannerPalette {
  const _DefaultBannerPalette({
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

class _DefaultSphereBanner extends StatelessWidget {
  const _DefaultSphereBanner({required this.sphereName, this.templateKey});

  final String sphereName;
  final String? templateKey;

  @override
  Widget build(BuildContext context) {
    final palette = (templateKey != null ? _paletteForTemplateKey(templateKey!) : null)
        ?? _defaultBannerPaletteForSphere(sphereName);
    if (palette == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.startColor, palette.endColor],
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

class _SphereBannerImage extends StatelessWidget {
  const _SphereBannerImage({required this.imageSource});

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
