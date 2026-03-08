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
  final int warningCount;

  SphereMember({
    required this.userId,
    required this.nickname,
    required this.joinedAt,
    this.warningCount = 0,
  });

  factory SphereMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SphereMember(
      userId: doc.id,
      nickname: data['nickname'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      warningCount: data['warningCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'warningCount': warningCount,
    };
  }
}

/// Warning record for content moderation
class UserWarning {
  final String userId;
  final String sphereId;
  final DateTime timestamp;
  final String reason;
  final String messageContent;

  UserWarning({
    required this.userId,
    required this.sphereId,
    required this.timestamp,
    required this.reason,
    required this.messageContent,
  });

  factory UserWarning.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserWarning(
      userId: data['userId'] ?? '',
      sphereId: data['sphereId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] ?? '',
      messageContent: data['messageContent'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sphereId': sphereId,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
      'messageContent': messageContent,
    };
  }
}
