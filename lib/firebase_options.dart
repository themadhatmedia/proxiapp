// Generated from `android/app/google-services.json` (Android only).
// Run `flutterfire configure` when you add iOS/web and replace this file.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase has not been configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase has not been configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACF4eF7J-snSMyNDcjmQv0aMKEX7Rnf34',
    appId: '1:387366676196:android:1be137ba83d0a6dd3aeef1',
    messagingSenderId: '387366676196',
    projectId: 'myproxiapp-dev-2127e',
    storageBucket: 'myproxiapp-dev-2127e.firebasestorage.app',
  );
}
