import 'package:flutter/widgets.dart';

class AuthSessionGate extends StatelessWidget {
  const AuthSessionGate({
    required this.sessionRestoration,
    required this.isAuthenticated,
    required this.authenticatedChild,
    required this.unauthenticatedChild,
    required this.loadingChild,
    super.key,
  });

  final Future<void> sessionRestoration;
  final bool Function() isAuthenticated;
  final Widget authenticatedChild;
  final Widget unauthenticatedChild;
  final Widget loadingChild;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: sessionRestoration,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return loadingChild;
        }
        return isAuthenticated() ? authenticatedChild : unauthenticatedChild;
      },
    );
  }
}
