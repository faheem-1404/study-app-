import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/focus_metrics.dart';
import 'web_face_detection_service.dart';

/// Advanced focus score service using ML Kit Face Detection.
///
/// Detection pipeline:
///   1. ML Kit detects face + returns euler angles (yaw/pitch/roll) and
///      eye-open probabilities via classification.
///   2. Individual sub-scores are computed for: eye state, head orientation,
///      and gaze stability.
///   3. Scores are smoothed over a 5-frame sliding window to eliminate jitter.
///   4. On web (no image stream), falls back to [WebFaceDetectionService].
class FocusScoreService {
  FocusScoreService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            // ACCURATE mode for better euler angle + classification quality
            performanceMode: FaceDetectorMode.accurate,
            enableLandmarks: true,
            enableContours: false,
            // Classification gives leftEyeOpenProbability / rightEyeOpenProbability
            enableClassification: true,
            enableTracking: true,   // Track the same face across frames
            minFaceSize: 0.15,      // Detect faces that are at least 15% of frame
          ),
        );

  final FaceDetector _faceDetector;
  final WebFaceDetectionService _webDetector = WebFaceDetectionService();

  // ── Temporal smoothing: last N focus scores ─────────────────────────────
  static const int _smoothingWindow = 5;
  final Queue<int> _scoreHistory = Queue<int>();

  // ── Thresholds (tuned for studying at a desk ~50–80 cm from screen) ─────
  /// Eye is considered open if probability >= this value
  static const double _eyeOpenThreshold = 0.5;
  /// Max |yaw| (left-right head rotation) to be considered "looking at screen"
  static const double _maxYawDeg = 25.0;
  /// Max |pitch| (up-down head tilt) to be considered "looking at screen"
  static const double _maxPitchDeg = 20.0;
  /// Max |roll| (head tilt side-to-side) before penalising
  static const double _maxRollDeg = 30.0;

  // ── Eye-closed duration tracking ────────────────────────────────────────
  DateTime? _lastFaceDetectedTime;
  DateTime? _eyesClosedStartTime;

  // ── Public API ───────────────────────────────────────────────────────────

  Future<FocusMetrics> calculateFocusMetrics(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (kIsWeb) {
      // ML Kit image streaming unsupported on web — use brightness heuristic
      return _webDetector.processFrame(image);
    }

    try {
      final InputImage? inputImage = _buildInputImage(image, camera);
      if (inputImage == null) return _defaultMetrics();

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return _noFaceMetrics();

      _lastFaceDetectedTime = DateTime.now();
      final Face face = faces.first;

      // ── 1. Eye state ──────────────────────────────────────────────────
      final _EyeState eyeState = _analyseEyes(face);

      // Update eyes-closed timer
      if (!eyeState.bothOpen) {
        _eyesClosedStartTime ??= DateTime.now();
      } else {
        _eyesClosedStartTime = null;
      }
      final Duration eyesClosedDuration =
          eyeState.bothOpen ? Duration.zero : _eyesClosedDuration();

      // ── 2. Head orientation ──────────────────────────────────────────
      final _HeadOrientation head = _analyseHeadOrientation(face);

      // ── 3. Sub-scores → composite score ─────────────────────────────
      //
      //   Eye score  (0–40): based on how open both eyes are
      //   Gaze score (0–35): penalised by yaw/pitch deviations
      //   Roll score (0–15): penalised by excessive head tilt
      //   Face bonus (0–10): constant for having a face in frame
      //
      final int eyeScore = _eyeSubScore(eyeState);
      final int gazeScore = _gazeSubScore(head);
      final int rollScore = _rollSubScore(head.rollDeg);
      const int faceBonus = 10;

      final int rawScore =
          (eyeScore + gazeScore + rollScore + faceBonus).clamp(0, 100);

      // Smooth score to prevent flickering UI
      final int smoothedScore = _smooth(rawScore);

      return FocusMetrics(
        focusScore: smoothedScore,
        eyesOpen: eyeState.bothOpen,
        headStable: head.isStable,
        eyeMovement: eyeState.movementLevel,
        faceDetected: true,
        headPitchAngle: head.pitchDeg,
        eyesClosedDuration: eyesClosedDuration,
        faceMissingDuration: Duration.zero,
      );
    } catch (_) {
      return _defaultMetrics();
    }
  }

  // ── Eye Analysis ─────────────────────────────────────────────────────────

  _EyeState _analyseEyes(Face face) {
    final double? left = face.leftEyeOpenProbability;
    final double? right = face.rightEyeOpenProbability;

    // If classification unavailable fall back to landmark presence
    if (left == null || right == null) {
      final bool landmarksPresent =
          face.landmarks[FaceLandmarkType.leftEye] != null &&
          face.landmarks[FaceLandmarkType.rightEye] != null;
      return _EyeState(
        leftProb: landmarksPresent ? 0.8 : 0.5,
        rightProb: landmarksPresent ? 0.8 : 0.5,
      );
    }

    return _EyeState(leftProb: left, rightProb: right);
  }

  /// Eye sub-score: 0–40
  /// - Both open at ≥ threshold → 40
  /// - One eye partially open → proportional
  /// - Both closed → 0
  int _eyeSubScore(_EyeState eye) {
    if (eye.leftProb == null || eye.rightProb == null) return 20;
    final double avgProb = (eye.leftProb! + eye.rightProb!) / 2.0;
    // Remap: 0.0–1.0 → 0–40 pts, but treat < threshold as closed
    if (avgProb < _eyeOpenThreshold) return 0;
    return ((avgProb - _eyeOpenThreshold) / (1.0 - _eyeOpenThreshold) * 40)
        .round()
        .clamp(0, 40);
  }

  // ── Head Orientation Analysis ────────────────────────────────────────────

  _HeadOrientation _analyseHeadOrientation(Face face) {
    // ML Kit provides Euler angles:
    //   headEulerAngleY = yaw  (positive = head turned right)
    //   headEulerAngleX = pitch (positive = head tilted up)
    //   headEulerAngleZ = roll  (positive = head tilted left)
    final double yaw = face.headEulerAngleY ?? 0.0;
    final double pitch = face.headEulerAngleX ?? 0.0;
    final double roll = face.headEulerAngleZ ?? 0.0;

    final bool isStable =
        yaw.abs() < _maxYawDeg &&
        pitch.abs() < _maxPitchDeg &&
        roll.abs() < _maxRollDeg;

    return _HeadOrientation(
      yawDeg: yaw,
      pitchDeg: pitch,
      rollDeg: roll,
      isStable: isStable,
    );
  }

  /// Gaze sub-score: 0–35 — penalises yaw and pitch deviation
  int _gazeSubScore(_HeadOrientation h) {
    // Yaw contribution (0–20 pts)
    final double yawNorm = (h.yawDeg.abs() / _maxYawDeg).clamp(0.0, 1.0);
    final int yawPts = ((1.0 - yawNorm) * 20).round();

    // Pitch contribution (0–15 pts)
    final double pitchNorm = (h.pitchDeg.abs() / _maxPitchDeg).clamp(0.0, 1.0);
    final int pitchPts = ((1.0 - pitchNorm) * 15).round();

    return (yawPts + pitchPts).clamp(0, 35);
  }

  /// Roll sub-score: 0–15
  int _rollSubScore(double roll) {
    final double rollNorm = (roll.abs() / _maxRollDeg).clamp(0.0, 1.0);
    return ((1.0 - rollNorm) * 15).round().clamp(0, 15);
  }

  // ── Temporal Smoothing ───────────────────────────────────────────────────

  int _smooth(int raw) {
    _scoreHistory.addLast(raw);
    if (_scoreHistory.length > _smoothingWindow) _scoreHistory.removeFirst();
    final int sum = _scoreHistory.fold(0, (a, b) => a + b);
    return (sum / _scoreHistory.length).round();
  }

  // ── Fallback Metrics ─────────────────────────────────────────────────────

  FocusMetrics _noFaceMetrics() {
    _eyesClosedStartTime = null;
    return FocusMetrics(
      focusScore: 0,
      eyesOpen: false,
      headStable: false,
      eyeMovement: 1.0,
      faceDetected: false,
      headPitchAngle: 0,
      eyesClosedDuration: Duration.zero,
      faceMissingDuration: _faceMissingDuration(),
    );
  }

  FocusMetrics _defaultMetrics() => const FocusMetrics(
        focusScore: 0,
        eyesOpen: false,
        headStable: false,
        eyeMovement: 1.0,
        faceDetected: false,
        headPitchAngle: 0,
      );

  Duration _eyesClosedDuration() {
    if (_eyesClosedStartTime == null) return Duration.zero;
    return DateTime.now().difference(_eyesClosedStartTime!);
  }

  Duration _faceMissingDuration() {
    if (_lastFaceDetectedTime == null) return Duration.zero;
    return DateTime.now().difference(_lastFaceDetectedTime!);
  }

  // ── Image Conversion ─────────────────────────────────────────────────────

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    // On Android, camera gives NV21 regardless of requested format
    final InputImageFormat format = defaultTargetPlatform == TargetPlatform.android
        ? InputImageFormat.nv21
        : (InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.bgra8888);

    final BytesBuilder builder = BytesBuilder();
    for (final Plane plane in image.planes) {
      builder.add(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: builder.takeBytes(),
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
}

// ── Value objects ─────────────────────────────────────────────────────────────

class _EyeState {
  _EyeState({required this.leftProb, required this.rightProb});

  final double? leftProb;
  final double? rightProb;

  bool get bothOpen =>
      (leftProb ?? 0.8) >= FocusScoreService._eyeOpenThreshold ||
      (rightProb ?? 0.8) >= FocusScoreService._eyeOpenThreshold;

  /// 0 = stable, 1 = high movement (based on asymmetry between eyes)
  double get movementLevel {
    if (leftProb == null || rightProb == null) return 0.3;
    return ((leftProb! - rightProb!).abs()).clamp(0.0, 1.0);
  }
}

class _HeadOrientation {
  const _HeadOrientation({
    required this.yawDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.isStable,
  });

  final double yawDeg;
  final double pitchDeg;
  final double rollDeg;
  final bool isStable;
}
