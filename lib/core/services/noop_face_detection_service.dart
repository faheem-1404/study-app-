import 'package:camera/camera.dart';

import 'face_detection_service.dart';

class NoopFaceDetectionService implements FaceDetectionService {
  @override
  Future<bool> hasFace(CameraImage image, CameraDescription camera) async {
    return image.planes.isNotEmpty;
  }

  @override
  Future<void> dispose() async {
    // No-op service has nothing to dispose
  }
}