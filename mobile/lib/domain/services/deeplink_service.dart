import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rescue_app/domain/routing/app_route_paths.dart';

class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks() {
    _init();
  }

  final AppLinks _appLinks;
  final BehaviorSubject<String?> _links = BehaviorSubject<String?>.seeded(null);
  StreamSubscription<Uri>? _sub;
  String? _pendingRoute;

  Stream<String?> get linkStream => _links.stream;

  Future<void> _init() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _pendingRoute = _routeFromUri(initialLink);
      _links.add(_pendingRoute);
    }

    _sub = _appLinks.uriLinkStream.listen((uri) {
      _pendingRoute = _routeFromUri(uri);
      _links.add(_pendingRoute);
    });
  }

  String? _routeFromUri(Uri uri) => AppRoutePaths.locationFromIncomingUri(uri);

  void setPendingRoute(String route) {
    final supportedRoute = AppRoutePaths.locationFromIncomingUri(
      Uri.tryParse(route) ?? Uri(),
    );
    if (supportedRoute == null) return;
    _pendingRoute = supportedRoute;
    _links.add(supportedRoute);
  }

  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _links.close();
  }
}
