import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Service for managing user presence and location in Firestore
/// Allows real-time tracking of nearby users
class UserPresenceService {
  static final UserPresenceService _instance = UserPresenceService._internal();
  factory UserPresenceService() => _instance;
  UserPresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  
  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  /// Start tracking user's location and presence
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ Cannot start presence tracking - user not signed in');
        }
        return;
      }

      // Initialize location service
      final hasLocation = await _locationService.initialize();
      if (!hasLocation) {
        if (kDebugMode) {
          print('⚠️ Cannot start presence tracking - no location permission');
        }
        return;
      }

      _isTracking = true;

      // Update location immediately
      await _updateUserLocation();

      // Update location every 30 seconds
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (timer) => _updateUserLocation(),
      );

      if (kDebugMode) {
        print('✅ User presence tracking started');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting presence tracking: $e');
      }
    }
  }

  /// Stop tracking user's location and presence
  Future<void> stopTracking() async {
    _isTracking = false;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    // Mark user as offline
    await _markOffline();

    if (kDebugMode) {
      print('🛑 User presence tracking stopped');
    }
  }

  /// Update user's location in Firestore
  Future<void> _updateUserLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final position = _locationService.currentPosition;
      if (position == null) {
        // Try to get location
        await _locationService.getCurrentLocation();
        final newPosition = _locationService.currentPosition;
        if (newPosition == null) return;
      }

      final lat = _locationService.latitude;
      final lng = _locationService.longitude;

      // Update user document with location and presence
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoURL': user.photoURL,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'location': {
          'latitude': lat,
          'longitude': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'isDetectable': true, // User is visible on radar
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('📍 Location updated: $lat, $lng');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user location: $e');
      }
    }
  }

  /// Mark user as offline
  Future<void> _markOffline() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('👋 User marked as offline');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking user offline: $e');
      }
    }
  }

  /// Get nearby users from Firestore
  /// Returns users within specified radius (in kilometers)
  Future<List<Map<String, dynamic>>> getNearbyUsers({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ Cannot get nearby users - not signed in');
        }
        return [];
      }

      // Calculate bounding box for efficient query
      // Approximate: 1 degree latitude ≈ 111 km
      final latDelta = radiusKm / 111.0;

      final minLat = latitude - latDelta;
      final maxLat = latitude + latDelta;

      // Query Firestore for users in bounding box
      final snapshot = await _firestore
          .collection('users')
          .where('isDetectable', isEqualTo: true)
          .where('location.latitude', isGreaterThanOrEqualTo: minLat)
          .where('location.latitude', isLessThanOrEqualTo: maxLat)
          .get();

      // Filter results to exact radius and exclude self
      final nearbyUsers = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        if (doc.id == user.uid) continue; // Skip self

        final data = doc.data();
        final userLocation = data['location'] as Map<String, dynamic>?;
        
        if (userLocation == null) continue;

        final userLat = userLocation['latitude'] as double?;
        final userLng = userLocation['longitude'] as double?;

        if (userLat == null || userLng == null) continue;

        // Calculate precise distance
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          userLat,
          userLng,
        ) / 1000.0; // Convert to km

        // Only include users within radius
        if (distance <= radiusKm) {
          nearbyUsers.add({
            ...data,
            'distance': distance,
            'distanceKm': distance,
          });
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) {
        final distA = a['distance'] as double;
        final distB = b['distance'] as double;
        return distA.compareTo(distB);
      });

      if (kDebugMode) {
        print('📍 Found ${nearbyUsers.length} nearby users within ${radiusKm}km');
      }

      return nearbyUsers;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting nearby users: $e');
      }
      return [];
    }
  }

  /// Stream of nearby users (real-time updates)
  Stream<List<Map<String, dynamic>>> getNearbyUsersStream({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Calculate bounding box
    final latDelta = radiusKm / 111.0;

    final minLat = latitude - latDelta;
    final maxLat = latitude + latDelta;

    return _firestore
        .collection('users')
        .where('isDetectable', isEqualTo: true)
        .where('location.latitude', isGreaterThanOrEqualTo: minLat)
        .where('location.latitude', isLessThanOrEqualTo: maxLat)
        .snapshots()
        .map((snapshot) {
      final nearbyUsers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        if (doc.id == user.uid) continue; // Skip self

        final data = doc.data();
        final userLocation = data['location'] as Map<String, dynamic>?;

        if (userLocation == null) continue;

        final userLat = userLocation['latitude'] as double?;
        final userLng = userLocation['longitude'] as double?;

        if (userLat == null || userLng == null) continue;

        // Calculate distance
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          userLat,
          userLng,
        ) / 1000.0;

        if (distance <= radiusKm) {
          nearbyUsers.add({
            ...data,
            'distance': distance,
            'distanceKm': distance,
          });
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) {
        final distA = a['distance'] as double;
        final distB = b['distance'] as double;
        return distA.compareTo(distB);
      });

      return nearbyUsers;
    });
  }

  /// Update user's detectability status
  Future<void> setDetectable(bool isDetectable) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'isDetectable': isDetectable,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('👁️ Detectability set to: $isDetectable');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting detectability: $e');
      }
    }
  }
}

