import 'package:cloud_firestore/cloud_firestore.dart';

class Sphere {
  final String id;
  final String name;
  final int memberCount;
  final DateTime createdAt;
  final String? description;
  final String? creatorId;
  final bool isPremade;
  final String? pinnedTitle;
  final String? pinnedBody;
  final String? lastActivityText;
  final DateTime? lastActivityAt;
  final String? dailyPrompt;
  final String? dailyPromptDateKey;
  final String? pinnedPostId;
  final String? bannerUrl;
  final String? bannerTemplate;

  Sphere({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.createdAt,
    this.description,
    this.creatorId,
    this.isPremade = false,
    this.pinnedTitle,
    this.pinnedBody,
    this.lastActivityText,
    this.lastActivityAt,
    this.dailyPrompt,
    this.dailyPromptDateKey,
    this.pinnedPostId,
    this.bannerUrl,
    this.bannerTemplate,
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
      pinnedTitle: data['pinnedTitle'],
      pinnedBody: data['pinnedBody'],
      lastActivityText: data['lastActivityText'],
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate(),
      dailyPrompt: data['dailyPrompt'],
      dailyPromptDateKey: data['dailyPromptDateKey'],
      pinnedPostId: data['pinnedPostId'],
      bannerUrl: data['bannerUrl'],
      bannerTemplate: data['bannerTemplate'],
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
      'pinnedTitle': pinnedTitle,
      'pinnedBody': pinnedBody,
      'lastActivityText': lastActivityText,
      'lastActivityAt': lastActivityAt == null
          ? null
          : Timestamp.fromDate(lastActivityAt!),
      'dailyPrompt': dailyPrompt,
      'dailyPromptDateKey': dailyPromptDateKey,
      'pinnedPostId': pinnedPostId,
      'bannerUrl': bannerUrl,
      'bannerTemplate': bannerTemplate,
    };
  }
}

class SphereMember {
  final String userId;
  final String nickname;
  final DateTime joinedAt;
  final int warningCount;
  final DateTime? lastReadAt;
  final DateTime? lastActiveAt;
  final String? role;

  SphereMember({
    required this.userId,
    required this.nickname,
    required this.joinedAt,
    this.warningCount = 0,
    this.lastReadAt,
    this.lastActiveAt,
    this.role,
  });

  factory SphereMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SphereMember(
      userId: doc.id,
      nickname: data['nickname'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      warningCount: data['warningCount'] ?? 0,
      lastReadAt: (data['lastReadAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      role: data['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'warningCount': warningCount,
      'lastReadAt': lastReadAt == null ? null : Timestamp.fromDate(lastReadAt!),
      'lastActiveAt': lastActiveAt == null
          ? null
          : Timestamp.fromDate(lastActiveAt!),
      'role': role,
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
