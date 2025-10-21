import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service for managing user location and GPS functionality
/// Provides real-time location updates for nearby user detection
class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isInitialized = false;
  bool _hasPermission = false;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStream;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  String? get errorMessage => _errorMessage;
  
  double get latitude => _currentPosition?.latitude ?? 0.0;
  double get longitude => _currentPosition?.longitude ?? 0.0;
  
  bool get hasLocation => _currentPosition != null;

  /// Initialize location service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return _hasPermission;

    try {
      if (kDebugMode) {
        print('📍 Initializing Location Service...');
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled. Please enable GPS.';
        if (kDebugMode) {
          print('❌ $_errorMessage');
        }
        notifyListeners();
        return false;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permissions are denied.';
          if (kDebugMode) {
            print('❌ $_errorMessage');
          }
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permissions are permanently denied. Please enable in settings.';
        if (kDebugMode) {
          print('❌ $_errorMessage');
        }
        notifyListeners();
        return false;
      }

      // Permission granted - get current location
      _hasPermission = true;
      await getCurrentLocation();
      
      // Start listening to location updates
      _startLocationUpdates();

      _isInitialized = true;
      if (kDebugMode) {
        print('✅ Location Service initialized successfully');
        print('📍 Current location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize location service: $e';
      if (kDebugMode) {
        print('❌ $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      if (kDebugMode) {
        print('📍 Getting current location...');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _errorMessage = null;

      if (kDebugMode) {
        print('✅ Location updated: ${position.latitude}, ${position.longitude}');
      }

      notifyListeners();
      return position;
    } catch (e) {
      _errorMessage = 'Failed to get current location: $e';
      if (kDebugMode) {
        print('❌ $_errorMessage');
      }
      notifyListeners();
      return null;
    }
  }

  /// Start listening to location updates
  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentPosition = position;
        _errorMessage = null;
        
        if (kDebugMode) {
          print('📍 Location updated: ${position.latitude}, ${position.longitude}');
        }
        
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Location update error: $error';
        if (kDebugMode) {
          print('❌ $_errorMessage');
        }
        notifyListeners();
      },
    );
  }

  /// Stop listening to location updates
  void stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
    
    if (kDebugMode) {
      print('🛑 Location updates stopped');
    }
  }

  /// Calculate distance between two coordinates in meters
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Calculate distance from current location to a point
  double? getDistanceFromCurrentLocation({
    required double latitude,
    required double longitude,
  }) {
    if (_currentPosition == null) return null;
    
    return calculateDistance(
      lat1: _currentPosition!.latitude,
      lon1: _currentPosition!.longitude,
      lat2: latitude,
      lon2: longitude,
    );
  }

  /// Check if location services are available
  Future<bool> checkLocationServices() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking location services: $e');
      }
      return false;
    }
  }

  /// Check permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open app settings (for when permission is permanently denied)
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Clean up resources
  @override
  void dispose() {
    stopLocationUpdates();
    _usersController.close();
    super.dispose();
  }

  final StreamController<void> _usersController = StreamController<void>.broadcast();
}

/// Location permission status result
class LocationPermissionResult {
  final bool hasPermission;
  final String? errorMessage;
  final bool isPermanentlyDenied;

  LocationPermissionResult({
    required this.hasPermission,
    this.errorMessage,
    this.isPermanentlyDenied = false,
  });

  factory LocationPermissionResult.granted() => LocationPermissionResult(
        hasPermission: true,
      );

  factory LocationPermissionResult.denied(String message, {bool permanent = false}) =>
      LocationPermissionResult(
        hasPermission: false,
        errorMessage: message,
        isPermanentlyDenied: permanent,
      );
}

