import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class LocalFirebaseOptions {
  const LocalFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }

    throw UnsupportedError(
      'Local Firebase is configured for Android only. Run FlutterFire configure '
      'for the local project before using another platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC4EOWHP-rNdgF8T9E4Ujk7S-y6h3t8BU8',
    appId: '1:841793218700:android:b8057d4b21835a7b1df3a9',
    messagingSenderId: '841793218700',
    projectId: 'rescue-alert-system-local',
    storageBucket: 'rescue-alert-system-local.firebasestorage.app',
  );
}
