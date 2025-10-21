import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../../notifications/services/notification_service_firebase.dart';
import '../../notifications/models/notification_model.dart';

/// Service for managing chat conversations and messages with Firebase
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get conversations stream for current user
  Stream<List<ChatConversation>> getConversationsStream() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <ChatConversation>[];
      
      for (final doc in snapshot.docs) {
        try {
          final conv = ChatConversation.fromFirestore(doc);
          
          // Get online status of the other participant (for 1-on-1 chats)
          if (conv.participantId != null && conv.participantId!.isNotEmpty) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(conv.participantId)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data()!;
                final isOnline = userData['isOnline'] as bool? ?? false;
                conversations.add(conv.copyWith(isOnline: isOnline));
              } else {
                conversations.add(conv);
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Error fetching user status: $e');
              }
              conversations.add(conv);
            }
          } else {
            conversations.add(conv);
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error processing conversation ${doc.id}: $e');
          }
        }
      }
      
      return conversations;
    });
  }

  /// Get messages stream for a conversation
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return ChatMessage.fromFirestore(doc);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error processing message ${doc.id}: $e');
          }
          // Return a default message on error
          return ChatMessage(
            id: doc.id,
            conversationId: conversationId,
            senderId: '',
            senderName: 'Unknown',
            senderAvatar: '👤',
            text: '[Error loading message]',
            timestamp: DateTime.now(),
          );
        }
      }).toList();
    });
  }

  /// Create or get existing conversation with a user
  Future<String> createOrGetConversation({
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
  }) async {
    if (currentUserId == null) {
      throw Exception('Not signed in');
    }

    try {
      // Check if conversation already exists
      final existingConversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      for (final doc in existingConversations.docs) {
        final data = doc.data();
        final participantIds = (data['participantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        
        if (participantIds.contains(otherUserId) && participantIds.length == 2) {
          // Conversation exists
          return doc.id;
        }
      }

      // Create new conversation
      final currentUser = _auth.currentUser!;
      final conversationData = {
        'name': otherUserName,
        'avatar': otherUserAvatar,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'isOnline': false,
        'participantIds': [currentUserId, otherUserId],
        'participantId': otherUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('conversations').add(conversationData);
      
      // Also create a conversation document for the other user's view
      final otherConversationData = {
        'name': currentUser.displayName ?? 'User',
        'avatar': currentUser.photoURL ?? '👤',
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'isOnline': false,
        'participantIds': [currentUserId, otherUserId],
        'participantId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('conversations').add(otherConversationData);

      if (kDebugMode) {
        print('✅ Created new conversation with $otherUserName');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating conversation: $e');
      }
      rethrow;
    }
  }

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? imageUrl,
  }) async {
    if (currentUserId == null) {
      throw Exception('Not signed in');
    }

    if (text.trim().isEmpty && imageUrl == null) {
      throw Exception('Message cannot be empty');
    }

    try {
      final currentUser = _auth.currentUser!;
      
      // Create message
      final messageData = {
        'conversationId': conversationId,
        'senderId': currentUserId,
        'senderName': currentUser.displayName ?? 'User',
        'senderAvatar': currentUser.photoURL ?? '👤',
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'imageUrl': imageUrl,
      };

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation's last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': text.trim().isNotEmpty ? text.trim() : '📷 Image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Increment unread count for other participants
      final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
      if (conversationDoc.exists) {
        final data = conversationDoc.data()!;
        final participantIds = (data['participantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        
        for (final participantId in participantIds) {
          if (participantId != currentUserId) {
            // Find their conversation document and increment unread
            final theirConversations = await _firestore
                .collection('conversations')
                .where('participantIds', arrayContains: participantId)
                .where('participantId', isEqualTo: currentUserId)
                .get();
            
            for (final doc in theirConversations.docs) {
              await doc.reference.update({
                'unreadCount': FieldValue.increment(1),
                'lastMessage': text.trim().isNotEmpty ? text.trim() : '📷 Image',
                'lastMessageTime': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      // Send notification to other participants
      try {
        final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
        if (conversationDoc.exists) {
          final data = conversationDoc.data()!;
          final participantIds = (data['participantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final currentUser = _auth.currentUser!;
          
          for (final participantId in participantIds) {
            if (participantId != currentUserId) {
              final notificationService = NotificationServiceFirebase();
              await notificationService.sendNotificationToUser(
                toUserId: participantId,
                title: 'New Message',
                body: '${currentUser.displayName ?? "Someone"}: ${text.length > 50 ? "${text.substring(0, 50)}..." : text}',
                type: NotificationType.message,
                actionUrl: '/chat',
                data: {'conversationId': conversationId},
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to send message notification: $e');
        }
      }

      if (kDebugMode) {
        print('✅ Message sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending message: $e');
      }
      rethrow;
    }
  }

  /// Mark messages as read in a conversation
  Future<void> markAsRead(String conversationId) async {
    if (currentUserId == null) return;

    try {
      // Reset unread count
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': 0,
      });

      // Mark all messages as read
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (kDebugMode) {
        print('✅ Marked ${messages.docs.length} messages as read');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error marking messages as read: $e');
      }
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    if (currentUserId == null) return;

    try {
      // Delete all messages first
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete conversation
      await _firestore.collection('conversations').doc(conversationId).delete();

      if (kDebugMode) {
        print('✅ Conversation deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting conversation: $e');
      }
      rethrow;
    }
  }

  /// Get unread message count
  Future<int> getUnreadCount() async {
    if (currentUserId == null) return 0;

    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      int total = 0;
      for (final doc in conversations.docs) {
        final data = doc.data();
        total += (data['unreadCount'] as int?) ?? 0;
      }

      return total;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error getting unread count: $e');
      }
      return 0;
    }
  }
}

