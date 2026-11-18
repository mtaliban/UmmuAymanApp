import '../config.dart';

// Firebase Cloud Messaging - imezimwa kwa sababu kUseFirebase = false.
// Ili kuiwasha:
//  1. Ondoa comments za firebase_core na firebase_messaging kwenye pubspec.yaml
//  2. Ongeza google-services.json kwenye android/app/
//  3. Badilisha kUseFirebase = true kwenye lib/config.dart
class Notifications {
  static Future<void> init() async {
    if (!kUseFirebase) return;
    // Firebase.initializeApp() itaitwa hapa ukiwasha Firebase
  }

  static Future<void> registerAfterLogin() async {
    if (!kUseFirebase) return;
  }
}
