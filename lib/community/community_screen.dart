import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../avatar_store.dart';
import '../models/sphere.dart';
import 'friends_hub_screen.dart';
import 'social_features.dart';
import 'sphere_chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final Set<String> _pendingDeleteIds = <String>{};
  static bool _didInitializePremadeSpheres = false;
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _spheresStream =
      FirebaseFirestore.instance
          .collection('spheres')
          .orderBy('memberCount', descending: true)
          .snapshots();

  static const List<String> _defaultSphereOrder = [
    'General',
    'Sleep',
    'Exercise',
  ];

  static const Map<String, String> _defaultDescriptions = {
    'General': 'Heartwarming daily support, gratitude, and steady progress.',
    'Sleep':
        'Better nights through calm routines, gentle accountability, and rest tips.',
    'Exercise':
        'Small consistent workouts, motivation boosts, and progress celebrations.',
  };

  static const Map<String, String> _defaultPinnedBodies = {
    'General':
        'Use this sphere for check-ins, gentle motivation, and practical support for this week.',
    'Sleep':
        'Share bedtime wins, wind-down routines, and kind tips for better rest tonight.',
    'Exercise':
        'Celebrate every rep, encourage beginners, and share realistic workout routines.',
  };

  @override
  void initState() {
    super.initState();
    if (!_didInitializePremadeSpheres) {
      _didInitializePremadeSpheres = true;
      unawaited(_initializePremadeSpheres());
    }
  }

  Future<void> _initializePremadeSpheres() async {
    final spheresRef = FirebaseFirestore.instance.collection('spheres');
    try {
      final existing = await spheresRef
          .where('isPremade', isEqualTo: true)
          .get();
      final existingNames = existing.docs
          .map(
            (d) => _normalizedSphereName((d.data()['name'] as String?) ?? ''),
          )
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
          'isPublic': true,
          'creatorId': userId,
          'pinnedTitle': 'Welcome to $name',
          'pinnedBody':
              _defaultPinnedBodies[name] ??
              'Support each other with kindness, practical tips, and privacy in mind.',
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Keep the UI responsive even if bootstrap fails.
    }
  }

  void _setSpherePendingDelete(String sphereId, bool isPending) {
    setState(() {
      if (isPending) {
        _pendingDeleteIds.add(sphereId);
      } else {
        _pendingDeleteIds.remove(sphereId);
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingInvitesStream() {
    final uid = _currentUserId;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sphere_invites')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingFriendRequestsStream() {
    final uid = _currentUserId;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
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
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _pendingFriendRequestsStream(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;
                          final label = '$count';
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Friends',
                                onPressed: _openFriendsHub,
                                icon: const Icon(Icons.person_search_rounded),
                              ),
                              if (count > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.error,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: cs.surface,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: cs.onError,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
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
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _pendingInvitesStream(),
              builder: (context, snapshot) {
                final invites = snapshot.data?.docs ?? const [];
                if (invites.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sphere invites',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ...invites.take(3).map((inviteDoc) {
                            final data = inviteDoc.data();
                            final sphereName = (data['sphereName'] ?? 'Sphere')
                                .toString();
                            final fromUsername =
                                (data['fromUsername'] ?? 'friend').toString();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Join $sphereName'),
                              subtitle: Text('Invited by @$fromUsername'),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _declineSphereInvite(inviteDoc),
                                    child: const Text('Decline'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        _acceptSphereInvite(inviteDoc),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
                                  !_pendingDeleteIds.contains(sphere.id) &&
                                  (searchQuery.isEmpty ||
                                      sphere.name.toLowerCase().contains(
                                        searchQuery,
                                      )),
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
                            onJoinRequired: () => _confirmJoinSphere(sphere),
                            onOpen: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SphereChatScreen(sphere: sphere),
                                ),
                              );
                            },
                            onDelete:
                                (!sphere.isPremade &&
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

  void _openFriendsHub() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FriendsHubScreen()));
  }
}

String _normalizedSphereName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

List<Sphere> _visibleUniqueSpheres(Iterable<Sphere> spheres) {
  const defaultOrder = <String, int>{'general': 0, 'sleep': 1, 'exercise': 2};
  const hiddenSphereNames = <String>{'test', 'test sphere'};

  final seenNames = <String>{};
  final uniqueSpheres = <Sphere>[];

  for (final sphere in spheres) {
    final normalizedName = _normalizedSphereName(sphere.name);
    if (hiddenSphereNames.contains(normalizedName)) {
      continue;
    }
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

          return InkWell(
            onTap: userId == null || !memberSnapshot.hasData
                ? null
                : () {
                    if (isJoined) {
                      onOpen();
                    } else {
                      onJoinRequired();
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: Column(
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
                              templateKey: hasTemplateBanner
                                  ? bannerTemplate
                                  : null,
                              titleOverride:
                                  (!sphere.isPremade && hasTemplateBanner)
                                  ? sphere.name
                                  : null,
                              subtitleOverride:
                                  (!sphere.isPremade && hasTemplateBanner)
                                  ? _shortBannerDescription(sphere.description)
                                  : null,
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
                                    _InfoPill(
                                      icon: sphere.isPublic
                                          ? Icons.public_rounded
                                          : Icons.lock_outline_rounded,
                                      label: sphere.isPublic
                                          ? 'Public'
                                          : 'Invite only',
                                      background: cs.surfaceContainerHighest,
                                      foreground: cs.onSurfaceVariant,
                                    ),
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
                      if (previewText != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: highlightPreview
                                  ? cs.primaryContainer.withValues(alpha: 0.55)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.45,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: highlightPreview
                                  ? Border(
                                      left: BorderSide(
                                        color: cs.primary,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            padding: EdgeInsets.fromLTRB(
                              highlightPreview ? 9 : 10,
                              9,
                              10,
                              9,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  highlightPreview
                                      ? Icons.mark_chat_unread_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  size: 14,
                                  color: highlightPreview
                                      ? cs.primary
                                      : cs.onSurfaceVariant.withValues(
                                          alpha: 0.45,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    previewText,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: highlightPreview
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant,
                                      fontWeight: highlightPreview
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      height: 1.35,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (highlightPreview) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: cs.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on _CommunityScreenState {
  Future<void> _confirmJoinSphere(Sphere sphere) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final canJoinDirectly =
        sphere.isPublic || sphere.isPremade || sphere.creatorId == userId;
    if (!canJoinDirectly) {
      final shouldRequestInvite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invite only'),
          content: const Text(
            'You need an invite before you can join this sphere.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: const Text('Request Invite'),
            ),
          ],
        ),
      );
      if (!mounted || shouldRequestInvite != true) return;
      await _requestSphereInvite(sphere);
      return;
    }

    final shouldJoin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join ${sphere.name}?'),
        content: const Text(
          'Join this sphere to post messages, reply, react, and share progress with members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join Sphere'),
          ),
        ],
      ),
    );

    if (!mounted || shouldJoin != true) return;
    await _joinSphere(sphere);
  }

  Future<void> _requestSphereInvite(Sphere sphere) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final avatarStore = context.read<AvatarStore>();
    final profile = await SocialFeatures.getCurrentUserProfile();
    String username = profile?.username.trim() ?? '';
    if (username.isEmpty) {
      final display = profile?.displayName.trim() ?? '';
      username = display.replaceAll(' ', '_').toLowerCase();
    }
    if (username.isEmpty) username = 'member';

    try {
      await FirebaseFirestore.instance
          .collection('spheres')
          .doc(sphere.id)
          .collection('join_requests')
          .doc(userId)
          .set({
            'userId': userId,
            'username': username,
            'displayName': profile?.displayName ?? username,
            'status': 'pending',
            'sphereId': sphere.id,
            'sphereName': sphere.name,
            'miniMe': avatarStore.toCommunityAvatarMap(),
            'miniMeName': username,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite request sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not request invite: $e')));
    }
  }

  Future<void> _joinSphere(Sphere sphere) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    if (!sphere.isPublic && !sphere.isPremade && sphere.creatorId != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This sphere is invite only.')),
      );
      return;
    }
    final avatarStore = context.read<AvatarStore>();
    final miniMeData = avatarStore.toCommunityAvatarMap();
    final username = await _defaultCommunityUsername();

    try {
      final sphereRef = FirebaseFirestore.instance
          .collection('spheres')
          .doc(sphere.id);
      final memberRef = sphereRef.collection('members').doc(userId);
      await memberRef.set({
        'username': username,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'warningCount': 0,
        'role': (!sphere.isPremade && sphere.creatorId == userId)
            ? 'owner'
            : 'member',
        'miniMe': miniMeData,
        'miniMeName': username,
      });

      await sphereRef.set({
        'memberCount': FieldValue.increment(1),
        'lastActivityText': '$username has joined the sphere',
        'lastActivityAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await sphereRef.collection('posts').add({
        'type': 'system_join',
        'text': '$username has joined the sphere',
        'userId': userId,
        'username': username,
        'miniMe': miniMeData,
        'miniMeName': username,
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

  Future<String> _defaultCommunityUsername() async {
    final profile = await SocialFeatures.getCurrentUserProfile();
    if (profile == null) return 'member';
    final candidate = profile.username.trim();
    if (candidate.isNotEmpty) return candidate;
    final fallback = profile.displayName
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();
    return fallback.isEmpty ? 'member' : fallback;
  }

  Future<void> _acceptSphereInvite(
    QueryDocumentSnapshot<Map<String, dynamic>> inviteDoc,
  ) async {
    final uid = _currentUserId;
    if (uid == null) return;
    final avatarStore = context.read<AvatarStore>();
    final inviteData = inviteDoc.data();
    final sphereId = (inviteData['sphereId'] ?? '').toString();
    final inviteRef = inviteDoc.reference;

    if (sphereId.isEmpty) return;

    final sphereRef = FirebaseFirestore.instance
        .collection('spheres')
        .doc(sphereId);
    final sphereDoc = await sphereRef.get();
    if (!sphereDoc.exists) {
      await inviteRef.update({
        'status': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This sphere is no longer available.')),
      );
      return;
    }

    final memberRef = sphereRef.collection('members').doc(uid);
    final memberDoc = await memberRef.get();
    if (!memberDoc.exists) {
      final username = await _defaultCommunityUsername();
      final miniMeData = avatarStore.toCommunityAvatarMap();
      await memberRef.set({
        'username': username,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'warningCount': 0,
        'role': 'member',
        'miniMe': miniMeData,
        'miniMeName': username,
      });
      await sphereRef.set({
        'memberCount': FieldValue.increment(1),
        'lastActivityText': '$username has joined the sphere',
        'lastActivityAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await sphereRef.collection('posts').add({
        'type': 'system_join',
        'text': '$username has joined the sphere',
        'userId': uid,
        'username': username,
        'miniMe': miniMeData,
        'miniMeName': username,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'latestActivityAt': FieldValue.serverTimestamp(),
        'replyCount': 0,
        'reactionCounts': <String, int>{},
        'isPinned': false,
      });
    }

    await inviteRef.update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await sphereRef.collection('invites').doc(uid).set({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _declineSphereInvite(
    QueryDocumentSnapshot<Map<String, dynamic>> inviteDoc,
  ) async {
    final uid = _currentUserId;
    final sphereId = (inviteDoc.data()['sphereId'] ?? '').toString();
    await inviteDoc.reference.update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (uid == null || sphereId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('spheres')
        .doc(sphereId)
        .collection('invites')
        .doc(uid)
        .set({
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _showCreateSphereDialog() {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create a sphere.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CreateSphereScreen(onCreate: _createSphere),
      ),
    );
  }

  Future<void> _createSphere(
    String name,
    String description, {
    String bannerUrl = '',
    String bannerTemplate = '',
    List<String> inviteFriendIds = const <String>[],
    bool isPublic = true,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final avatarStore = context.read<AvatarStore>();

    try {
      final sphereRef = await FirebaseFirestore.instance.collection('spheres').add({
        'name': name,
        'description': description.isEmpty ? null : description,
        'memberCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': userId,
        'isPremade': false,
        'isPublic': isPublic,
        if (bannerUrl.isNotEmpty) 'bannerUrl': bannerUrl,
        if (bannerTemplate.isNotEmpty) 'bannerTemplate': bannerTemplate,
        'pinnedTitle': 'Start here',
        'pinnedBody':
            'Introduce yourself, share what you are working on, and keep replies practical, kind, and privacy-safe.',
        'lastActivityText': 'Sphere created',
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      final username = await _defaultCommunityUsername();
      final miniMeData = avatarStore.toCommunityAvatarMap();
      await sphereRef.collection('members').doc(userId).set({
        'username': username,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'warningCount': 0,
        'role': 'owner',
        'miniMe': miniMeData,
        'miniMeName': username,
      });

      if (inviteFriendIds.isNotEmpty) {
        await SocialFeatures.sendSphereInvites(
          sphereId: sphereRef.id,
          sphereName: name,
          friendUserIds: inviteFriendIds,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sphere created successfully!')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SphereChatScreen(
              sphere: Sphere(
                id: sphereRef.id,
                name: name,
                memberCount: 1,
                createdAt: DateTime.now(),
                description: description.isEmpty ? null : description,
                creatorId: userId,
                isPremade: false,
                isPublic: isPublic,
                bannerUrl: bannerUrl.isEmpty ? null : bannerUrl,
                bannerTemplate: bannerTemplate.isEmpty ? null : bannerTemplate,
              ),
            ),
          ),
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
    _setSpherePendingDelete(sphere.id, true);
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
    } catch (e) {
      if (mounted) {
        _setSpherePendingDelete(sphere.id, false);
      }
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
    key: 'sky',
    label: 'Sky',
    startColor: Color(0xFF7BDFF2),
    endColor: Color(0xFFB2F7EF),
    accentColor: Color(0xFFE0F7FA),
    icon: Icons.cloud_rounded,
    subtitle: 'Light & airy',
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
  const _DefaultSphereBanner({
    required this.sphereName,
    this.templateKey,
    this.titleOverride,
    this.subtitleOverride,
  });

  final String sphereName;
  final String? templateKey;
  final String? titleOverride;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final palette =
        (templateKey != null ? _paletteForTemplateKey(templateKey!) : null) ??
        _defaultBannerPaletteForSphere(sphereName);
    if (palette == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }

    final title = (titleOverride ?? '').trim().isEmpty
        ? palette.title
        : titleOverride!.trim();
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
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
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

String? _shortBannerDescription(String? description) {
  final text = (description ?? '').trim();
  if (text.isEmpty) return null;

  final periodIndex = text.indexOf('.');
  if (periodIndex > 0 && periodIndex < 60) {
    return text.substring(0, periodIndex).trim();
  }

  const maxLength = 60;
  if (text.length <= maxLength) return text;

  final slice = text.substring(0, maxLength);
  final lastSpace = slice.lastIndexOf(' ');
  final trimmed = (lastSpace > 20 ? slice.substring(0, lastSpace) : slice)
      .trim();
  return '$trimmed...';
}

class _CreateSphereScreen extends StatefulWidget {
  const _CreateSphereScreen({required this.onCreate});

  final Future<void> Function(
    String name,
    String description, {
    String bannerUrl,
    String bannerTemplate,
    List<String> inviteFriendIds,
    bool isPublic,
  })
  onCreate;

  @override
  State<_CreateSphereScreen> createState() => _CreateSphereScreenState();
}

class _CreateSphereScreenState extends State<_CreateSphereScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _inviteFriendIds = <String>{};
  String? _selectedTemplate;
  Uint8List? _pickedBytes;
  bool _isPublic = true;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 420,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _selectedTemplate = null;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sphere name')),
      );
      return;
    }

    setState(() => _isUploading = true);

    String uploadedBannerUrl = '';
    if (_pickedBytes != null) {
      // Encode as base64 data URI — stored directly in Firestore.
      // Firebase Storage is not yet initialised on this project.
      uploadedBannerUrl =
          'data:image/jpeg;base64,${base64Encode(_pickedBytes!)}';
    }

    await widget.onCreate(
      name,
      _descController.text.trim(),
      bannerUrl: uploadedBannerUrl,
      bannerTemplate: _selectedTemplate ?? '',
      inviteFriendIds: _inviteFriendIds.toList(growable: false),
      isPublic: _isPublic,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickFriendsToInvite() async {
    final selected = await SocialFeatures.showFriendPicker(
      context,
      title: 'Invite friends to this sphere',
      actionLabel: 'Save selection',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _inviteFriendIds
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Sphere'),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _submit,
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
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
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLength: 100,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.public_rounded),
                    label: Text('Public'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.lock_outline_rounded),
                    label: Text('Invite only'),
                  ),
                ],
                selected: {_isPublic},
                onSelectionChanged: (selection) {
                  setState(() => _isPublic = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _isPublic
                    ? 'Anyone can discover and join this sphere.'
                    : 'Only invited people can join this sphere.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Invite friends'),
                subtitle: Text(
                  _inviteFriendIds.isEmpty
                      ? 'No friends selected yet'
                      : '${_inviteFriendIds.length} selected',
                ),
                trailing: OutlinedButton(
                  onPressed: _pickFriendsToInvite,
                  child: const Text('Select'),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Banner',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (int i = 0; i < _allBannerTemplates.length; i++)
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: _BannerSwatch(
                        template: _allBannerTemplates[i],
                        selectedKey: _selectedTemplate,
                        onSelect: (key) => setState(() {
                          _selectedTemplate = key == _selectedTemplate
                              ? null
                              : key;
                          _pickedBytes = null;
                        }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (_pickedBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _pickedBytes!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                color: cs.onSurfaceVariant,
                                size: 26,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose from camera roll',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Recommended size: 1200 x 420',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      if (_pickedBytes != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _pickedBytes = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
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

class _BannerSwatch extends StatelessWidget {
  const _BannerSwatch({
    required this.template,
    required this.selectedKey,
    required this.onSelect,
  });

  final _BannerTemplate template;
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedKey == template.key;
    return GestureDetector(
      onTap: () => onSelect(template.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [template.startColor, template.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: template.endColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Center(
                child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
              )
            : null,
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
