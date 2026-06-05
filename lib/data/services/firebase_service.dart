import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        // On web, initializing Firebase without options will fail unless config script is loaded.
        // We will catch the error and fall back gracefully.
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp();
      }
      _initialized = true;
      debugPrint('Firebase successfully initialized!');
    } catch (e) {
      _initialized = false;
      debugPrint('Firebase initialization failed: $e');
      debugPrint('StudyPay running in offline/local mock mode.');
    }
  }
}
