class AppRoutePaths {
  const AppRoutePaths._();

  static const String home = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String eventDetailsPattern = '/events/:id';

  static String eventDetails(int eventId) => '/events/$eventId';

  static bool isPublicLocation(Uri location) {
    return location.path == signIn ||
        location.path == signUp ||
        location.path == forgotPassword ||
        _resetPasswordSegments(location.pathSegments) != null;
  }

  static String? protectedLocation(Uri location) {
    final eventId = _eventId(location.pathSegments);
    return eventId == null ? null : eventDetails(eventId);
  }

  static String? locationFromIncomingUri(Uri uri) {
    final eventId = uri.host == 'events'
        ? _eventId(uri.pathSegments, requireEventPrefix: false)
        : _eventId(uri.pathSegments);
    if (eventId != null) return eventDetails(eventId);

    final resetSegments = uri.host == 'reset-password'
        ? _resetPasswordSegments(uri.pathSegments, requirePrefix: false)
        : _resetPasswordSegments(uri.pathSegments);
    if (resetSegments != null) {
      return '$resetPassword/${resetSegments.$1}/${resetSegments.$2}';
    }

    return null;
  }

  static String signInFor(Uri location) {
    final destination = protectedLocation(location);
    if (destination == null) return signIn;
    return Uri(
      path: signIn,
      queryParameters: <String, String>{'next': destination},
    ).toString();
  }

  static String? postAuthenticationLocation(Uri location) {
    final next = location.queryParameters['next'];
    if (next == null) return null;
    return protectedLocation(Uri.tryParse(next) ?? Uri());
  }

  static int? _eventId(
    List<String> segments, {
    bool requireEventPrefix = true,
  }) {
    final idSegment = requireEventPrefix
        ? segments.length == 2 && segments.first == 'events'
            ? segments.last
            : null
        : segments.length == 1
            ? segments.single
            : null;
    return idSegment == null ? null : int.tryParse(idSegment);
  }

  static (String, String)? _resetPasswordSegments(
    List<String> segments, {
    bool requirePrefix = true,
  }) {
    final values = requirePrefix
        ? segments.length == 3 && segments.first == 'reset-password'
            ? segments.skip(1).toList(growable: false)
            : null
        : segments.length == 2
            ? segments
            : null;
    if (values == null || values.any((value) => value.isEmpty)) return null;
    return (values.first, values.last);
  }
}

class AppRouteRedirect {
  const AppRouteRedirect._();

  static String? forLocation({
    required bool isAuthenticated,
    required Uri location,
  }) {
    if (!isAuthenticated && !AppRoutePaths.isPublicLocation(location)) {
      return AppRoutePaths.signInFor(location);
    }

    if (isAuthenticated && location.path == AppRoutePaths.signIn) {
      return AppRoutePaths.postAuthenticationLocation(location) ??
          AppRoutePaths.home;
    }

    if (isAuthenticated &&
        (location.path == AppRoutePaths.signUp ||
            location.path == AppRoutePaths.forgotPassword)) {
      return AppRoutePaths.home;
    }

    return null;
  }
}
