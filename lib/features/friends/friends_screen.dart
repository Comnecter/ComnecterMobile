import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';

class FriendsScreen extends HookWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Load friends from Firebase/API
    final friends = useState<List<Map<String, dynamic>>>([]);

    // TODO: Load pending friend requests from Firebase/API
    final pendingRequests = useState<List<Map<String, dynamic>>>([]);

    final currentTab = useState(0);
    final searchQuery = useState('');
    final showAddFriendSearch = useState(false);
    final addFriendSearchQuery = useState('');
    final searchResults = useState<List<Map<String, dynamic>>>([]);

    // TODO: Query users from Firebase/API when searching
    final allUsers = <Map<String, dynamic>>[];

    // Search for users when query changes
    useEffect(() {
      if (addFriendSearchQuery.value.isEmpty) {
        searchResults.value = [];
      } else {
        // TODO: Implement Firebase/API search for users
        // For now, no search results since allUsers is empty
        final query = addFriendSearchQuery.value.toLowerCase();
        searchResults.value = allUsers.where((user) {
          final isNotFriend = !friends.value.any((friend) => friend['username'] == user['username']);
          final matchesQuery = (user['name'] as String).toLowerCase().contains(query) || 
                              (user['username'] as String).toLowerCase().contains(query);
          return isNotFriend && matchesQuery;
        }).toList();
      }
      return null;
    }, [addFriendSearchQuery.value]);

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
          'Friends',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 24),
            onPressed: () => _showSearchDialog(context, searchQuery),
            tooltip: 'Search',
          ),
          IconButton(
            icon: Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary, size: 24),
            onPressed: () {
              showAddFriendSearch.value = true;
              addFriendSearchQuery.value = '';
            },
            tooltip: 'Add Friend',
          ),
        ],
      ),
      body: showAddFriendSearch.value
          ? _buildAddFriendSearch(context, addFriendSearchQuery, searchResults, showAddFriendSearch, friends, pendingRequests)
          : Column(
              children: [
                // Tab Bar
                Container(
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
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          context,
                          'Friends (${friends.value.length})',
                          0,
                          currentTab.value,
                          () => currentTab.value = 0,
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          context,
                          'Requests (${pendingRequests.value.length})',
                          1,
                          currentTab.value,
                          () => currentTab.value = 1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: currentTab.value == 0
                      ? _buildFriendsList(context, friends.value, searchQuery.value)
                      : _buildRequestsList(context, pendingRequests.value),
                ),
              ],
            ),
      floatingActionButton: showAddFriendSearch.value
          ? null
          : FloatingActionButton(
              onPressed: () {
                showAddFriendSearch.value = true;
                addFriendSearchQuery.value = '';
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add),
            ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList(BuildContext context, List<Map<String, dynamic>> friends, String searchQuery) {
    final filteredFriends = friends.where((friend) {
      if (searchQuery.isEmpty) return true;
      final query = searchQuery.toLowerCase();
      return friend['name'].toLowerCase().contains(query) || 
             friend['username'].toLowerCase().contains(query);
    }).toList();

    if (filteredFriends.isEmpty) {
      return _buildEmptyState(
        context,
        searchQuery.isEmpty ? 'No friends yet' : 'No friends found',
        searchQuery.isEmpty ? 'Add some friends to get started!' : 'Try a different search term',
        Icons.people_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        return _buildFriendCard(context, friend);
      },
    );
  }

  Widget _buildRequestsList(BuildContext context, List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return _buildEmptyState(
        context,
        'No pending requests',
        'Friend requests will appear here',
        Icons.person_add_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(context, request);
      },
    );
  }

  Widget _buildFriendCard(BuildContext context, Map<String, dynamic> friend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                friend['avatar'],
                style: const TextStyle(fontSize: 24),
              ),
            ),
            if (friend['isOnline'])
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friend['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${friend['username']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              friend['isOnline'] ? 'Online' : 'Last seen ${friend['lastSeen']}',
              style: TextStyle(
                color: friend['isOnline'] 
                    ? Colors.green 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          onSelected: (value) => _handleFriendAction(context, value, friend),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'message',
              child: Row(
                children: [
                  Icon(Icons.message, size: 20),
                  SizedBox(width: 8),
                  Text('Message'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 20),
                  SizedBox(width: 8),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove Friend', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showFriendProfile(context, friend),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    request['avatar'],
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${request['username']}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request['message'],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequestAction(context, 'accept', request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRequestAction(context, 'decline', request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFriendSearch(BuildContext context, ValueNotifier<String> searchQuery, ValueNotifier<List<Map<String, dynamic>>> searchResults, ValueNotifier<bool> showAddFriendSearch, ValueNotifier<List<Map<String, dynamic>>> friends, ValueNotifier<List<Map<String, dynamic>>> pendingRequests) {
    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  searchQuery.value = '';
                  showAddFriendSearch.value = false;
                },
              ),
              Expanded(
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => searchQuery.value = value,
                  decoration: InputDecoration(
                    hintText: 'Search by name or username...',
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.background,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search Results
        Expanded(
          child: searchQuery.value.isEmpty
              ? _buildEmptyState(
                  context,
                  'Search for users',
                  'Enter a name or username to find people to add as friends',
                  Icons.search,
                )
              : searchResults.value.isEmpty
                  ? _buildEmptyState(
                      context,
                      'No users found',
                      'Try searching with a different name or username',
                      Icons.person_search,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: searchResults.value.length,
                      itemBuilder: (context, index) {
                        final user = searchResults.value[index];
                        return _buildUserSearchCard(context, user, searchResults, pendingRequests);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserSearchCard(BuildContext context, Map<String, dynamic> user, ValueNotifier<List<Map<String, dynamic>>> searchResults, ValueNotifier<List<Map<String, dynamic>>> pendingRequests) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                user['avatar'],
                style: const TextStyle(fontSize: 24),
              ),
            ),
            if (user['isOnline'])
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          user['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user['username']}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user['isOnline'] ? 'Online' : 'Offline',
              style: TextStyle(
                color: user['isOnline'] 
                    ? Colors.green 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _sendFriendRequest(context, user, searchResults, pendingRequests),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Add'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context, ValueNotifier<String> searchQuery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Friends'),
        content: TextField(
          onChanged: (value) => searchQuery.value = value,
          decoration: const InputDecoration(
            hintText: 'Enter name or username...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _sendFriendRequest(BuildContext context, Map<String, dynamic> user, ValueNotifier<List<Map<String, dynamic>>> searchResults, ValueNotifier<List<Map<String, dynamic>>> pendingRequests) {
    // TODO: Implement actual friend request functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Friend request sent to ${user['name']} (@${user['username']})!')),
    );
    
    // Add to pending requests for demo purposes
    pendingRequests.value = [
      ...pendingRequests.value,
      {
        'id': 'req_${user['id']}',
        'name': user['name'],
        'username': user['username'],
        'avatar': user['avatar'],
        'message': 'Friend request sent',
        'timestamp': DateTime.now(),
      },
    ];
    
    // Remove from search results
    searchResults.value = searchResults.value.where((u) => u['id'] != user['id']).toList();
  }

  void _handleFriendAction(BuildContext context, String action, Map<String, dynamic> friend) {
    switch (action) {
      case 'message':
        // TODO: Navigate to chat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening chat with ${friend['name']}')),
        );
        break;
      case 'profile':
        // TODO: Navigate to profile
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing ${friend['name']}\'s profile')),
        );
        break;
      case 'remove':
        _showRemoveFriendDialog(context, friend);
        break;
    }
  }

  void _handleRequestAction(BuildContext context, String action, Map<String, dynamic> request) {
    // TODO: Implement request handling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request ${action}ed')),
    );
  }

  void _showFriendProfile(BuildContext context, Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(friend['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                friend['avatar'],
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              friend['isOnline'] ? 'Online' : 'Last seen ${friend['lastSeen']}',
              style: TextStyle(
                color: friend['isOnline'] 
                    ? Colors.green 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to chat
            },
            child: const Text('Message'),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(BuildContext context, Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to remove ${friend['name']} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement remove friend
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${friend['name']} removed from friends')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}