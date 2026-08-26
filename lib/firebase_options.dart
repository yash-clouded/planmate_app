import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBpuEXeCI6TUdF2EMN8EPw0rAyptHcRbo',
    appId: '1:468657114122:android:df99c29643dba30ee323f3',
    messagingSenderId: '468657114122',
    projectId: 'planmate-bbc4d',
    storageBucket: 'planmate-bbc4d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '468657114122',
    projectId: 'planmate-bbc4d',
    storageBucket: 'planmate-bbc4d.firebasestorage.app',
    iosBundleId: 'com.planmate.planmate',
  );
}
