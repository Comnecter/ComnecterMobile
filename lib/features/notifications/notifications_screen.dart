import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends HookWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Load notifications from Firebase Cloud Messaging / Cloud Functions
    final notifications = useState<List<Map<String, dynamic>>>([]);

    final selectedFilter = useState<String>('all');

    List<Map<String, dynamic>> getFilteredNotifications() {
      final allNotifications = notifications.value;
      switch (selectedFilter.value) {
        case 'unread':
          return allNotifications.where((n) => !n['isRead']).toList();
        case 'friend_request':
          return allNotifications.where((n) => n['type'] == 'friend_request').toList();
        case 'message':
          return allNotifications.where((n) => n['type'] == 'message').toList();
        case 'event':
          return allNotifications.where((n) => n['type'] == 'event').toList();
        case 'system':
          return allNotifications.where((n) => n['type'] == 'system').toList();
        default:
          return allNotifications;
      }
    }

    void markAsRead(String notificationId) {
      final index = notifications.value.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        notifications.value = List.from(notifications.value);
        notifications.value[index] = {
          ...notifications.value[index],
          'isRead': true,
        };
      }
    }

    void deleteNotification(String notificationId) {
      notifications.value = notifications.value.where((n) => n['id'] != notificationId).toList();
    }


    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary, size: 24),
          onPressed: () => context.pop(),
          tooltip: 'Go Back',
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary, size: 24),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(context, selectedFilter),
          
          // Notifications list
          Expanded(
            child: getFilteredNotifications().isEmpty
                ? _buildEmptyState(context, selectedFilter.value)
                : _buildNotificationsList(context, notifications, selectedFilter, markAsRead, deleteNotification),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, ValueNotifier<String> selectedFilter) {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'unread', 'label': 'Unread'},
      {'key': 'friend_request', 'label': 'Friends'},
      {'key': 'message', 'label': 'Messages'},
      {'key': 'event', 'label': 'Events'},
      {'key': 'system', 'label': 'System'},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter.value == filter['key'];
          
          return GestureDetector(
            onTap: () => selectedFilter.value = filter['key'] as String,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filter['label'] as String,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white 
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context, ValueNotifier<List<Map<String, dynamic>>> notificationsState, ValueNotifier<String> selectedFilter, Function(String) markAsRead, Function(String) deleteNotification) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: notificationsState,
      builder: (context, currentNotifications, child) {
        final filteredNotifications = currentNotifications.where((notification) {
          if (selectedFilter.value.toLowerCase() == 'all') return true;
          if (selectedFilter.value.toLowerCase() == 'unread') return !notification['isRead'];
          if (selectedFilter.value.toLowerCase() == 'friend requests') return notification['type'] == 'friend_request';
          if (selectedFilter.value.toLowerCase() == 'messages') return notification['type'] == 'message';
          if (selectedFilter.value.toLowerCase() == 'events') return notification['type'] == 'event';
          if (selectedFilter.value.toLowerCase() == 'system') return notification['type'] == 'system';
          return true;
        }).toList();
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredNotifications.length,
          itemBuilder: (context, index) {
            final notification = filteredNotifications[index];
            return Dismissible(
              key: Key('notification_${notification['id']}'),
              direction: DismissDirection.endToStart, // Only allow swipe left (delete)
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Delete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Notification'),
                    content: const Text('Are you sure you want to delete this notification?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (direction) {
                // Delete notification
                final updatedNotifications = notificationsState.value.where((n) => n['id'] != notification['id']).toList();
                notificationsState.value = updatedNotifications;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification deleted')),
                );
              },
              child: _buildNotificationCard(context, notification, notificationsState, markAsRead, deleteNotification),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> notification, ValueNotifier<List<Map<String, dynamic>>> notificationsState, Function(String) markAsRead, Function(String) deleteNotification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification['isRead'] 
          ? Theme.of(context).colorScheme.surface 
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      elevation: notification['isRead'] ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notification['isRead'] 
            ? BorderSide.none 
            : BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _getNotificationColor(notification['type']).withValues(alpha: 0.1),
              child: notification['avatar'] != null
                  ? Text(notification['avatar'], style: const TextStyle(fontSize: 16))
                  : Icon(
                      _getNotificationIcon(notification['type']),
                      color: _getNotificationColor(notification['type']),
                      size: 20,
                    ),
            ),
            if (!notification['isRead'])
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: notification['isRead'] ? FontWeight.normal : FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'],
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(notification['timestamp']),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (notification['senderName'] != null)
                  Text(
                    'from ${notification['senderName']}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          onSelected: (value) {
            switch (value) {
              case 'toggle_read':
                final index = notificationsState.value.indexWhere((n) => n['id'] == notification['id']);
                if (index != -1) {
                  final updatedNotifications = List<Map<String, dynamic>>.from(notificationsState.value);
                  updatedNotifications[index] = {
                    ...updatedNotifications[index],
                    'isRead': !updatedNotifications[index]['isRead'],
                  };
                  notificationsState.value = updatedNotifications;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      notification['isRead'] 
                          ? 'Notification marked as unread' 
                          : 'Notification marked as read',
                    ),
                  ),
                );
                break;
              case 'delete':
                final updatedNotifications = notificationsState.value.where((n) => n['id'] != notification['id']).toList();
                notificationsState.value = updatedNotifications;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification deleted')),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_read',
              child: Text(notification['isRead'] ? 'Mark as unread' : 'Mark as read'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () {
          if (!notification['isRead']) {
            markAsRead(notification['id']);
          }
          // TODO: Navigate to relevant screen based on notification type
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String filter) {
    String title;
    String subtitle;
    IconData icon;

    switch (filter) {
      case 'unread':
        title = 'No unread notifications';
        subtitle = 'You\'re all caught up!';
        icon = Icons.notifications_none;
        break;
      case 'friend_request':
        title = 'No friend requests';
        subtitle = 'Friend requests will appear here';
        icon = Icons.person_add;
        break;
      case 'message':
        title = 'No message notifications';
        subtitle = 'Message notifications will appear here';
        icon = Icons.message;
        break;
      case 'event':
        title = 'No event notifications';
        subtitle = 'Event invitations will appear here';
        icon = Icons.event;
        break;
      case 'system':
        title = 'No system notifications';
        subtitle = 'System updates will appear here';
        icon = Icons.info;
        break;
      default:
        title = 'No notifications';
        subtitle = 'You\'ll see notifications here when they arrive';
        icon = Icons.notifications_none;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.onBackground.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'message':
        return Icons.message;
      case 'event':
        return Icons.event;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'friend_request':
        return Colors.blue;
      case 'message':
        return Colors.green;
      case 'event':
        return Colors.orange;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
