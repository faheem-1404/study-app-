import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_detection_service.dart';

class MlKitFaceDetectionService implements FaceDetectionService {
  MlKitFaceDetectionService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableLandmarks: false,
            enableContours: false,
            enableClassification: false,
            minFaceSize: 0.2,
          ),
        );

  final FaceDetector _faceDetector;

  @override
  Future<bool> hasFace(CameraImage image, CameraDescription camera) async {
    final InputImage? inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) {
      return false;
    }

    final List<Face> faces = await _faceDetector.processImage(inputImage);
    return faces.isNotEmpty;
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) {
      return null;
    }

    final InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }

    final BytesBuilder allBytes = BytesBuilder();
    for (final Plane plane in image.planes) {
      allBytes.add(plane.bytes);
    }
    final Uint8List bytes = allBytes.takeBytes();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: Platform.isAndroid ? InputImageFormat.nv21 : format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _faceDetector.close();
  }
}