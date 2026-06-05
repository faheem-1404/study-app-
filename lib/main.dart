import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_storage_service.dart';
import 'data/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  final AppStorageService storage = AppStorageService();
  await storage.initialize();

  // Safely initialize Firebase with fallback
  await FirebaseService.initialize();

  runApp(
    const ProviderScope(
      child: StudyEarnApp(),
    ),
  );
}