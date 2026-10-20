import 'package:go_router/go_router.dart';
import 'package:rescue_app/domain/services/auth_service.dart';
import 'package:rescue_app/domain/routing/app_route_paths.dart';
import 'package:rescue_app/screens/home_screen.dart';
import 'package:rescue_app/screens/forgot_password_screen.dart';
import 'package:rescue_app/screens/reset_password_screen.dart';
import 'package:rescue_app/screens/sign_in_screen.dart';
import 'package:rescue_app/screens/sign_up_screen.dart';
import 'package:rescue_app/screens/event_detail_screen.dart';

export 'package:rescue_app/domain/routing/app_route_paths.dart';

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
      path: AppRoutePaths.eventDetailsPattern,
      builder: (context, state) => EventDetailLoaderScreen(
        eventId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
  redirect: (context, state) {
    return AppRouteRedirect.forLocation(
      isAuthenticated: _authService.isAuthenticated,
      location: state.uri,
    );
  },
  refreshListenable: _authService.session,
);
