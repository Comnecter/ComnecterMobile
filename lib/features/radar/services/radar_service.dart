import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/detection_history_service.dart';
import '../../../services/sound_service.dart';
import '../../../services/location_service.dart';
import '../../../services/user_presence_service.dart';

class RadarService {
  static final RadarService _instance = RadarService._internal();
  factory RadarService() => _instance;
  RadarService._internal();

  final StreamController<List<NearbyUser>> _usersController = StreamController<List<NearbyUser>>.broadcast();
  final StreamController<RadarDetection> _detectionController = StreamController<RadarDetection>.broadcast();
  
  Stream<List<NearbyUser>> get usersStream => _usersController.stream;
  Stream<RadarDetection> get detectionStream => _detectionController.stream;

  Timer? _scanTimer;
  bool _isScanning = false;
  RadarSettings _settings = const RadarSettings();
  RadarRangeSettings _rangeSettings = const RadarRangeSettings();
  List<NearbyUser> _currentUsers = [];
  final Random _random = Random();
  final DetectionHistoryService _detectionHistoryService = DetectionHistoryService();
  final LocationService _locationService = LocationService();
  final UserPresenceService _presenceService = UserPresenceService();

  // Initialize the radar service
  Future<void> initialize() async {
    // Initialize detection history service
    await _detectionHistoryService.initialize();
    
    // Initialize location service
    await _locationService.initialize();
    
    // Start tracking user's presence
    await _presenceService.startTracking();
    
    // Load real nearby users
    await _loadNearbyUsers();
  }

