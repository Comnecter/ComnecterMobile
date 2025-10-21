import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// Service for managing notifications with Firebase Cloud Messaging
class NotificationServiceFirebase {
  static final NotificationServiceFirebase _instance = NotificationServiceFirebase._internal();
  factory NotificationServiceFirebase() => _instance;
  NotificationServiceFirebase._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize notification service and request permissions
  Future<void> initialize() async {
    if (currentUserId == null) {
      if (kDebugMode) {
        print('⚠️ Cannot initialize NotificationService - not signed in');
      }
      return;
    }

    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✅ Notification permissions granted');
        }

        // Get FCM token
        final token = await _messaging.getToken();
        if (token != null) {
          // Save token to user document for sending notifications
          await _firestore.collection('users').doc(currentUserId).update({
            'fcmToken': token,
            'fcmTokenUpdated': FieldValue.serverTimestamp(),
          });

          if (kDebugMode) {
            print('✅ FCM token saved: ${token.substring(0, 20)}...');
          }
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          await _firestore.collection('users').doc(currentUserId).update({
            'fcmToken': newToken,
            'fcmTokenUpdated': FieldValue.serverTimestamp(),
          });
        });

        // Setup message handlers
        _setupMessageHandlers();
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          print('⚠️ Notification permissions denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing notifications: $e');
      }
    }
  }

  /// Setup FCM message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📨 Foreground notification: ${message.notification?.title}');
      }

      // Create in-app notification
      if (message.notification != null) {
        _createNotificationFromFCM(message);
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 User tapped notification: ${message.notification?.title}');
      }
      
      // TODO: Navigate to relevant screen based on message.data
    });

    // Handle notification tap when app was terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && kDebugMode) {
        print('🔔 App opened from notification: ${message.notification?.title}');
      }
    });
  }

  /// Create notification from FCM message
  Future<void> _createNotificationFromFCM(RemoteMessage message) async {
    if (currentUserId == null) return;

    try {
      final notification = message.notification;
      final data = message.data;

      await createNotification(
        title: notification?.title ?? 'Notification',
        message: notification?.body ?? '',
        type: _parseTypeFromString(data['type'] as String?),
        senderId: data['senderId'] as String?,
        senderName: data['senderName'] as String?,
        senderAvatar: data['senderAvatar'] as String?,
        actionUrl: data['actionUrl'] as String?,
        metadata: data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error creating notification from FCM: $e');
      }
    }
  }

  /// Get notifications stream for current user
  Stream<List<AppNotification>> getNotificationsStream() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return AppNotification.fromFirestore(doc);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error processing notification ${doc.id}: $e');
          }
          // Return default notification on error
          return AppNotification(
            id: doc.id,
            userId: currentUserId!,
            title: 'Notification',
            message: 'Error loading notification',
            type: NotificationType.system,
            timestamp: DateTime.now(),
          );
        }
      }).toList();
    });
  }

  /// Create a notification
  Future<String> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) async {
    if (currentUserId == null) {
      throw Exception('Not signed in');
    }

    try {
      final notificationData = {
        'userId': currentUserId,
        'title': title,
        'message': message,
        'type': _typeToString(type),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'actionUrl': actionUrl,
        'metadata': metadata,
      };

      final docRef = await _firestore.collection('notifications').add(notificationData);

      if (kDebugMode) {
        print('✅ Notification created: $title');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating notification: $e');
      }
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      if (kDebugMode) {
        print('✅ Notification marked as read');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking notification as read: $e');
      }
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (currentUserId == null) return;

    try {
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (kDebugMode) {
        print('✅ Marked ${unreadNotifications.docs.length} notifications as read');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking all as read: $e');
      }
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();

      if (kDebugMode) {
        print('✅ Notification deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting notification: $e');
      }
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    if (currentUserId == null) return;

    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (kDebugMode) {
        print('✅ All notifications deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting all notifications: $e');
      }
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    if (currentUserId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Send notification to another user (via FCM)
  Future<void> sendNotificationToUser({
    required String toUserId,
    required String title,
    required String body,
    required NotificationType type,
    String? actionUrl,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(toUserId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ User has no FCM token');
        }
        return;
      }

      // Create in-app notification
      final currentUser = _auth.currentUser;
      await _firestore.collection('notifications').add({
        'userId': toUserId,
        'title': title,
        'message': body,
        'type': _typeToString(type),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'senderId': currentUser?.uid,
        'senderName': currentUser?.displayName ?? 'User',
        'senderAvatar': currentUser?.photoURL ?? '👤',
        'actionUrl': actionUrl,
        'metadata': data,
      });

      // TODO: Send FCM push notification via Cloud Functions
      // For now, the in-app notification is created
      // You'll need Cloud Functions to send actual push notifications

      if (kDebugMode) {
        print('✅ In-app notification created for user $toUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification: $e');
      }
    }
  }

  /// Helper: Convert type to string
  String _typeToString(NotificationType type) {
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

  /// Helper: Parse type from string
  NotificationType _parseTypeFromString(String? type) {
    switch (type) {
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'message':
        return NotificationType.message;
      case 'event':
        return NotificationType.event;
      case 'community':
        return NotificationType.community;
      default:
        return NotificationType.system;
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationsSubscription?.cancel();
  }
}

