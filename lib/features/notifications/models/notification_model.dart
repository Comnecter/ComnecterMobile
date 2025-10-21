import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification type enum
enum NotificationType {
  friendRequest,
  message,
  event,
  community,
  system,
}

/// Notification model
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? actionUrl; // Deep link for navigation
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.actionUrl,
    this.metadata,
  });

  /// Create from Firestore document
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      type: _parseType(data['type'] as String?),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      senderAvatar: data['senderAvatar'] as String?,
      actionUrl: data['actionUrl'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Parse type string to enum
  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'message':
        return NotificationType.message;
      case 'event':
        return NotificationType.event;
      case 'community':
        return NotificationType.community;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  /// Convert type enum to string
  String get typeString {
    switch (type) {
      case NotificationType.friendRequest:
        return 'friend_request';
      case NotificationType.message:
        return 'message';
      case NotificationType.event:
        return 'event';
      case NotificationType.community:
        return 'community';
      case NotificationType.system:
        return 'system';
    }
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': typeString,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'actionUrl': actionUrl,
      'metadata': metadata,
    };
  }

  /// Copy with modifications
  AppNotification copyWith({
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      actionUrl: actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}

