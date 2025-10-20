import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

/// Provider for LocationService
final locationServiceProvider = ChangeNotifierProvider<LocationService>((ref) {
  final service = LocationService();
  // Auto-initialize when provider is first accessed
  service.initialize();
  return service;
});

/// Provider for current position
final currentPositionProvider = Provider<Position?>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.currentPosition;
});

/// Provider for current latitude
final currentLatitudeProvider = Provider<double>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.latitude;
});

/// Provider for current longitude
final currentLongitudeProvider = Provider<double>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.longitude;
});

/// Provider for location permission status
final hasLocationPermissionProvider = Provider<bool>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.hasPermission;
});

/// Provider for checking if location is available
final hasLocationProvider = Provider<bool>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.hasLocation;
});

