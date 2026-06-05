import 'dart:math';
import 'dart:typed_data';

import '../models/focus_sound.dart';

class AmbientAudioService {
  static const int _sampleRate = 44100;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  final Random _random = Random();

  Uint8List buildWaveBytes(
    FocusSound sound, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final int sampleCount = (_sampleRate * duration.inMilliseconds / 1000)
        .round();
    final Int16List samples = Int16List(sampleCount);

    double filter = 0;
    for (int index = 0; index < sampleCount; index++) {
      switch (sound) {
        case FocusSound.whiteNoise:
          samples[index] = _whiteNoiseSample();
          break;
        case FocusSound.rain:
          filter = filter * 0.96 + (_random.nextDouble() * 2 - 1) * 1800;
          final double drop = _random.nextDouble() < 0.0015
              ? _random.nextDouble() * 14000
              : 0;
          final int sample = (filter + drop).clamp(-16000, 16000).round();
          samples[index] = sample;
          break;
        case FocusSound.brownNoise:
          // Brown noise: integrate white noise (each sample += prev * 0.996)
          filter = filter * 0.996 + (_random.nextDouble() * 2 - 1) * 200;
          samples[index] = filter.clamp(-16000, 16000).round();
          break;
      }
    }

    return _toWav(samples);
  }

  int _whiteNoiseSample() {
    final double raw = (_random.nextDouble() * 2 - 1) * 9000;
    return raw.round();
  }

  Uint8List _toWav(Int16List samples) {
    final int dataSize = samples.length * 2;
    final ByteData buffer = ByteData(44 + dataSize);

    _writeString(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    _writeString(buffer, 8, 'WAVE');
    _writeString(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, _channels, Endian.little);
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(
      28,
      _sampleRate * _channels * _bitsPerSample ~/ 8,
      Endian.little,
    );
    buffer.setUint16(32, _channels * _bitsPerSample ~/ 8, Endian.little);
    buffer.setUint16(34, _bitsPerSample, Endian.little);
    _writeString(buffer, 36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    for (int index = 0; index < samples.length; index++) {
      buffer.setInt16(44 + (index * 2), samples[index], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  void _writeString(ByteData data, int offset, String value) {
    for (int index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
}