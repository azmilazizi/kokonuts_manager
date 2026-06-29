import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

// TODO: Replace all placeholder values below with your actual Firebase project config.
//
// How to get these values:
//   1. Go to Firebase Console → your project → Project Settings → General
//   2. Under "Your apps", click the web app (or add one)
//   3. Copy the firebaseConfig object values
//
// VAPID key:
//   Firebase Console → Project Settings → Cloud Messaging → Web configuration
//   → Web Push certificates → Key pair (generate one if none exists)
//
// Fastest way: run `dart pub global activate flutterfire_cli` then
//   `flutterfire configure` in this directory — it fills everything in automatically.

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'This platform is not supported.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBDEXz3a5lwzAKjUTSQHMKDJnLtaPF6NGQ',
    appId: '1:83700561890:web:e9115663167a0c3240abbb',
    messagingSenderId: '83700561890',
    projectId: 'kokonuts-manager',
    authDomain: 'kokonuts-manager.firebaseapp.com',
    storageBucket: 'kokonuts-manager.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3olLvdoE54Xn9zUGEgV_p9k9FDDjaDd8',
    appId: '1:83700561890:android:209e011dec0d178e40abbb',
    messagingSenderId: '83700561890',
    projectId: 'kokonuts-manager',
    storageBucket: 'kokonuts-manager.firebasestorage.app',
  );

  // VAPID (Web Push) key pair — "Key pair" string from Firebase Console.
  static const String vapidKey =
      'BILzrXU0l0iivdspiYTIumWuV76J5nUvWswmJt10iwq3TB9ryG2pwy_itEsZZk13i1-9WoxZbbayhczTFUq1wGs';
}
