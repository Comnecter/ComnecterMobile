import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'models/notification_model.dart';
import 'services/notification_service_firebase.dart';

class NotificationsScreen extends HookWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = useState<List<AppNotification>>([]);
    final notificationService = useMemoized(() => NotificationServiceFirebase(), []);
    final selectedFilter = useState<String>('all');

    // Load notifications from Firebase
    useEffect(() {
      notificationService.initialize();
      
      final subscription = notificationService.getNotificationsStream().listen((notifs) {
        notifications.value = notifs;
      });
      
      return subscription.cancel;
    }, []);

    Future<void> markAsRead(String notificationId) async {
      await notificationService.markAsRead(notificationId);
    }

    Future<void> deleteNotification(String notificationId) async {
      await notificationService.deleteNotification(notificationId);
    }

    List<AppNotification> getFilteredNotifications() {
      final allNotifications = notifications.value;
      switch (selectedFilter.value) {
        case 'unread':
          return allNotifications.where((n) => !n.isRead).toList();
        case 'friend_request':
          return allNotifications.where((n) => n.type == NotificationType.friendRequest).toList();
        case 'message':
          return allNotifications.where((n) => n.type == NotificationType.message).toList();
        case 'event':
          return allNotifications.where((n) => n.type == NotificationType.event).toList();
        case 'system':
          return allNotifications.where((n) => n.type == NotificationType.system).toList();
        default:
          return allNotifications;
      }
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

  Widget _buildNotificationsList(BuildContext context, ValueNotifier<List<AppNotification>> notificationsState, ValueNotifier<String> selectedFilter, Function(String) markAsRead, Function(String) deleteNotification) {
    final allNotifications = notificationsState.value;
    final filteredNotifications = selectedFilter.value == 'unread'
        ? allNotifications.where((n) => !n.isRead).toList()
        : selectedFilter.value == 'friend_request'
            ? allNotifications.where((n) => n.type == NotificationType.friendRequest).toList()
            : selectedFilter.value == 'message'
                ? allNotifications.where((n) => n.type == NotificationType.message).toList()
                : selectedFilter.value == 'event'
                    ? allNotifications.where((n) => n.type == NotificationType.event).toList()
                    : selectedFilter.value == 'system'
                        ? allNotifications.where((n) => n.type == NotificationType.system).toList()
                        : allNotifications;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = filteredNotifications[index];
        return Dismissible(
          key: Key('notification_${notification.id}'),
          direction: DismissDirection.endToStart,
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
          onDismissed: (direction) async {
            await deleteNotification(notification.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification deleted')),
              );
            }
          },
          child: _buildNotificationCard(context, notification, markAsRead, deleteNotification),
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification, Function(String) markAsRead, Function(String) deleteNotification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead 
          ? Theme.of(context).colorScheme.surface 
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      elevation: notification.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notification.isRead 
            ? BorderSide.none 
            : BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _getNotificationColor(notification.type).withValues(alpha: 0.1),
              child: notification.senderAvatar != null
                  ? Text(notification.senderAvatar!, style: const TextStyle(fontSize: 16))
                  : Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 20,
                    ),
            ),
            if (!notification.isRead)
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
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
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
                  _formatTimestamp(notification.timestamp),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (notification.senderName != null)
                  Text(
                    'from ${notification.senderName}',
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
          onSelected: (value) async {
            switch (value) {
              case 'toggle_read':
                await markAsRead(notification.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        notification.isRead 
                            ? 'Notification marked as unread' 
                            : 'Notification marked as read',
                      ),
                    ),
                  );
                }
                break;
              case 'delete':
                await deleteNotification(notification.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification deleted')),
                  );
                }
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_read',
              child: Text(notification.isRead ? 'Mark as unread' : 'Mark as read'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () {
          if (!notification.isRead) {
            markAsRead(notification.id);
          }
          // TODO: Navigate to relevant screen based on notification type and actionUrl
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

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.community:
        return Icons.groups;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return Colors.blue;
      case NotificationType.message:
        return Colors.green;
      case NotificationType.event:
        return Colors.orange;
      case NotificationType.community:
        return Colors.purple;
      case NotificationType.system:
        return Colors.grey;
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
