import 'package:flutter/services.dart';

class NativeCvBridge {
  static const MethodChannel _channel = MethodChannel('study_earn/native_cv');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> detectFace() async {
    try {
      return await _channel.invokeMethod<bool>('detectFace') ?? false;
    } catch (_) {
      return false;
    }
  }
}