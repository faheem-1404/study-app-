import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/firestore_wallet_repository.dart';
import '../../data/services/simulated_ml_service.dart';
import '../../data/services/tflite_ml_service.dart';
import '../../core/services/app_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/services/ml_service_interfaces.dart';
import '../../domain/services/focus_analyzer.dart';

/// App storage provider
final appStorageServiceProvider = Provider<AppStorageService>((ref) {
  // Return instance that was initialized in main.dart
  return AppStorageService();
});

/// Auth Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(appStorageServiceProvider);
  return FirebaseAuthRepository(storage);
});

/// Wallet Repository provider
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final storage = ref.watch(appStorageServiceProvider);
  return FirestoreWalletRepository(storage);
});

/// Face Landmarker ML Service
final faceLandmarkerServiceProvider = Provider<FaceLandmarkerService>((ref) {
  if (kIsWeb) {
    return SimulatedFaceLandmarker();
  }
  return TfliteFaceLandmarkerService();
});

/// Posture Tracker ML Service
final postureTrackerServiceProvider = Provider<PostureTrackerService>((ref) {
  if (kIsWeb) {
    return SimulatedPostureTracker();
  }
  return TflitePostureTrackerService();
});

/// Object Detector ML Service
final objectDetectorServiceProvider = Provider<ObjectDetectorService>((ref) {
  if (kIsWeb) {
    return SimulatedObjectDetector();
  }
  return TfliteObjectDetectorService();
});

/// Focus Analyzer provider
final focusAnalyzerProvider = Provider<FocusAnalyzer>((ref) {
  return FocusAnalyzer();
});
