import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../core/models/focus_metrics.dart';
import 'ml_service_interfaces.dart';

class FocusAnalyzer {
  final Queue<int> _scoreHistory = Queue<int>();
  static const int _smoothingWindow = 10;

  DateTime? _eyesClosedStartTime;
  DateTime? _absenceStartTime;

  /// Aggregate ML pipeline results into a smoothed FocusMetrics object
  FocusMetrics analyzeFrame({
    required FaceMeshResult faceResult,
    required PostureResult postureResult,
    required List<DetectedObject> objects,
  }) {
    final now = DateTime.now();

    // Check if phone, book, laptop, or chair is present
    final bool phonePresent = objects.any((o) => o.label == StudyObjectClass.phone);
    final bool bookPresent = objects.any((o) => o.label == StudyObjectClass.book);
    final bool laptopPresent = objects.any((o) => o.label == StudyObjectClass.laptop);
    final bool chairPresent = objects.any((o) => o.label == StudyObjectClass.chair);

    // Leaving chair state
    final bool leavingChair = !faceResult.faceDetected && chairPresent;

    // ── 1. Calculate raw component scores ──────────────────────────────────
    double faceScore = 0.0;
    double eyeScore = 0.0;
    double objectScore = 0.0;
    double postureScore = 0.0;
    double distractionScore = 0.0;

    // Face Presence = 35%
    if (faceResult.faceDetected && !leavingChair) {
      if (faceResult.multipleFacesDetected) {
        faceScore = 15.0; // Multiple faces penalty
      } else {
        faceScore = 35.0;
      }
    }

    // Eye Attention = 20%
    if (faceResult.faceDetected && !leavingChair && !faceResult.eyesClosed && !faceResult.isLookingAway) {
      eyeScore = 20.0;
    }

    // Study Object Presence = 15%
    if (bookPresent || laptopPresent) {
      objectScore = 15.0;
    }

    // Posture = 15%
    if (faceResult.faceDetected && !leavingChair) {
      if (!postureResult.isSlouching) {
        postureScore = 15.0;
      } else {
        postureScore = 5.0;
      }
    }

    // Low Distraction = 15%
    if (!phonePresent) {
      distractionScore = 15.0;
    }

    final double rawTotalScore = faceScore + eyeScore + objectScore + postureScore + distractionScore;
    final int finalRawScore = rawTotalScore.round().clamp(0, 100);

    // ── 2. Temporal Smoothing ──────────────────────────────────────────────
    _scoreHistory.addLast(finalRawScore);
    if (_scoreHistory.length > _smoothingWindow) {
      _scoreHistory.removeFirst();
    }
    final int smoothedScore = (_scoreHistory.fold(0, (sum, val) => sum + val) / _scoreHistory.length).round();

    // ── 3. Duration Tracking ───────────────────────────────────────────────
    // Eyes closed / sleeping duration
    if (faceResult.faceDetected && faceResult.eyesClosed) {
      _eyesClosedStartTime ??= now;
    } else {
      _eyesClosedStartTime = null;
    }
    final Duration eyesClosedDuration =
        _eyesClosedStartTime != null ? now.difference(_eyesClosedStartTime!) : Duration.zero;

    // Absence / distraction duration (starts if face is missing, multiple faces detected, or phone present)
    final bool isAbsentOrDistracted = !faceResult.faceDetected || 
                                      faceResult.multipleFacesDetected || 
                                      phonePresent || 
                                      leavingChair;

    if (isAbsentOrDistracted) {
      _absenceStartTime ??= now;
    } else {
      _absenceStartTime = null;
    }
    final Duration faceMissingDuration =
        _absenceStartTime != null ? now.difference(_absenceStartTime!) : Duration.zero;

    return FocusMetrics(
      focusScore: smoothedScore,
      eyesOpen: !faceResult.eyesClosed,
      headStable: faceResult.pitch.abs() < 45.0,
      eyeMovement: 0.2, // Default
      faceDetected: faceResult.faceDetected,
      headPitchAngle: faceResult.pitch,
      eyesClosedDuration: eyesClosedDuration,
      faceMissingDuration: faceMissingDuration,
      multipleFaces: faceResult.multipleFacesDetected,
      phoneDetected: phonePresent,
      bookDetected: bookPresent,
      laptopDetected: laptopPresent,
      leavingChair: leavingChair,
      slouching: postureResult.isSlouching,
      headYaw: faceResult.yaw,
      headRoll: faceResult.roll,
    );
  }

  void reset() {
    _scoreHistory.clear();
    _eyesClosedStartTime = null;
    _absenceStartTime = null;
  }
}
