import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';

/// Provider for community service
final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

/// Provider for user communities stream
final userCommunitiesStreamProvider = StreamProvider<List<Community>>((ref) {
  final service = ref.watch(communityServiceProvider);
  return service.getUserCommunitiesStream();
});

/// Provider for fetching a specific community
final communityProvider = FutureProvider.family<Community?, String>((ref, communityId) async {
  final service = ref.watch(communityServiceProvider);
  return service.getCommunity(communityId);
});

/// Provider for community members
final communityMembersProvider = FutureProvider.family<List<CommunityMember>, String>((ref, communityId) async {
  final service = ref.watch(communityServiceProvider);
  return service.getCommunityMembers(communityId);
});

