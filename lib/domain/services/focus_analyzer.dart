import 'dart:collection';
import '../../core/models/focus_metrics.dart';
import 'ml_service_interfaces.dart';

class FocusAnalyzer {
  final Queue<int> _scoreHistory = Queue<int>();
  static const int _smoothingWindow = 10;

  DateTime? _eyesClosedStartTime;
  DateTime? _faceMissingStartTime;
  DateTime? _multipleFacesStartTime;
  DateTime? _phoneUsageStartTime;

  /// Aggregate ML pipeline results into a smoothed FocusMetrics object
  FocusMetrics analyzeFrame({
    required FaceMeshResult faceResult,
    required PostureResult postureResult,
    required List<DetectedObject> objects,
  }) {
    final now = DateTime.now();

    // ── 1. Track durations of conditions ──────────────────────────────────
    
    // Face presence / missing
    if (!faceResult.faceDetected) {
      _faceMissingStartTime ??= now;
    } else {
      _faceMissingStartTime = null;
    }
    final Duration faceMissingDuration =
        _faceMissingStartTime != null ? now.difference(_faceMissingStartTime!) : Duration.zero;

    // Eyes closed / sleeping
    if (faceResult.faceDetected && faceResult.eyesClosed) {
      _eyesClosedStartTime ??= now;
    } else {
      _eyesClosedStartTime = null;
    }
    final Duration eyesClosedDuration =
        _eyesClosedStartTime != null ? now.difference(_eyesClosedStartTime!) : Duration.zero;

    // Multiple faces
    if (faceResult.faceDetected && faceResult.multipleFacesDetected) {
      _multipleFacesStartTime ??= now;
    } else {
      _multipleFacesStartTime = null;
    }
    final Duration multipleFacesDuration =
        _multipleFacesStartTime != null ? now.difference(_multipleFacesStartTime!) : Duration.zero;

    // Phone presence
    final bool phonePresent = objects.any((o) => o.label == StudyObjectClass.phone);
    if (phonePresent) {
      _phoneUsageStartTime ??= now;
    } else {
      _phoneUsageStartTime = null;
    }
    final Duration phoneDuration =
        _phoneUsageStartTime != null ? now.difference(_phoneUsageStartTime!) : Duration.zero;

    final bool bookPresent = objects.any((o) => o.label == StudyObjectClass.book);
    final bool laptopPresent = objects.any((o) => o.label == StudyObjectClass.laptop);
    final bool chairPresent = objects.any((o) => o.label == StudyObjectClass.chair);
    final bool leavingChair = !faceResult.faceDetected && chairPresent;

    // ── 2. Calculate raw component scores with grace periods ──────────────

    double faceScore = 0.0;
    double eyeScore = 0.0;
    double headPoseScore = 0.0;
    double postureScore = 0.0;
    double objectScore = 0.0;

    // Apply 3-second grace period for face missing
    final bool faceConsideredPresent = faceResult.faceDetected || 
        (faceMissingDuration.inSeconds <= 3 && _faceMissingStartTime != null);

    // Face Presence = 35%
    if (faceConsideredPresent && !leavingChair) {
      faceScore = 35.0;
    }

    // Eye Attention = 20%
    if (faceConsideredPresent && !leavingChair) {
      // Apply 5-second grace period for eyes closed
      final bool eyesConsideredOpen = !faceResult.eyesClosed || 
          (eyesClosedDuration.inSeconds <= 5 && _eyesClosedStartTime != null);
      if (eyesConsideredOpen && !faceResult.isLookingAway) {
        eyeScore = 20.0;
      }
    }

    // Head Pose = 15%
    // Thresholds: Yaw within [-25, 25], Pitch within [-25, 25], Roll within [-20, 20]
    final bool headStable = faceResult.pitch.abs() <= 25.0 && 
                            faceResult.yaw.abs() <= 25.0 && 
                            faceResult.roll.abs() <= 20.0;
    if (faceConsideredPresent && !leavingChair && headStable) {
      headPoseScore = 15.0;
    }

    // Posture = 15%
    if (faceConsideredPresent && !leavingChair) {
      if (!postureResult.isSlouching) {
        postureScore = 15.0;
      } else {
        postureScore = 5.0; // Posture penalty
      }
    }

    // Study Object Presence = 15%
    if (bookPresent || laptopPresent) {
      objectScore = 15.0;
    }

    double rawTotalScore = faceScore + eyeScore + headPoseScore + postureScore + objectScore;

    // ── 3. Apply Distraction Penalties (Post-grace period) ────────────────
    
    // Phone Usage > 10 seconds: Subtract 25 points
    if (phoneDuration.inSeconds > 10) {
      rawTotalScore -= 25.0;
    }

    // Multiple Faces > 5 seconds: Subtract 15 points
    if (multipleFacesDuration.inSeconds > 5) {
      rawTotalScore -= 15.0;
    }

    final int finalRawScore = rawTotalScore.round().clamp(0, 100);

    // ── 4. Temporal Smoothing ──────────────────────────────────────────────
    _scoreHistory.addLast(finalRawScore);
    if (_scoreHistory.length > _smoothingWindow) {
      _scoreHistory.removeFirst();
    }
    final int smoothedScore = (_scoreHistory.fold(0, (sum, val) => sum + val) / _scoreHistory.length).round();

    return FocusMetrics(
      focusScore: smoothedScore,
      eyesOpen: !faceResult.eyesClosed,
      headStable: headStable,
      eyeMovement: 0.2,
      faceDetected: faceResult.faceDetected,
      headPitchAngle: faceResult.pitch,
      eyesClosedDuration: eyesClosedDuration,
      faceMissingDuration: faceMissingDuration,
      multipleFacesDuration: multipleFacesDuration,
      phoneDuration: phoneDuration,
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
    _faceMissingStartTime = null;
    _multipleFacesStartTime = null;
    _phoneUsageStartTime = null;
  }
}
