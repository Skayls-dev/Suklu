// ⚠️  This file is a placeholder.
// Run the following from apps/mobile/ to generate the real version:
//
//   flutterfire configure \
//     --project=suklu-prod \
//     --platforms=android,ios,web
//
// Then commit the generated file (it contains no secrets — only public config).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA3PWu3omWkAliC4AlQXBSHo2LBsNDpOwM',
    appId: '1:765014148505:web:b8e8453355c7b4297b3f08',
    messagingSenderId: '765014148505',
    projectId: 'suklu-prod',
    authDomain: 'suklu-prod.firebaseapp.com',
    storageBucket: 'suklu-prod.firebasestorage.app',
    measurementId: 'G-RCX1P41D2R',
  );

  // TODO: replace with real values from flutterfire configure

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6Bk8K5mfHVawSm2MNvmnx1Dx0tDOGwx0',
    appId: '1:765014148505:android:38b06021449b1b307b3f08',
    messagingSenderId: '765014148505',
    projectId: 'suklu-prod',
    storageBucket: 'suklu-prod.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDICo7hTCwMzaaUWSEyi78KOxDkmh1pTRo',
    appId: '1:765014148505:ios:fdcf2e97fc65a4b57b3f08',
    messagingSenderId: '765014148505',
    projectId: 'suklu-prod',
    storageBucket: 'suklu-prod.firebasestorage.app',
    iosBundleId: 'com.skayls.suklu',
  );

}