import 'package:camera/camera.dart';

abstract class FaceDetectionService {
  Future<bool> hasFace(CameraImage image, CameraDescription camera);

  Future<void> dispose() async {}
}