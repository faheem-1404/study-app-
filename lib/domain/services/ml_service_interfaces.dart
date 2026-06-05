import 'dart:ui';
import 'package:camera/camera.dart';

/// Bounding box for object detection
class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

/// 3D Landmark point
class LandmarkPoint {
  const LandmarkPoint({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

/// Result of Face Mesh Landmarker
class FaceMeshResult {
  const FaceMeshResult({
    required this.faceDetected,
    required this.multipleFacesDetected,
    required this.landmarks,
    required this.leftEyeEar,
    required this.rightEyeEar,
    required this.isLookingAway,
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  final bool faceDetected;
  final bool multipleFacesDetected;
  final List<LandmarkPoint> landmarks; // 478 landmarks
  final double leftEyeEar;
  final double rightEyeEar;
  final bool isLookingAway;
  final double yaw;
  final double pitch;
  final double roll;

  bool get eyesClosed => leftEyeEar < 0.2 && rightEyeEar < 0.2;
}

/// Result of MoveNet Posture Tracking
class PostureResult {
  const PostureResult({
    required this.isSlouching,
    required this.postureScore,
    required this.headRollAngle,
    required this.shoulderRollAngle,
    required this.keypoints,
  });

  final bool isSlouching;
  final double postureScore; // 0 to 100
  final double headRollAngle;
  final double shoulderRollAngle;
  final Map<int, Offset> keypoints; // joint index -> 2D screen coordinate
}

/// Classes of interest for StudyPay
enum StudyObjectClass {
  phone,
  book,
  laptop,
  chair,
  unknown,
}

/// Detected object from YOLOv8n
class DetectedObject {
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  final StudyObjectClass label;
  final double confidence;
  final BoundingBox boundingBox;
}

/// Abstract classes for ML pipeline
abstract class FaceLandmarkerService {
  Future<void> initialize();
  Future<FaceMeshResult> processImage(CameraImage image, CameraDescription camera);
  void dispose();
}

abstract class PostureTrackerService {
  Future<void> initialize();
  Future<PostureResult> processImage(CameraImage image, CameraDescription camera);
  void dispose();
}

abstract class ObjectDetectorService {
  Future<void> initialize();
  Future<List<DetectedObject>> processImage(CameraImage image, CameraDescription camera);
  void dispose();
}
