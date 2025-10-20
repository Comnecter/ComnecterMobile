import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../friends/services/friend_service.dart';
import '../friends/models/friend_model.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends HookConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState<bool>(false);
    // TODO: Load conversations from Firebase/API
    final conversations = useState<List<ChatConversation>>([]);
    
    // Get current user data
    final currentUser = ref.watch(currentUserProvider);
    final userName = currentUser?.displayName ?? 'You';
    final userAvatar = currentUser?.photoURL ?? '👤';

    void openConversation(ChatConversation conversation) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatConversationScreen(
            conversation: conversation,
            currentUserName: userName,
            currentUserAvatar: userAvatar,
          ),
        ),
      );
    }

    String _formatLastSeen(DateTime lastSeen) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    }

    void _startChatWithFriend(Friend friend, BuildContext context) {
      // Check if conversation already exists
      final existingConversation = conversations.value.firstWhere(
        (conv) => conv.name.toLowerCase() == friend.name.toLowerCase(),
        orElse: () => ChatConversation(
          id: '',
          name: '',
          avatar: '',
          lastMessage: '',
          timestamp: DateTime.now(),
          unreadCount: 0,
          isOnline: false,
        ),
      );

      if (existingConversation.id.isNotEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You already have a chat with ${friend.name}')),
        );
        return;
      }

      // Create new conversation
      final newConversation = ChatConversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: friend.name,
        avatar: friend.avatar,
        lastMessage: '', // Will be populated with first real message
        timestamp: DateTime.now(),
        unreadCount: 0,
        isOnline: friend.isOnline,
      );

      conversations.value = [newConversation, ...conversations.value];

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat started with ${friend.name}')),
      );

      // Open the new conversation
      openConversation(newConversation);
    }

    void startNewChat() {
      final friendService = FriendService();
      final friends = friendService.getFriends().where((f) => f.status == FriendStatus.accepted).toList();
      
      if (friends.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Friends Available'),
            content: const Text('You need to add friends first before you can start a chat.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Start New Chat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Friends List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            friend.avatar,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          friend.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          friend.isOnline ? 'Online' : 'Last seen ${_formatLastSeen(friend.lastSeen)}',
                          style: TextStyle(
                            color: friend.isOnline 
                                ? Colors.green 
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chat_bubble_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onTap: () => _startChatWithFriend(friend, context),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Simulate a brief loading state to prevent dark background
    useEffect(() {
      Future.delayed(const Duration(milliseconds: 100), () {
        isLoading.value = false;
      });
      return null;
    }, []);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary, size: 24),
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary, size: 24),
            onPressed: () => context.push('/notifications'),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: Icon(Icons.people, color: Theme.of(context).colorScheme.primary, size: 24),
            onPressed: () => context.push('/friends'),
            tooltip: 'Friends',
          ),
          IconButton(
            icon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: isLoading.value
          ? _buildLoadingState(context)
          : conversations.value.isEmpty
              ? _buildEmptyState(context, startNewChat)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.value.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations.value[index];
                    return _buildConversationTile(context, conversation, openConversation);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: startNewChat,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    ChatConversation conversation,
    Function(ChatConversation) onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(conversation),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          conversation.avatar,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    if (conversation.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.success.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(conversation.timestamp),
                             style: TextStyle(
                              fontSize: 12,
                                 color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage,
                               style: TextStyle(
                                fontSize: 14,
                                 color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                conversation.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading conversations...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, VoidCallback startNewChat) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start chatting with people you meet!',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: startNewChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start New Chat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.day}/${time.month}';
    } else if (difference.inHours > 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ChatConversation {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;

  ChatConversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
  });
}

class ChatConversationScreen extends HookWidget {
  final ChatConversation conversation;
  final String currentUserName;
  final String currentUserAvatar;

  const ChatConversationScreen({
    super.key,
    required this.conversation,
    required this.currentUserName,
    required this.currentUserAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Load messages from Firebase/API based on conversation.id
    final messages = useState<List<ChatMessage>>([]);

    final textController = useTextEditingController();
    final scrollController = useScrollController();

    void sendMessage() {
      if (textController.text.trim().isNotEmpty) {
        final newMessage = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: textController.text.trim(),
          isMe: true,
          timestamp: DateTime.now(),
          senderName: currentUserName,
          senderAvatar: currentUserAvatar,
        );

        messages.value = [...messages.value, newMessage];
        textController.clear();

        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          conversation.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.value.length,
              itemBuilder: (context, index) {
                final message = messages.value[index];
                return _buildMessageBubble(context, message);
              },
            ),
          ),
          _buildMessageInput(context, textController, sendMessage),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  message.senderAvatar,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: message.isMe 
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.surface,
                          Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: message.isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: message.isMe 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isMe
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  currentUserAvatar,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, TextEditingController controller, VoidCallback onSend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onSend,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (difference.inHours > 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String senderName;
  final String senderAvatar;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.senderName,
    required this.senderAvatar,
  });
}
