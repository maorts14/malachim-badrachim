import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rescue_app/screens/rescue_alert_app.dart';
import 'firebase_options.dart';
import 'firebase_options_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const env = String.fromEnvironment('ENV', defaultValue: 'staging');
  await dotenv.load(fileName: '.env.$env');
  // Android may initialize the default Firebase app from google-services
  // before Dart starts. Reusing it avoids a startup-only duplicate-app crash.
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: env == 'local'
            ? LocalFirebaseOptions.currentPlatform
            : DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      // Native Android initialization can win the race after the apps check.
      // In that one case the already registered default app is the correct one.
      if (error.code != 'duplicate-app') rethrow;
    }
  }
  runApp(const RescueAlertApp());
}
