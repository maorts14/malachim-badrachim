import 'package:go_router/go_router.dart';
import 'package:rescue_app/domain/services/auth_service.dart';
import 'package:rescue_app/screens/home_screen.dart';
import 'package:rescue_app/screens/forgot_password_screen.dart';
import 'package:rescue_app/screens/reset_password_screen.dart';
import 'package:rescue_app/screens/sign_in_screen.dart';
import 'package:rescue_app/screens/sign_up_screen.dart';
import 'package:rescue_app/screens/event_detail_screen.dart';

class AppRoutePaths {
  const AppRoutePaths._();

  static const String home = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String users = '/users';
  static const String events = '/events';
  static const String ptt = '/ptt';
  static const String groups = '/groups';
  static const String createEvent = '/events/create';
  static const String eventDetails = '/events/details';
  static const String eventChat = '/events/chat';
  static const String userManagement = '/users/manage';
}

class EventDeepLink {
  const EventDeepLink({required this.eventId});

  final String eventId;

  static EventDeepLink? tryParse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Supported format example: rescue://events/123
    if (uri.host == 'events' && uri.pathSegments.isNotEmpty) {
      return EventDeepLink(eventId: uri.pathSegments.first);
    }

    // Supported format example: https://app.rescue/events/123
    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'events') {
      return EventDeepLink(eventId: uri.pathSegments[1]);
    }

    return null;
  }
}

final AuthService _authService = AuthService();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutePaths.signIn,
  routes: <GoRoute>[
    GoRoute(
      path: AppRoutePaths.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutePaths.signIn,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutePaths.signUp,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: AppRoutePaths.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '${AppRoutePaths.resetPassword}/:uid/:token',
      builder: (context, state) => ResetPasswordScreen(
        uid: state.pathParameters['uid']!,
        token: state.pathParameters['token']!,
      ),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) => EventDetailLoaderScreen(
        eventId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
  redirect: (context, state) {
    final bool isLoggedIn = _authService.isAuthenticated;
    final bool isAuthRoute = state.matchedLocation == AppRoutePaths.signIn ||
        state.matchedLocation == AppRoutePaths.signUp ||
        state.matchedLocation == AppRoutePaths.forgotPassword ||
        state.matchedLocation.startsWith(AppRoutePaths.resetPassword);

    if (!isLoggedIn && !isAuthRoute) {
      return AppRoutePaths.signIn;
    }

    if (isLoggedIn && isAuthRoute) {
      return AppRoutePaths.home;
    }

    return null;
  },
  refreshListenable: _authService.session,
);
