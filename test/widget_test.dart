import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_earn/core/models/study_session_summary.dart';
import 'package:study_earn/core/models/payout_method.dart';
import 'package:study_earn/core/models/wallet_transaction.dart';
import 'package:study_earn/core/models/redemption_request.dart';
import 'package:study_earn/domain/services/focus_analyzer.dart';
import 'package:study_earn/domain/services/ml_service_interfaces.dart';
import 'package:study_earn/features/wallet/screens/wallet_screen.dart';
import 'package:study_earn/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:study_earn/domain/repositories/wallet_repository.dart';
import 'package:study_earn/core/providers/providers.dart';

// Mock Wallet Repository for testing
class MockWalletRepository implements WalletRepository {
  double credits = 100.0;
  int seconds = 0;
  List<RedemptionRequest> redemptions = [];
  List<WalletTransaction> transactions = [];

  @override
  Future<double> getCredits() async => credits;

  @override
  Future<int> getTodayStudySeconds() async => seconds;

  @override
  Future<List<RedemptionRequest>> getRedemptions() async => redemptions;

  @override
  Future<List<WalletTransaction>> getTransactions() async => transactions;

  @override
  Future<void> commitStudySummary(StudySessionSummary summary) async {
    credits += summary.earnedCredits;
    seconds += summary.focusedSeconds;
  }

  @override
  Future<void> deductCredits(double value) async {
    credits -= value;
  }

  @override
  Future<void> saveRedemption(RedemptionRequest request) async {
    redemptions.add(request);
  }

  @override
  Future<void> updateRedemptionStatus(String id, RedemptionStatus status) async {}

  @override
  Future<void> resetWallet() async {
    credits = 0.0;
    seconds = 0;
  }
}

