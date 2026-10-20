import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/domain/routing/app_route_paths.dart';

void main() {
  group('AppRoutePaths.locationFromIncomingUri', () {
    test('accepts a custom-scheme event link with a numeric id', () {
      expect(
        AppRoutePaths.locationFromIncomingUri(Uri.parse('rescue://events/42')),
        '/events/42',
      );
    });

    test('accepts a web event link with a numeric id', () {
      expect(
        AppRoutePaths.locationFromIncomingUri(
          Uri.parse('https://app.rescue/events/42'),
        ),
        '/events/42',
      );
    });

    test('accepts an in-app event path', () {
      expect(
        AppRoutePaths.locationFromIncomingUri(Uri.parse('/events/42')),
        '/events/42',
      );
    });

    test('accepts a password reset link', () {
      expect(
        AppRoutePaths.locationFromIncomingUri(
          Uri.parse('rescue://reset-password/user-id/reset-token'),
        ),
        '/reset-password/user-id/reset-token',
      );
    });

    test('rejects unsupported and malformed links', () {
      expect(
        AppRoutePaths.locationFromIncomingUri(
            Uri.parse('rescue://events/nope')),
        isNull,
      );
      expect(
        AppRoutePaths.locationFromIncomingUri(Uri.parse('rescue://messages/9')),
        isNull,
      );
    });
  });

  group('AppRouteRedirect', () {
    test('sends unauthenticated event links to sign in with a safe return path',
        () {
      expect(
        AppRouteRedirect.forLocation(
          isAuthenticated: false,
          location: Uri.parse('/events/42'),
        ),
        '/sign-in?next=%2Fevents%2F42',
      );
    });

    test('restores an authenticated event link after sign in', () {
      expect(
        AppRouteRedirect.forLocation(
          isAuthenticated: true,
          location: Uri.parse('/sign-in?next=%2Fevents%2F42'),
        ),
        '/events/42',
      );
    });

    test('does not redirect to an unsupported post-login path', () {
      expect(
        AppRouteRedirect.forLocation(
          isAuthenticated: true,
          location: Uri.parse('/sign-in?next=%2Fmessages%2F42'),
        ),
        AppRoutePaths.home,
      );
    });
  });
}
