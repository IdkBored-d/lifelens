import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'social_features.dart';

class FriendsHubScreen extends StatefulWidget {
  const FriendsHubScreen({super.key});

  @override
  State<FriendsHubScreen> createState() => _FriendsHubScreenState();
}

class _FriendsHubScreenState extends State<FriendsHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _working = false;
  int _activeSection = 0;
  Future<List<_UserSearchResult>>? _searchFuture;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchQuery(String rawValue) {
    final normalized = SocialFeatures.normalizeUsername(rawValue);
    if (normalized == _query) return;

    setState(() {
      _query = normalized;
      if (_query.length >= 2) {
        _searchFuture = _searchUsers(_query);
      } else {
        _searchFuture = null;
      }
    });
  }

  Future<List<_UserSearchResult>> _searchUsers(String normalizedQuery) async {
    final uid = _currentUserId;
    if (uid.isEmpty) return const <_UserSearchResult>[];

    // Always include matching existing friends so they still appear in search.
    final friendMatches = <_UserSearchResult>[];
    try {
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('friends')
          .limit(250)
          .get()
          .timeout(const Duration(seconds: 8));

      friendMatches.addAll(
        friendsSnapshot.docs
            .map((doc) {
              final data = doc.data();
              final username = (data['username'] ?? '').toString().trim();
              final usernameLower = username.toLowerCase();
              final displayName = (data['displayName'] ?? '').toString().trim();
              return _UserSearchResult(
                userId: doc.id,
                username: username,
                usernameLower: usernameLower,
                displayName: displayName,
              );
            })
            .where((item) => item.usernameLower.startsWith(normalizedQuery))
            .toList(growable: false),
      );
    } on FirebaseException {
      // Keep global search working even if friends subcollection lookup fails.
    }

    final mergedByUserId = <String, _UserSearchResult>{
      for (final item in friendMatches) item.userId: item,
    };

    try {
      final usernamesSnapshot = await FirebaseFirestore.instance
          .collection('usernames')
          .orderBy(FieldPath.documentId)
          .startAt([normalizedQuery])
          .endAt(['$normalizedQuery\uf8ff'])
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 8));

      final results = usernamesSnapshot.docs
          .map((doc) {
            final data = doc.data();
            final userId = (data['uid'] ?? '').toString().trim();
            final username = (data['username'] ?? doc.id).toString().trim();
            if (userId.isEmpty || userId == uid) return null;
            return _UserSearchResult(
              userId: userId,
              username: username,
              usernameLower: username.toLowerCase(),
              displayName: '',
            );
          })
          .whereType<_UserSearchResult>()
          .toList(growable: false);

      for (final item in results) {
        mergedByUserId.putIfAbsent(item.userId, () => item);
      }
    } on FirebaseException {
      // Fall back to users collection scan when usernames registry is unavailable.
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(250)
        .get()
        .timeout(const Duration(seconds: 8));

    final results =
        snapshot.docs
            .where((doc) => doc.id != uid)
            .map((doc) {
              final data = doc.data();
              final username = (data['username'] ?? '').toString().trim();
              final usernameLower = username.toLowerCase();
              final first = (data['firstName'] ?? '').toString().trim();
              final last = (data['lastName'] ?? '').toString().trim();
              final displayName = [
                first,
                last,
              ].where((part) => part.isNotEmpty).join(' ').trim();
              return _UserSearchResult(
                userId: doc.id,
                username: username,
                usernameLower: usernameLower,
                displayName: displayName,
              );
            })
            .where((item) => item.usernameLower.startsWith(normalizedQuery))
            .toList(growable: false)
          ..sort((a, b) => a.usernameLower.compareTo(b.usernameLower));

    for (final item in results) {
      mergedByUserId.putIfAbsent(item.userId, () => item);
    }

    final merged = mergedByUserId.values.toList(growable: false)
      ..sort((a, b) => a.usernameLower.compareTo(b.usernameLower));
    return merged.take(30).toList(growable: false);
  }

  Future<void> _sendRequest(String toUserId) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await SocialFeatures.sendFriendRequest(toUserId: toUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _respond(String requestId, bool accept) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await SocialFeatures.respondToFriendRequest(
        requestId: requestId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Friend request accepted.' : 'Request declined.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _emptyStateCard(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionSwitchButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final labelWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    return SizedBox(
      height: 46,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primaryContainer,
                foregroundColor: cs.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: labelWidget,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                backgroundColor: cs.surface.withValues(alpha: 0.08),
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: labelWidget,
            ),
    );
  }

  Widget _statusPill(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUserId;
    final cs = Theme.of(context).colorScheme;

    if (uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: const Center(child: Text('Please sign in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('friends')
            .snapshots(),
        builder: (context, friendsSnapshot) {
          final friendIds = <String>{
            for (final doc in friendsSnapshot.data?.docs ?? const []) doc.id,
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('friend_requests')
                .where('toUserId', isEqualTo: uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, incomingSnapshot) {
              final incomingBySender = <String, String>{
                for (final doc in incomingSnapshot.data?.docs ?? const [])
                  (doc.data()['fromUserId'] ?? '').toString(): doc.id,
              };

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('friend_requests')
                    .where('fromUserId', isEqualTo: uid)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, outgoingSnapshot) {
                  final outgoingTo = <String>{
                    for (final doc in outgoingSnapshot.data?.docs ?? const [])
                      (doc.data()['toUserId'] ?? '').toString(),
                  };

                  final incomingDocs =
                      incomingSnapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final friendDocs =
                      friendsSnapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final panelMinHeight =
                      MediaQuery.of(context).size.height * 0.30;
                  final emptyPanelHeight = (panelMinHeight - 90).clamp(
                    130.0,
                    280.0,
                  );

                  Widget sectionBody;
                  if (_activeSection == 0) {
                    sectionBody = Card(
                      key: const ValueKey('requests-section'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: panelMinHeight,
                          ),
                          child: Column(
                            children: [
                              _sectionHeader(
                                context,
                                icon: Icons.mark_email_unread_outlined,
                                title: 'Incoming Requests',
                                trailing: _statusPill(
                                  context,
                                  '${incomingDocs.length}',
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (incomingDocs.isEmpty) ...[
                                SizedBox(
                                  height: emptyPanelHeight,
                                  child: Center(
                                    child: _emptyStateCard(
                                      context,
                                      'No pending requests.',
                                    ),
                                  ),
                                ),
                              ] else
                                Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < incomingDocs.length;
                                      i++
                                    ) ...[
                                      Builder(
                                        builder: (context) {
                                          final doc = incomingDocs[i];
                                          final data = doc.data();
                                          final fromUsername =
                                              (data['fromUsername'] ?? '')
                                                  .toString();
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  cs.tertiaryContainer,
                                              foregroundColor:
                                                  cs.onTertiaryContainer,
                                              child: const Icon(Icons.person),
                                            ),
                                            title: Text('@$fromUsername'),
                                            trailing: Wrap(
                                              spacing: 8,
                                              children: [
                                                TextButton(
                                                  onPressed: _working
                                                      ? null
                                                      : () => _respond(
                                                          doc.id,
                                                          false,
                                                        ),
                                                  child: const Text('Decline'),
                                                ),
                                                FilledButton(
                                                  onPressed: _working
                                                      ? null
                                                      : () => _respond(
                                                          doc.id,
                                                          true,
                                                        ),
                                                  child: const Text('Accept'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      if (i != incomingDocs.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 56,
                                          endIndent: 4,
                                          color: cs.outlineVariant.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    sectionBody = Card(
                      key: const ValueKey('friends-section'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: panelMinHeight,
                          ),
                          child: Column(
                            children: [
                              _sectionHeader(
                                context,
                                icon: Icons.groups_2_outlined,
                                title: 'Your Friends',
                              ),
                              const SizedBox(height: 10),
                              if (friendDocs.isEmpty) ...[
                                SizedBox(
                                  height: emptyPanelHeight,
                                  child: Center(
                                    child: _emptyStateCard(
                                      context,
                                      'No friends yet.',
                                    ),
                                  ),
                                ),
                              ] else
                                Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < friendDocs.length;
                                      i++
                                    ) ...[
                                      Builder(
                                        builder: (context) {
                                          final doc = friendDocs[i];
                                          final data = doc.data();
                                          final username =
                                              (data['username'] ?? '')
                                                  .toString();
                                          final displayName =
                                              (data['displayName'] ?? '')
                                                  .toString();
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                ),
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  cs.secondaryContainer,
                                              foregroundColor:
                                                  cs.onSecondaryContainer,
                                              child: const Icon(Icons.person),
                                            ),
                                            title: Text('@$username'),
                                            subtitle: displayName.isEmpty
                                                ? null
                                                : Text(displayName),
                                          );
                                        },
                                      ),
                                      if (i != friendDocs.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 56,
                                          endIndent: 4,
                                          color: cs.outlineVariant.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            children: [
                              _sectionHeader(
                                context,
                                icon: Icons.person_search_rounded,
                                title: 'Find People',
                                subtitle:
                                    'Search by username to add new friends.',
                                trailing: _statusPill(
                                  context,
                                  '${friendDocs.length} friends',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search users by username',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _updateSearchQuery('');
                                          },
                                        ),
                                ),
                                onChanged: _updateSearchQuery,
                              ),
                              if (_query.isNotEmpty && _query.length < 2)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Type at least 2 characters to search.',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_query.length >= 2 && _searchFuture != null)
                        FutureBuilder<List<_UserSearchResult>>(
                          future: _searchFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: LinearProgressIndicator(minHeight: 2),
                              );
                            }

                            if (snapshot.hasError) {
                              var message = 'Search failed. Please try again.';
                              final error = snapshot.error;
                              if (error is FirebaseException) {
                                if (error.code == 'permission-denied') {
                                  message =
                                      'Search is blocked by Firestore rules. Deploy the latest rules and try again.';
                                } else if (error.code == 'unavailable') {
                                  message =
                                      'Search is temporarily unavailable. Check your connection and try again.';
                                }
                              }
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: cs.error,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          message,
                                          style: TextStyle(color: cs.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final users =
                                snapshot.data ?? const <_UserSearchResult>[];
                            if (users.isEmpty) {
                              return _emptyStateCard(
                                context,
                                'No users found for "$_query".',
                              );
                            }

                            return Card(
                              child: Column(
                                children: [
                                  for (var i = 0; i < users.length; i++) ...[
                                    Builder(
                                      builder: (context) {
                                        final user = users[i];
                                        final isFriend = friendIds.contains(
                                          user.userId,
                                        );
                                        final hasIncoming = incomingBySender
                                            .containsKey(user.userId);
                                        final hasOutgoing = outgoingTo.contains(
                                          user.userId,
                                        );

                                        Widget trailing;
                                        if (isFriend) {
                                          trailing = _statusPill(
                                            context,
                                            'Friends',
                                          );
                                        } else if (hasIncoming) {
                                          trailing = FilledButton(
                                            onPressed: _working
                                                ? null
                                                : () => _respond(
                                                    incomingBySender[user
                                                        .userId]!,
                                                    true,
                                                  ),
                                            child: const Text('Accept'),
                                          );
                                        } else if (hasOutgoing) {
                                          trailing = const Text('Pending');
                                        } else {
                                          trailing = FilledButton(
                                            onPressed: _working
                                                ? null
                                                : () =>
                                                      _sendRequest(user.userId),
                                            child: const Text('Add'),
                                          );
                                        }

                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 14,
                                              ),
                                          leading: CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                cs.secondaryContainer,
                                            foregroundColor:
                                                cs.onSecondaryContainer,
                                            child: const Icon(Icons.person),
                                          ),
                                          title: Text(
                                            user.username.isEmpty
                                                ? '(no username)'
                                                : '@${user.username}',
                                          ),
                                          subtitle: user.displayName.isEmpty
                                              ? null
                                              : Text(user.displayName),
                                          trailing: trailing,
                                        );
                                      },
                                    ),
                                    if (i != users.length - 1)
                                      Divider(
                                        height: 1,
                                        indent: 64,
                                        endIndent: 14,
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _sectionSwitchButton(
                                  context,
                                  label: 'Requests (${incomingDocs.length})',
                                  icon: Icons.mail_outline,
                                  selected: _activeSection == 0,
                                  onPressed: () {
                                    setState(() => _activeSection = 0);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _sectionSwitchButton(
                                  context,
                                  label: 'Friends (${friendDocs.length})',
                                  icon: Icons.group_outlined,
                                  selected: _activeSection == 1,
                                  onPressed: () {
                                    setState(() => _activeSection = 1);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: sectionBody,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _UserSearchResult {
  const _UserSearchResult({
    required this.userId,
    required this.username,
    required this.usernameLower,
    required this.displayName,
  });

  final String userId;
  final String username;
  final String usernameLower;
  final String displayName;
}
