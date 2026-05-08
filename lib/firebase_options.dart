// File generated from the Firebase options supplied with the original app.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase options are not configured for Linux.',
        );
      default:
        throw UnsupportedError('Firebase options are not supported here.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    // Web도 Android/Windows와 같은 Firebase 프로젝트를 바라보도록 맞춘다.
    apiKey: 'AIzaSyCPgtWinuaT__Jf6_gDQVxhioqCAQ_wnc8',
    appId: '1:456373103467:web:59e706eb07dbfb7afefa2e',
    messagingSenderId: '456373103467',
    projectId: 'test1-8b353',
    authDomain: 'test1-8b353.firebaseapp.com',
    storageBucket: 'test1-8b353.firebasestorage.app',
    measurementId: 'G-FW9FE6VTHH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCo8u-0u86oXTpds_y_vRuU9Xq_Kfl2b3A',
    appId: '1:456373103467:android:59abb1c8783b1e7afefa2e',
    messagingSenderId: '456373103467',
    projectId: 'test1-8b353',
    storageBucket: 'test1-8b353.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAY_IR-1Qa5aK6-3AyYOcTdgqpbS3ee79U',
    appId: '1:456373103467:ios:fbc1690c2157c169fefa2e',
    messagingSenderId: '456373103467',
    projectId: 'test1-8b353',
    storageBucket: 'test1-8b353.firebasestorage.app',
    iosBundleId: 'com.centralfestival.centralFestivalApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD14YSw13pwDiDTWzxZkRnJJxOYTqPjoF8',
    appId: '1:214301372203:ios:25e583f964cdfb56411f6e',
    messagingSenderId: '214301372203',
    projectId: 'cetral',
    storageBucket: 'cetral.firebasestorage.app',
    iosBundleId: 'com.example.centralFestival',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCPgtWinuaT__Jf6_gDQVxhioqCAQ_wnc8',
    appId: '1:456373103467:web:59e706eb07dbfb7afefa2e',
    messagingSenderId: '456373103467',
    projectId: 'test1-8b353',
    authDomain: 'test1-8b353.firebaseapp.com',
    storageBucket: 'test1-8b353.firebasestorage.app',
    measurementId: 'G-FW9FE6VTHH',
  );
}
