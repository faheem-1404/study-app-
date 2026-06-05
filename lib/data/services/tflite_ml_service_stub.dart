import 'package:camera/camera.dart';
import '../../domain/services/ml_service_interfaces.dart';

class TfliteFaceLandmarkerService implements FaceLandmarkerService {
  @override
  Future<void> initialize() async {}

  @override
  Future<FaceMeshResult> processImage(CameraImage image, CameraDescription camera) async {
    throw UnimplementedError('TFLite Face Landmarker not supported on Web');
  }

  @override
  void dispose() {}
}

class TflitePostureTrackerService implements PostureTrackerService {
  @override
  Future<void> initialize() async {}

  @override
  Future<PostureResult> processImage(CameraImage image, CameraDescription camera) async {
    throw UnimplementedError('TFLite Posture Tracker not supported on Web');
  }

  @override
  void dispose() {}
}

class TfliteObjectDetectorService implements ObjectDetectorService {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<DetectedObject>> processImage(CameraImage image, CameraDescription camera) async {
    throw UnimplementedError('TFLite Object Detector not supported on Web');
  }

  @override
  void dispose() {}
}
