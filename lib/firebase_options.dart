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
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPIlQ3SNRTcaRgBtw-EI21muLGvo71q3g',
    appId: '1:116199012830:android:08959abee5a30a1131454f',
    messagingSenderId: '116199012830',
    projectId: 'geotag-cd89e',
    databaseURL: 'https://geotag-cd89e-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'geotag-cd89e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'not-needed',
    appId: 'not-needed',
    messagingSenderId: 'not-needed',
    projectId: 'geotag-attendance',
    storageBucket: 'geotag-attendance.appspot.com',
    iosBundleId: 'com.example.geotag',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBtYLGPOieaHpPFmX3RgzSaglzNeXbQEpo',
    appId: '1:116199012830:web:ed9e6196a1d5ad2b31454f',
    messagingSenderId: '116199012830',
    projectId: 'geotag-cd89e',
    authDomain: 'geotag-cd89e.firebaseapp.com',
    databaseURL: 'https://geotag-cd89e-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'geotag-cd89e.firebasestorage.app',
    measurementId: 'G-7FY8J0T0PP',
  );

}