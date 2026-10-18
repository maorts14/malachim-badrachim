import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/domain/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_location.dart';

class LocationRepository {
  LocationRepository._internal()
      : _apiClient = RestApiService(),
        _locationService = LocationService();

  static final LocationRepository _instance = LocationRepository._internal();

  factory LocationRepository() => _instance;

  final RestApiService _apiClient;
  final LocationService _locationService;

  StreamSubscription<Position>? _positionSubscription;
  static const _pendingLocationKey = 'pending_location_update_v1';

  Future<void> startTracking() async {
    await _positionSubscription?.cancel();
    final initialPosition = await _locationService.startTracking();
    if (initialPosition == null) return;

    await _flushPendingLocation();
    await _sendOrQueue(initialPosition);
    _positionSubscription = _locationService.watchPosition().listen(
      (position) => unawaited(_sendOrQueue(position)),
      onError: (_) {
        // A later position update will retry; no stale error should terminate
        // responder tracking while the app stays open.
      },
    );
  }

  void stopTracking() async {
    await _positionSubscription?.cancel();
    await _locationService.stopTracking();
  }

  Future<List<UserLocation>> getAllUserLocations() =>
      _apiClient.getAllUsersLocation();

  Future<void> _sendOrQueue(Position position) async {
    try {
      await _apiClient.updateCurrentUserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _clearPendingLocation();
    } catch (_) {
      await _savePendingLocation(position);
    }
  }

  Future<void> _flushPendingLocation() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_pendingLocationKey);
    if (saved == null) return;
    try {
      final location = jsonDecode(saved) as Map<String, dynamic>;
      await _apiClient.updateCurrentUserLocation(
        latitude: (location['latitude'] as num).toDouble(),
        longitude: (location['longitude'] as num).toDouble(),
      );
      await preferences.remove(_pendingLocationKey);
    } catch (_) {
      // Keep the single latest update for the next authenticated retry.
    }
  }

  Future<void> _savePendingLocation(Position position) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingLocationKey,
      jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'captured_at': position.timestamp.toIso8601String(),
      }),
    );
  }

  Future<void> _clearPendingLocation() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingLocationKey);
  }
}
