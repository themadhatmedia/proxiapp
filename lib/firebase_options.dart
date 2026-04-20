// Sync with ios/Runner/GoogleService-Info.plist (GOOGLE_APP_ID, API_KEY).
// After adding an iOS app in Firebase Console (bundle id: com.app.proxiapp), download the
// plist and either paste values here or run: dart pub global activate flutterfire_cli && flutterfire configure
//
// For push delivery on iOS you must also upload your Apple APNs key (.p8) in Firebase:
// Project settings â†’ Cloud Messaging â†’ Apple app configuration.

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
      case TargetPlatform.iOS:
        return ios;
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

  /// Must match [GoogleService-Info.plist] GOOGLE_APP_ID until you replace both from Firebase.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACF4eF7J-snSMyNDcjmQv0aMKEX7Rnf34',
    appId: '1:387366676196:ios:3bbb4786fad3dcf13aeef1',
    messagingSenderId: '387366676196',
    projectId: 'myproxiapp-dev-2127e',
    storageBucket: 'myproxiapp-dev-2127e.firebasestorage.app',
    iosBundleId: 'com.app.proxiapp',
  );
}
