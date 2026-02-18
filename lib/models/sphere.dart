import 'package:cloud_firestore/cloud_firestore.dart';

class Sphere {
  final String id;
  final String name;
  final int memberCount;
  final DateTime createdAt;
  final String? description;
  final String? creatorId;
  final bool isPremade;

  Sphere({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.createdAt,
    this.description,
    this.creatorId,
    this.isPremade = false,
  });

  factory Sphere.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sphere(
      id: doc.id,
      name: data['name'] ?? '',
      memberCount: data['memberCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      creatorId: data['creatorId'],
      isPremade: data['isPremade'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'memberCount': memberCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
      'creatorId': creatorId,
      'isPremade': isPremade,
    };
  }
}

class SphereMember {
  final String userId;
  final String nickname;
  final DateTime joinedAt;

  SphereMember({
    required this.userId,
    required this.nickname,
    required this.joinedAt,
  });

  factory SphereMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SphereMember(
      userId: doc.id,
      nickname: data['nickname'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'nickname': nickname, 'joinedAt': Timestamp.fromDate(joinedAt)};
  }
}
