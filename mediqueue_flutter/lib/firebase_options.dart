// File generated manually using Firebase project config from new credentials
// Project: medique-b29ee

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android; // Fallback for any other platform
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmhvep0QM24Mf3SesIital2CCETmlsJ-4',
    authDomain: 'medique-b29ee.firebaseapp.com',
    projectId: 'medique-b29ee',
    storageBucket: 'medique-b29ee.firebasestorage.app',
    messagingSenderId: '16979338752',
    appId: '1:16979338752:web:1d4ca34fb54fdad6b55ae5',
    measurementId: 'G-PH4EKPV5NL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmhvep0QM24Mf3SesIital2CCETmlsJ-4',
    appId: '1:16979338752:android:1d4ca34fb54fdad6b55ae5',
    messagingSenderId: '16979338752',
    projectId: 'medique-b29ee',
    storageBucket: 'medique-b29ee.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBmhvep0QM24Mf3SesIital2CCETmlsJ-4',
    appId: '1:16979338752:ios:app',
    messagingSenderId: '16979338752',
    projectId: 'medique-b29ee',
    storageBucket: 'medique-b29ee.firebasestorage.app',
    iosBundleId: 'com.mediqueue.app.mediqueue_app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBmhvep0QM24Mf3SesIital2CCETmlsJ-4',
    appId: '1:16979338752:ios:app',
    messagingSenderId: '16979338752',
    projectId: 'medique-b29ee',
    storageBucket: 'medique-b29ee.firebasestorage.app',
    iosBundleId: 'com.mediqueue.app.mediqueue_app',
  );
}