  /// Load nearby users from Firestore
  Future<void> _loadNearbyUsers() async {
    try {
      if (!_locationService.hasLocation) {
        if (kDebugMode) {
          print('⚠️ Cannot load nearby users - no location available');
        }
        return;
      }

      final lat = _locationService.latitude;
      final lng = _locationService.longitude;
      final radiusKm = _settings.detectionRangeKm;

      if (kDebugMode) {
        print('📡 Scanning for users within ${radiusKm}km of ($lat, $lng)');
      }

      final nearbyUsersData = await _presenceService.getNearbyUsers(
        latitude: lat,
        longitude: lng,
        radiusKm: radiusKm,
      );

      // Convert Firestore data to NearbyUser objects
      _currentUsers = nearbyUsersData.map((userData) {
        final distance = userData['distanceKm'] as double? ?? 0.0;
        final angle = _random.nextDouble() * 360; // Random angle for radar display
        final signalStrength = (1.0 - (distance / radiusKm)).clamp(0.0, 1.0);

        return NearbyUser(
          id: userData['uid'] as String? ?? '',
          name: userData['displayName'] as String? ?? 'User',
          avatar: userData['photoURL'] as String? ?? '👤',
          distanceKm: distance,
          angleDegrees: angle,
          signalStrength: signalStrength,
          isOnline: userData['isOnline'] as bool? ?? false,
          isDetected: true,
          interests: (userData['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          lastSeen: (userData['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      _usersController.add(_currentUsers);

      if (kDebugMode) {
        print('✅ Loaded ${_currentUsers.length} real nearby users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading nearby users: $e');
      }
      // Fallback to empty list on error
      _currentUsers = [];
      _usersController.add(_currentUsers);
    }
  }

  // Start scanning for users
  Future<void> startScanning() async {
    if (_isScanning) return;
    
    _isScanning = true;
    
    // Start periodic scanning (reload from Firestore every 5 seconds)
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isScanning) {
        _performScan();
      }
    });
    
    // Perform initial scan
    _performScan();
  }

  // Stop scanning
  Future<void> stopScanning() async {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  // Toggle radar visibility (affects both detectability and detection ability)
  void toggleRadarVisibility(bool isVisible) {
    _settings = _settings.copyWith(enableAutoDetection: isVisible);
    
    if (isVisible) {
      // If becoming visible, start scanning if not already scanning
      if (!_isScanning) {
        startScanning();
      }
    } else {
      // If becoming invisible, stop scanning
      stopScanning();
    }
    
    _usersController.add(_currentUsers);
  }

  // Check if radar is visible (can detect and be detected)
  bool get isRadarVisible => _settings.enableAutoDetection;

  // Update radar settings
  void updateSettings(RadarSettings newSettings) {
    _settings = newSettings;
    
    // Restart scanning if currently scanning
    if (_isScanning) {
      stopScanning().then((_) => startScanning());
    }
  }

  // Update range settings
  void updateRangeSettings(RadarRangeSettings newRangeSettings) {
    _rangeSettings = newRangeSettings;
    _settings = _settings.copyWith(detectionRangeKm: newRangeSettings.rangeKm);
    
    // Emit updated users with new range
    _usersController.add(_currentUsers);
    
    // Restart scanning if currently scanning
    if (_isScanning) {
      stopScanning().then((_) => startScanning());
    }
  }

  // Perform a scan for nearby users - reload from Firestore
  void _performScan() {
    if (!_settings.enableAutoDetection) return;

    // Reload real users from Firestore
    _loadNearbyUsers();
  }

  // Manually detect a specific user
  Future<void> manuallyDetectUser(String userId) async {
    final user = _currentUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => throw Exception('User not found'),
    );

    if (!user.isWithinRange(_rangeSettings.rangeKm)) {
      throw Exception('User is out of range');
    }

    final updatedUser = user.copyWith(isDetected: true);
    final index = _currentUsers.indexWhere((u) => u.id == userId);
    _currentUsers[index] = updatedUser;
    
    _usersController.add(_currentUsers);
    _emitDetection(updatedUser, true);
    
    // Save to detection history
    print('RadarService: Manually detecting user ${updatedUser.name} and saving to history');
    _detectionHistoryService.addDetection(updatedUser);
  }

  // Toggle user selection
  void toggleUserSelection(String userId) {
    final index = _currentUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final user = _currentUsers[index];
      _currentUsers[index] = user.copyWith(isSelected: !user.isSelected);
      _usersController.add(_currentUsers);
    }
  }

  // Emit detection event
  void _emitDetection(NearbyUser user, bool isManual) {
    final detection = RadarDetection(
      userId: user.id,
      timestamp: DateTime.now(),
      isManual: isManual,
      signalStrength: user.signalStrength,
      distanceKm: user.distanceKm,
    );

    _detectionController.add(detection);

    // Play sound and vibrate if enabled
    if (_settings.enableSound) {
      _playDetectionSound(isManual);
    }

    if (_settings.enableVibration) {
      _vibrate(isManual);
    }
  }

  // Play detection sound
  void _playDetectionSound(bool isManual) {
    if (isManual) {
      SoundService().playSuccessSound();
    } else {
      SoundService().playRadarPingSound();
    }
  }

  // Vibrate device
  void _vibrate(bool isManual) {
    if (isManual) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// ⚠️ DEPRECATED - MOCK DATA - DO NOT USE IN PRODUCTION ⚠️
  /// This method is kept for backwards compatibility only
  /// Use _loadNearbyUsers() instead which fetches real users from Firestore
  @deprecated
  List<NearbyUser> _generateMockUsers() {
    final names = [
      'Sarah Johnson', 'Mike Chen', 'Emma Wilson', 'Alex Rodriguez',
      'Lisa Park', 'David Kim', 'Maria Garcia', 'James Thompson',
      'Sophie Brown', 'Ryan Davis', 'Olivia White', 'Daniel Lee',
      'Ava Miller', 'Ethan Taylor', 'Isabella Anderson', 'Noah Martinez'
    ];

    final avatars = ['👩', '👨', '👩‍🦰', '👨‍🦱', '👩‍🦳', '👨‍🦳', '👩‍🦲', '👨‍🦲'];
    final interests = [
      ['Music', 'Travel'], ['Sports', 'Gaming'], ['Art', 'Photography'],
      ['Technology', 'Coding'], ['Food', 'Cooking'], ['Fitness', 'Health'],
      ['Reading', 'Writing'], ['Dancing', 'Fashion'], ['Nature', 'Hiking'],
      ['Movies', 'TV Shows'], ['Science', 'Space'], ['History', 'Culture']
    ];

    return List.generate(8, (index) {
      final distance = 0.1 + _random.nextDouble() * (_rangeSettings.rangeKm - 0.1);
      final angle = _random.nextDouble() * 360;
      final signalStrength = (1.0 - (distance / _rangeSettings.rangeKm)).clamp(0.0, 1.0);
      
      return NearbyUser(
        id: 'user_$index',
        name: names[index % names.length],
        avatar: avatars[index % avatars.length],
        distanceKm: distance,
        angleDegrees: angle,
        signalStrength: signalStrength,
        isOnline: _random.nextBool(),
        isDetected: signalStrength > 0.3,
        interests: interests[index % interests.length],
        lastSeen: DateTime.now().subtract(Duration(minutes: _random.nextInt(60))),
      );
    });
  }

  /// ⚠️ DEPRECATED - MOCK DATA - DO NOT USE IN PRODUCTION ⚠️
  /// This method is kept for backwards compatibility only
  @deprecated
  NearbyUser _generateRandomUser() {
    final names = ['New User', 'Anonymous', 'User${_random.nextInt(1000)}'];
    final avatars = ['👤', '👥', '👤'];
    
    final distance = 0.1 + _random.nextDouble() * (_rangeSettings.rangeKm - 0.1);
    final angle = _random.nextDouble() * 360;
    final signalStrength = (1.0 - (distance / _rangeSettings.rangeKm)).clamp(0.0, 1.0);
    
    return NearbyUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: names[_random.nextInt(names.length)],
      avatar: avatars[_random.nextInt(avatars.length)],
      distanceKm: distance,
      angleDegrees: angle,
      signalStrength: signalStrength,
      isOnline: _random.nextBool(),
      isDetected: signalStrength > 0.3,
      interests: ['New', 'User'],
      lastSeen: DateTime.now(),
    );
  }

  // Get current users
  List<NearbyUser> get currentUsers => List.unmodifiable(_currentUsers);

  // Get current settings
  RadarSettings get settings => _settings;
  
  // Get current range settings
  RadarRangeSettings get rangeSettings => _rangeSettings;

  // Check if scanning
  bool get isScanning => _isScanning;

  // Update radar range
  void updateRange(double rangeKm) {
    _settings = _settings.copyWith(detectionRangeKm: rangeKm);
    _rangeSettings = _rangeSettings.copyWith(rangeKm: rangeKm);
    
    // Emit updated users with new range
    _usersController.add(_currentUsers);
  }

  // Update detectability
  void updateDetectability(bool isDetectable) {
    _settings = _settings.copyWith(enableAutoDetection: isDetectable);
    
    // Emit updated users
    _usersController.add(_currentUsers);
  }

  // Get current range
  double getCurrentRange() => _settings.detectionRangeKm;

  // Get current detectability status
  bool getDetectabilityStatus() => _settings.enableAutoDetection;

  // Dispose resources
  void dispose() {
    stopScanning();
    _usersController.close();
    _detectionController.close();
  }
}