void main() {
  group('Focus Score Engine Tests', () {
    late FocusAnalyzer analyzer;

    setUp(() {
      analyzer = FocusAnalyzer();
    });

    test('TC01: Face Visible - Focus Score is calculated correctly', () {
      final metrics = analyzer.analyzeFrame(
        faceResult: const FaceMeshResult(
          faceDetected: true,
          multipleFacesDetected: false,
          landmarks: [],
          leftEyeEar: 0.3,
          rightEyeEar: 0.3,
          isLookingAway: false,
          yaw: 0.0,
          pitch: 0.0,
          roll: 0.0,
        ),
        postureResult: const PostureResult(
          isSlouching: false,
          postureScore: 90.0,
          headRollAngle: 0.0,
          shoulderRollAngle: 0.0,
          keypoints: {},
        ),
        objects: [],
      );

      expect(metrics.faceDetected, isTrue);
      // Expected raw components: Face (35) + Eye (20) + Head (15) + Posture (15) = 85
      expect(metrics.focusScore, equals(85));
    });

    test('TC10: Focus Score Calculation - Weighted values are correct', () {
      final metrics = analyzer.analyzeFrame(
        faceResult: const FaceMeshResult(
          faceDetected: true,
          multipleFacesDetected: false,
          landmarks: [],
          leftEyeEar: 0.3,
          rightEyeEar: 0.3,
          isLookingAway: false,
          yaw: 0.0,
          pitch: 0.0,
          roll: 0.0,
        ),
        postureResult: const PostureResult(
          isSlouching: false,
          postureScore: 90.0,
          headRollAngle: 0.0,
          shoulderRollAngle: 0.0,
          keypoints: {},
        ),
        objects: [
          const DetectedObject(
            label: StudyObjectClass.book,
            confidence: 0.9,
            boundingBox: BoundingBox(left: 0, top: 0, width: 0, height: 0),
          ),
        ],
      );

      // Expected raw: Face (35) + Eye (20) + Head (15) + Posture (15) + Book (15) = 100
      expect(metrics.focusScore, equals(100));
    });

    test('TC02: Face Missing > 3s tracking initialization', () {
      final metrics = analyzer.analyzeFrame(
        faceResult: const FaceMeshResult(
          faceDetected: false,
          multipleFacesDetected: false,
          landmarks: [],
          leftEyeEar: 0.0,
          rightEyeEar: 0.0,
          isLookingAway: false,
          yaw: 0.0,
          pitch: 0.0,
          roll: 0.0,
        ),
        postureResult: const PostureResult(
          isSlouching: false,
          postureScore: 0.0,
          headRollAngle: 0.0,
          shoulderRollAngle: 0.0,
          keypoints: {},
        ),
        objects: [],
      );

      expect(metrics.faceDetected, isFalse);
      expect(metrics.faceMissingDuration, equals(Duration.zero)); // Starts tracking
    });

    test('TC03: Multiple Faces detection check', () {
      final metrics = analyzer.analyzeFrame(
        faceResult: const FaceMeshResult(
          faceDetected: true,
          multipleFacesDetected: true,
          landmarks: [],
          leftEyeEar: 0.3,
          rightEyeEar: 0.3,
          isLookingAway: false,
          yaw: 0.0,
          pitch: 0.0,
          roll: 0.0,
        ),
        postureResult: const PostureResult(
          isSlouching: false,
          postureScore: 90.0,
          headRollAngle: 0.0,
          shoulderRollAngle: 0.0,
          keypoints: {},
        ),
        objects: [],
      );

      expect(metrics.multipleFaces, isTrue);
    });

    test('TC04: Eyes Closed tracking check', () {
      final metrics = analyzer.analyzeFrame(
        faceResult: const FaceMeshResult(
          faceDetected: true,
          multipleFacesDetected: false,
          landmarks: [],
          leftEyeEar: 0.05,
          rightEyeEar: 0.05,
          isLookingAway: false,
          yaw: 0.0,
          pitch: 0.0,
          roll: 0.0,
        ),
        postureResult: const PostureResult(
          isSlouching: false,
          postureScore: 90.0,
          headRollAngle: 0.0,
          shoulderRollAngle: 0.0,
          keypoints: {},
        ),
        objects: [],
      );

      expect(metrics.eyesOpen, isFalse);
    });

    test('TC05: Phone Present distraction check', () {
      final metrics = analyzer.analyzeFrame(
        faceResult: const FaceMeshResult(
          faceDetected: true,
          multipleFacesDetected: false,
          landmarks: [],
          leftEyeEar: 0.3,
          rightEyeEar: 0.3,
          isLookingAway: false,
          yaw: 0.0,
          pitch: 0.0,
          roll: 0.0,
        ),
        postureResult: const PostureResult(
          isSlouching: false,
          postureScore: 90.0,
          headRollAngle: 0.0,
          shoulderRollAngle: 0.0,
          keypoints: {},
        ),
        objects: [
          const DetectedObject(
            label: StudyObjectClass.phone,
            confidence: 0.9,
            boundingBox: BoundingBox(left: 0, top: 0, width: 0, height: 0),
          ),
        ],
      );

      expect(metrics.phoneDetected, isTrue);
    });

    test('TC09: Session Timer tracking baseline', () {
      final summary = StudySessionSummary(
        plannedSeconds: 1800,
        focusedSeconds: 1500,
        pausedSeconds: 200,
        absentSeconds: 100,
        earnedCredits: 15.0,
        invalidated: false,
        message: 'Completed focus session',
      );

      expect(summary.focusedSeconds, equals(1500));
      expect(summary.earnedCredits, equals(15.0));
      expect(summary.invalidated, isFalse);
    });
  });

  group('Withdrawal & Wallet System Tests', () {
    late MockWalletRepository repo;
    late WalletController controller;

    setUp(() {
      repo = MockWalletRepository();
      controller = WalletController(repo);
    });

    test('TC06: Valid Withdrawal succeeds and deducts balance', () async {
      repo.credits = 500.0; // ₹50.00
      await controller.loadWallet();

      await controller.createRedemption(
        credits: 200.0,
        method: PayoutMethod.upi,
        destination: 'test@upi',
      );

      expect(controller.state.credits, equals(300.0));
      expect(repo.redemptions.length, equals(1));
    });

    test('TC07: Withdrawal > Balance throws error', () async {
      repo.credits = 50.0; // ₹5.00
      await controller.loadWallet();

      expect(
        () => controller.createRedemption(
          credits: 100.0,
          method: PayoutMethod.upi,
          destination: 'test@upi',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Widget Tests', () {
    testWidgets('TC08: Wallet Screen Opens without Ticker Crash', (WidgetTester tester) async {
      final mockRepo = MockWalletRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: WalletScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('My Wallet'), findsOneWidget);
    });
  });
}
