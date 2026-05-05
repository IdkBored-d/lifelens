import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SocialUserProfile {
  const SocialUserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
  });

  final String uid;
  final String username;
  final String displayName;
}

class SocialFeatures {
  SocialFeatures._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String normalizeUsername(String input) {
    var value = input.trim().toLowerCase();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  static bool isValidUsername(String input) {
    final normalized = normalizeUsername(input);
    return RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch(normalized);
  }

  static Future<SocialUserProfile?> getCurrentUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return getUserProfile(uid);
  }

  static Future<SocialUserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? <String, dynamic>{};
    final username = (data['username'] ?? '').toString().trim();
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final displayName = [
      first,
      last,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final fallbackName = (displayName.isEmpty ? username : displayName).trim();
    if (username.isEmpty) {
      return SocialUserProfile(
        uid: uid,
        username: fallbackName.isEmpty ? 'member' : fallbackName,
        displayName: fallbackName.isEmpty ? 'Member' : fallbackName,
      );
    }
    return SocialUserProfile(
      uid: uid,
      username: username,
      displayName: fallbackName.isEmpty ? username : fallbackName,
    );
  }

  static Future<void> sendFriendRequest({required String toUserId}) async {
    final fromUserId = FirebaseAuth.instance.currentUser?.uid;
    if (fromUserId == null) {
      throw Exception('You must be signed in.');
    }
    if (fromUserId == toUserId) {
      throw Exception('You cannot friend yourself.');
    }

    final existingFriend = await _firestore
        .collection('users')
        .doc(fromUserId)
        .collection('friends')
        .doc(toUserId)
        .get();
    if (existingFriend.exists) {
      throw Exception('You are already friends.');
    }

    final pendingForward = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingForward.docs.isNotEmpty) {
      throw Exception('Friend request already sent.');
    }

    final pendingReverse = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: toUserId)
        .where('toUserId', isEqualTo: fromUserId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingReverse.docs.isNotEmpty) {
      throw Exception('This user already sent you a friend request.');
    }

    final fromProfile = await getUserProfile(fromUserId);
    final toProfile = await getUserProfile(toUserId);
    if (fromProfile == null || toProfile == null) {
      throw Exception('Unable to find user profiles.');
    }

    await _firestore.collection('friend_requests').add({
      'fromUserId': fromUserId,
      'fromUsername': fromProfile.username,
      'toUserId': toUserId,
      'toUsername': toProfile.username,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> respondToFriendRequest({
    required String requestId,
    required bool accept,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('You must be signed in.');
    }

    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw Exception('Friend request no longer exists.');
    }

    final data = requestDoc.data() ?? <String, dynamic>{};
    final fromUserId = (data['fromUserId'] ?? '').toString();
    final toUserId = (data['toUserId'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    if (toUserId != currentUserId) {
      throw Exception('Only the recipient can respond.');
    }
    if (status != 'pending') {
      throw Exception('This request is no longer pending.');
    }

    final batch = _firestore.batch();
    batch.update(requestRef, {
      'status': accept ? 'accepted' : 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      final fromProfile = await getUserProfile(fromUserId);
      final toProfile = await getUserProfile(toUserId);
      if (fromProfile == null || toProfile == null) {
        throw Exception('Unable to find user profiles.');
      }

      final fromFriendRef = _firestore
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .doc(toUserId);
      final toFriendRef = _firestore
          .collection('users')
          .doc(toUserId)
          .collection('friends')
          .doc(fromUserId);

      batch.set(fromFriendRef, {
        'userId': toUserId,
        'username': toProfile.username,
        'displayName': toProfile.displayName,
        'addedAt': FieldValue.serverTimestamp(),
      });
      batch.set(toFriendRef, {
        'userId': fromUserId,
        'username': fromProfile.username,
        'displayName': fromProfile.displayName,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  static Future<int> sendSphereInvites({
    required String sphereId,
    required String sphereName,
    required List<String> friendUserIds,
  }) async {
    final sender = await getCurrentUserProfile();
    if (sender == null) {
      throw Exception('You must be signed in.');
    }

    var sent = 0;
    for (final friendId in friendUserIds.toSet()) {
      if (friendId == sender.uid) continue;

      // Use a deterministic doc ID so we never need a prior read (which the
      // Firestore rules deny) and naturally deduplicate concurrent invites.
      final docId = '${sphereId}_${sender.uid}';
      final inviteRef = _firestore
          .collection('users')
          .doc(friendId)
          .collection('sphere_invites')
          .doc(docId);

      try {
        await inviteRef.set({
          'sphereId': sphereId,
          'sphereName': sphereName,
          'fromUserId': sender.uid,
          'fromUsername': sender.username,
          'toUserId': friendId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
        sent += 1;
      } on FirebaseException catch (e) {
        // permission-denied means the doc already exists (update not allowed);
        // treat that as already-invited and count it as sent.
        if (e.code == 'permission-denied') {
          sent += 1;
        } else {
          rethrow;
        }
      }
    }

    return sent;
  }

  static Future<List<String>?> showFriendPicker(
    BuildContext context, {
    required String title,
    String actionLabel = 'Invite',
    Set<String> excludeUserIds = const <String>{},
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value(<String>[]);

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _FriendPickerSheet(
          userId: uid,
          title: title,
          actionLabel: actionLabel,
          excludeUserIds: excludeUserIds,
        );
      },
    );
  }
}

class _FriendPickerSheet extends StatefulWidget {
  const _FriendPickerSheet({
    required this.userId,
    required this.title,
    required this.actionLabel,
    this.excludeUserIds = const <String>{},
  });

  final String userId;
  final String title;
  final String actionLabel;
  final Set<String> excludeUserIds;

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .collection('friends')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allDocs = snapshot.data!.docs;
                    final docs = widget.excludeUserIds.isEmpty
                        ? allDocs
                        : allDocs
                              .where(
                                (d) => !widget.excludeUserIds.contains(d.id),
                              )
                              .toList(growable: false);
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          allDocs.isEmpty
                              ? 'No friends yet.'
                              : 'All your friends are already in this sphere.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final friendId = doc.id;
                        final data = doc.data();
                        final username = (data['username'] ?? '').toString();
                        final displayName = (data['displayName'] ?? '')
                            .toString();
                        final selected = _selected.contains(friendId);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (_) {
                            setState(() {
                              if (selected) {
                                _selected.remove(friendId);
                              } else {
                                _selected.add(friendId);
                              }
                            });
                          },
                          title: Text(
                            username.isEmpty ? displayName : '@$username',
                          ),
                          subtitle: displayName.isEmpty
                              ? null
                              : Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(_selected.toList(growable: false));
                  },
                  child: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
