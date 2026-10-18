import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:rescue_app/constants/app_env.dart';
import 'package:rescue_app/constants/asset_paths.dart';
import 'package:rescue_app/domain/services/api/rest_api_models.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapTabScreen extends StatefulWidget {
  const MapTabScreen({super.key});

  @override
  State<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends State<MapTabScreen> {
  static const String _cameraLatKey = 'map_camera_lat';
  static const String _cameraLonKey = 'map_camera_lon';
  static const String _cameraZoomKey = 'map_camera_zoom';

  static const double _defaultLat = 32.0853;
  static const double _defaultLon = 34.7818;
  static const double _defaultZoom = 10.5;

  final String _mapboxToken = AppEnv.mapboxAccessToken;

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  List<UserCoordinate> _userCoordinates = const [];
  StreamSubscription<geo.Position>? _positionSubscription;
  bool _isRequestingPermission = false;
  bool _hasLocationPermission = false;
  bool _isTrackingLocation = false;
  String? _permissionMessage;
  String _currentStyleUri = MapboxStyles.STANDARD;
  double _lastLatitude = _defaultLat;
  double _lastLongitude = _defaultLon;
  double _lastZoom = _defaultZoom;

  static const Map<String, String> _mapStyles = {
    'Standard': MapboxStyles.STANDARD,
    'Streets': MapboxStyles.MAPBOX_STREETS,
    'Satellite': MapboxStyles.SATELLITE,
    'Satellite Streets': MapboxStyles.SATELLITE_STREETS,
    'Outdoors': MapboxStyles.OUTDOORS,
    'Dark': MapboxStyles.DARK,
    'Light': MapboxStyles.LIGHT,
  };

  bool get _hasToken => _mapboxToken.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasToken) {
      MapboxOptions.setAccessToken(_mapboxToken);
    }
    _restoreLastCamera();
    _initializeLocationFlow();
    _loadUserMarkers();
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }

  Future<void> _initializeLocationFlow() async {
    final bool granted = await _requestLocationPermission();
    if (!granted) {
      return;
    }
    await _startLocationTracking();
  }

  Future<bool> _requestLocationPermission() async {
    if (_isRequestingPermission) {
      return _hasLocationPermission;
    }

    _isRequestingPermission = true;
    setState(() {
      _permissionMessage = null;
    });

    final bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _hasLocationPermission = false;
        _permissionMessage =
            'שירותי המיקום כבויים. יש להפעיל אותם כדי להשתמש במפה.';
      });
      _isRequestingPermission = false;
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    final bool granted = permission == geo.LocationPermission.always ||
        permission == geo.LocationPermission.whileInUse;

    setState(() {
      _hasLocationPermission = granted;
      if (!granted) {
        _permissionMessage = permission == geo.LocationPermission.deniedForever
            ? 'הגישה למיקום נחסמה. אפשרו אותה בהגדרות המכשיר.'
            : 'לא אושרה גישה למיקום.';
      }
    });

    _isRequestingPermission = false;
    return granted;
  }

  Future<void> _startLocationTracking() async {
    if (_isTrackingLocation) {
      return;
    }

    final geo.LocationSettings settings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.best,
      distanceFilter: 10,
    );

    _positionSubscription = geo.Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((geo.Position position) {
      _onLocationChanged(position);
    });

    setState(() {
      _isTrackingLocation = true;
    });

    final geo.Position current = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );
    _onLocationChanged(current);
  }

  Future<void> _stopLocationTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (mounted) {
      setState(() {
        _isTrackingLocation = false;
      });
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _applySavedCamera();
    _applyHebrewLabels();
    _initUserMarkers();
  }

  Future<void> _applyHebrewLabels() async {
    final MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }

    // Standard style supports import config language override.
    // try {
    //   await map.style.setStyleImportConfigProperty('basemap', 'language', 'he');
    // } catch (_) {
    //   // Ignore for styles that do not expose the basemap language config.
    // }
  }

  Future<void> _restoreLastCamera() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double lat = prefs.getDouble(_cameraLatKey) ?? _defaultLat;
    final double lon = prefs.getDouble(_cameraLonKey) ?? _defaultLon;
    final double zoom = prefs.getDouble(_cameraZoomKey) ?? _defaultZoom;

    if (!mounted) {
      return;
    }

    setState(() {
      _lastLatitude = lat;
      _lastLongitude = lon;
      _lastZoom = zoom;
    });

    await _applySavedCamera();
  }

  Future<void> _applySavedCamera() async {
    await _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(_lastLongitude, _lastLatitude),
        ),
        zoom: _lastZoom,
      ),
    );
  }

  Future<void> _persistCameraState({
    required double latitude,
    required double longitude,
    required double zoom,
  }) async {
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    _lastZoom = zoom;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cameraLatKey, latitude);
    await prefs.setDouble(_cameraLonKey, longitude);
    await prefs.setDouble(_cameraZoomKey, zoom);
  }

  Future<void> _initUserMarkers() async {
    final MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }

    _annotationManager = await map.annotations.createPointAnnotationManager();
    await _renderUserMarkers(_userCoordinates);
  }

  Future<void> _loadUserMarkers() async {
    try {
      final users = await RestApiService().getAllUsers();
      final coordinates = users
          .where((user) => user.latitude != null && user.longitude != null)
          .map((user) => user.coordinates)
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _userCoordinates = coordinates);
      await _renderUserMarkers(coordinates);
    } catch (_) {
      // Current location and map controls stay usable when the responder
      // directory is temporarily unavailable.
    }
  }

  Future<void> _renderUserMarkers(List<UserCoordinate> users) async {
    final PointAnnotationManager? manager = _annotationManager;
    if (manager == null) {
      return;
    }

    await manager.deleteAll();

    final ByteData imageData = await rootBundle
        .load(AssetPaths.alertIcon)
        .catchError(
          (error) =>
              rootBundle.load('packages/mapbox_maps_flutter/assets/empty.png'),
        );
    final Uint8List markerBytes = imageData.buffer.asUint8List();

    final List<PointAnnotationOptions> options = users
        .map(
          (UserCoordinate u) => PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(u.longitude, u.latitude),
            ),
            image: markerBytes,
            iconSize: 2,
          ),
        )
        .toList();

    await manager.createMulti(options);
  }

  Future<void> _selectMapStyle(BuildContext context) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'סגנון מפה',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ..._mapStyles.entries.map(
                (MapEntry<String, String> entry) => ListTile(
                  leading: _currentStyleUri == entry.value
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : const Icon(Icons.radio_button_unchecked),
                  title: Text(entry.key),
                  onTap: () => Navigator.of(ctx).pop(entry.value),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == _currentStyleUri) {
      return;
    }

    setState(() {
      _currentStyleUri = selected;
    });
    await _mapboxMap?.style.setStyleURI(selected);
    await _applyHebrewLabels();
  }

  Future<void> _zoomIn() async {
    final MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }
    final CameraState camera = await map.getCameraState();
    final double zoom = (camera.zoom + 1).clamp(0.0, 22.0);
    await map.flyTo(
      CameraOptions(zoom: zoom),
      MapAnimationOptions(duration: 300),
    );
    await _persistCameraState(
      latitude: _lastLatitude,
      longitude: _lastLongitude,
      zoom: zoom,
    );
  }

  Future<void> _zoomOut() async {
    final MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }
    final CameraState camera = await map.getCameraState();
    final double zoom = (camera.zoom - 1).clamp(0.0, 22.0);
    await map.flyTo(
      CameraOptions(zoom: zoom),
      MapAnimationOptions(duration: 300),
    );
    await _persistCameraState(
      latitude: _lastLatitude,
      longitude: _lastLongitude,
      zoom: zoom,
    );
  }

  Future<void> _onLocationChanged(geo.Position position) async {
    const double zoom = 14;
    _mapboxMap?.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: zoom,
      ),
    );
    await _persistCameraState(
      latitude: position.latitude,
      longitude: position.longitude,
      zoom: zoom,
    );
  }

  Future<void> _retryPermissionsAndTracking() async {
    final bool granted = await _requestLocationPermission();
    if (!granted) {
      return;
    }
    await _startLocationTracking();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasToken) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Mapbox token missing. Run with --dart-define=MAPBOX_ACCESS_TOKEN=your_token',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_hasLocationPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _permissionMessage ??
                    'נדרשת הרשאת מיקום כדי להציג את מיקומך במפה.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isRequestingPermission
                    ? null
                    : _retryPermissionsAndTracking,
                child: const Text('אישור גישה למיקום'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('mapWidget'),
          onMapCreated: _onMapCreated,
          viewport: CameraViewportState(
            center: Point(
              coordinates: Position(_lastLongitude, _lastLatitude),
            ),
            zoom: _lastZoom,
          ),
          styleUri: _currentStyleUri,
        ),
        Positioned(
          left: 12,
          bottom: 62,
          child: FloatingActionButton.small(
            heroTag: 'map_layers',
            onPressed: () => _selectMapStyle(context),
            child: const Icon(Icons.layers),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'zoom_in',
                onPressed: _zoomIn,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'zoom_out',
                onPressed: _zoomOut,
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'my_location',
                onPressed: _isTrackingLocation
                    ? () async {
                        final geo.Position current =
                            await geo.Geolocator.getCurrentPosition(
                          locationSettings: const geo.LocationSettings(
                            accuracy: geo.LocationAccuracy.high,
                          ),
                        );
                        _onLocationChanged(current);
                      }
                    : null,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
