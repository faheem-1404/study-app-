import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../domain/services/ml_service_interfaces.dart';

/// Global controller to simulate ML states in the Developer Panel using confidence sliders
class MlSimulatorConfig {
  // Confidence values (0.0 to 1.0)
  static double faceConfidence = 0.98;
  static double multipleFacesConfidence = 0.02;
  static double eyesOpenConfidence = 0.96;
  static double headForwardConfidence = 0.92;
  static double postureConfidence = 0.94;
  static double phoneConfidence = 0.05;
  static double bookConfidence = 0.85;
  static double laptopConfidence = 0.10;
  static double leavingChairConfidence = 0.01;

  // Derived binary states
  static bool get faceDetected => faceConfidence > 0.5;
  static bool get multipleFaces => multipleFacesConfidence > 0.5;
  static bool get eyesClosed => eyesOpenConfidence < 0.5;
  static bool get lookingAway => headForwardConfidence < 0.5;
  static bool get phonePresent => phoneConfidence > 0.5;
  static bool get bookPresent => bookConfidence > 0.5;
  static bool get laptopPresent => laptopConfidence > 0.5;
  static bool get leavingChair => leavingChairConfidence > 0.5;
  static bool get slouching => postureConfidence < 0.5;

  /// Helper to get a simulated focus score based on current toggles
  static double get calculatedScore {
    if (leavingChair) return 0.0;
    if (!faceDetected) return 0.0;

    double score = 0.0;

    // Face Presence: 35%
    if (multipleFaces) {
      score += 15.0; // penalty for multiple faces
    } else {
      score += 35.0;
    }

    // Eye Attention: 20%
    if (!eyesClosed && !lookingAway) {
      score += 20.0;
    }

    // Study Object Presence: 15%
    if (bookPresent || laptopPresent) {
      score += 15.0;
    }

    // Posture: 15%
    if (!slouching) {
      score += 15.0;
    } else {
      score += 5.0;
    }

    // Low Distraction: 15% (deducted if phone is present)
    if (!phonePresent) {
      score += 15.0;
    }

    return score;
  }
}

// ── Simulated Face Landmarker ───────────────────────────────────────────────

class SimulatedFaceLandmarker implements FaceLandmarkerService {
  @override
  Future<void> initialize() async {}

  @override
  Future<FaceMeshResult> processImage(CameraImage image, CameraDescription camera) async {
    // Artificial delay to simulate processing time
    await Future<void>.delayed(const Duration(milliseconds: 16));

    if (MlSimulatorConfig.leavingChair || !MlSimulatorConfig.faceDetected) {
      return const FaceMeshResult(
        faceDetected: false,
        multipleFacesDetected: false,
        landmarks: [],
        leftEyeEar: 0.0,
        rightEyeEar: 0.0,
        isLookingAway: false,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
      );
    }

    final double earValue = MlSimulatorConfig.eyesClosed ? 0.12 : 0.32;
    final double yawValue = MlSimulatorConfig.lookingAway ? 35.0 : 5.0;

    // Generate 478 mock landmarks distributed in a circle/face shape
    final List<LandmarkPoint> mockLandmarks = List.generate(478, (i) {
      final double angle = (i / 478) * 2 * math.pi;
      return LandmarkPoint(
        x: 0.5 + 0.15 * math.cos(angle),
        y: 0.45 + 0.2 * math.sin(angle),
        z: -0.05 * math.cos(angle),
      );
    });

    return FaceMeshResult(
      faceDetected: true,
      multipleFacesDetected: MlSimulatorConfig.multipleFaces,
      landmarks: mockLandmarks,
      leftEyeEar: earValue,
      rightEyeEar: earValue,
      isLookingAway: MlSimulatorConfig.lookingAway,
      yaw: yawValue,
      pitch: 0.0,
      roll: 0.0,
    );
  }

  @override
  void dispose() {}
}

// ── Simulated Posture Tracker ───────────────────────────────────────────────

class SimulatedPostureTracker implements PostureTrackerService {
  @override
  Future<void> initialize() async {}

  @override
  Future<PostureResult> processImage(CameraImage image, CameraDescription camera) async {
    await Future<void>.delayed(const Duration(milliseconds: 12));

    final Map<int, Offset> keypoints = {
      0: const Offset(0.5, 0.3), // nose
      1: const Offset(0.47, 0.27), // left eye
      2: const Offset(0.53, 0.27), // right eye
      5: const Offset(0.4, 0.5),  // left shoulder
      6: const Offset(0.6, 0.5),  // right shoulder
    };

    final double score = MlSimulatorConfig.postureConfidence * 100.0;

    return PostureResult(
      isSlouching: MlSimulatorConfig.slouching,
      postureScore: score,
      headRollAngle: MlSimulatorConfig.slouching ? 12.0 : 1.0,
      shoulderRollAngle: MlSimulatorConfig.slouching ? 8.0 : 0.5,
      keypoints: keypoints,
    );
  }

  @override
  void dispose() {}
}

// ── Simulated Object Detector ───────────────────────────────────────────────

class SimulatedObjectDetector implements ObjectDetectorService {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<DetectedObject>> processImage(CameraImage image, CameraDescription camera) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final List<DetectedObject> list = <DetectedObject>[];

    if (MlSimulatorConfig.leavingChair) {
      list.add(DetectedObject(
        label: StudyObjectClass.chair,
        confidence: MlSimulatorConfig.leavingChairConfidence,
        boundingBox: const BoundingBox(left: 0.2, top: 0.3, width: 0.6, height: 0.6),
      ));
      return list;
    }

    if (MlSimulatorConfig.phonePresent) {
      list.add(DetectedObject(
        label: StudyObjectClass.phone,
        confidence: MlSimulatorConfig.phoneConfidence,
        boundingBox: const BoundingBox(left: 0.7, top: 0.6, width: 0.15, height: 0.25),
      ));
    }

    if (MlSimulatorConfig.bookPresent) {
      list.add(DetectedObject(
        label: StudyObjectClass.book,
        confidence: MlSimulatorConfig.bookConfidence,
        boundingBox: const BoundingBox(left: 0.3, top: 0.7, width: 0.4, height: 0.25),
      ));
    }

    if (MlSimulatorConfig.laptopPresent) {
      list.add(DetectedObject(
        label: StudyObjectClass.laptop,
        confidence: MlSimulatorConfig.laptopConfidence,
        boundingBox: const BoundingBox(left: 0.2, top: 0.5, width: 0.5, height: 0.4),
      ));
    }

    return list;
  }

  @override
  void dispose() {}
}
