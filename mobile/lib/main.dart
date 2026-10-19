import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rescue_app/screens/rescue_alert_app.dart';
import 'firebase_options.dart';
import 'firebase_options_local.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppStartup());
}

class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  late Future<void> _startup = _prepareApp();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: _StartupFailure(
                onRetry: () => setState(() => _startup = _prepareApp()),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: _StartupLoading(),
            );
          }
          return const RescueAlertApp();
        },
      );
}

Future<void> _prepareApp() async {
  const env = String.fromEnvironment('ENV', defaultValue: 'staging');
  await _loadEnvironment(env);
  // Android may initialize the default Firebase app from google-services
  // before Dart starts. Reusing it avoids a startup-only duplicate-app crash.
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: env == 'local'
            ? LocalFirebaseOptions.currentPlatform
            : DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
    } on FirebaseException catch (error) {
      // Native Android initialization can win the race after the apps check.
      // In that one case the already registered default app is the correct one.
      if (error.code != 'duplicate-app') rethrow;
    } on TimeoutException {
      // Do not leave Android's launch screen visible forever. On Android,
      // Firebase is normally initialized natively before Dart starts anyway.
    }
  }
}

Future<void> _loadEnvironment(String env) async {
  try {
    await dotenv
        .load(fileName: '.env.$env')
        .timeout(const Duration(seconds: 4));
  } on TimeoutException {
    // AppEnv has safe defaults, so the UI can still start if an asset read is
    // delayed on a device or emulator.
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF6F7F4),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  color: Color(0xFF128A5E),
                ),
              ),
              SizedBox(height: 18),
              Text(
                'מכינים את המערכת',
                style: TextStyle(
                  color: Color(0xFF16233A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF6F7F4),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: Color(0xFFD43A2F),
                  size: 48,
                ),
                const SizedBox(height: 14),
                const Text(
                  'לא הצלחנו להפעיל את המערכת',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF16233A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'בדקו את החיבור לאינטרנט ונסו שוב.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5A677D)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('נסה שוב'),
                ),
              ],
            ),
          ),
        ),
      );
}
