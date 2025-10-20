import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a community in the app
class Community {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final String creatorId;
  final List<String> memberIds;
  final List<String> tags;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.avatar,
    required this.creatorId,
    required this.memberIds,
    this.tags = const [],
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  /// Get member count
  int get memberCount => memberIds.length;

  /// Check if user is a member
  bool isMember(String userId) => memberIds.contains(userId);

  /// Check if user is creator
  bool isCreator(String userId) => creatorId == userId;

  /// Create from Firestore document
  factory Community.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Community(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      avatar: data['avatar'] ?? '👥',
      creatorId: data['creatorId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] ?? {},
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'avatar': avatar,
      'creatorId': creatorId,
      'memberIds': memberIds,
      'tags': tags,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  /// Copy with method
  Community copyWith({
    String? id,
    String? name,
    String? description,
    String? avatar,
    String? creatorId,
    List<String>? memberIds,
    List<String>? tags,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      creatorId: creatorId ?? this.creatorId,
      memberIds: memberIds ?? this.memberIds,
      tags: tags ?? this.tags,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Community(id: $id, name: $name, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Community && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents a community member
class CommunityMember {
  final String userId;
  final String communityId;
  final String role; // 'creator', 'admin', 'moderator', 'member'
  final DateTime joinedAt;
  final bool isActive;

  CommunityMember({
    required this.userId,
    required this.communityId,
    required this.role,
    required this.joinedAt,
    this.isActive = true,
  });

  /// Create from Firestore document
  factory CommunityMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityMember(
      userId: data['userId'] ?? '',
      communityId: data['communityId'] ?? '',
      role: data['role'] ?? 'member',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'communityId': communityId,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
    };
  }

  /// Check if member is creator
  bool get isCreator => role == 'creator';

  /// Check if member is admin
  bool get isAdmin => role == 'admin' || role == 'creator';

  /// Check if member is moderator
  bool get isModerator => role == 'moderator' || isAdmin;
}

