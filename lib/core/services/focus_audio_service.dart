import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/focus_sound.dart';

enum AudioMode { off, focusSound, music }

class FocusAudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioMode _mode = AudioMode.off;
  FocusSound _focusSound = FocusSound.whiteNoise;
  double _volume = 0.7;
  String? _musicPath;

  bool _isPlaying = false;
  bool _disposed = false;

  AudioMode get mode => _mode;
  FocusSound get focusSound => _focusSound;
  double get volume => _volume;
  String? get musicPath => _musicPath;
  bool get isPlaying => _isPlaying;
  AudioPlayer get player => _player;

  Future<void> setMode(AudioMode mode) async {
    if (_disposed) return;
    _mode = mode;
    if (mode == AudioMode.off) {
      await stop();
    } else {
      await _playCurrentMode();
    }
  }

  Future<void> setFocusSound(FocusSound sound) async {
    if (_disposed) return;
    _focusSound = sound;
    if (_mode == AudioMode.focusSound && _isPlaying) {
      await _playCurrentMode();
    }
  }

  Future<void> setMusicPath(String path) async {
    if (_disposed) return;
    _musicPath = path;
    if (_mode == AudioMode.music && _isPlaying) {
      await _playCurrentMode();
    }
  }

  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> play() async {
    if (_disposed || _mode == AudioMode.off) return;
    await _playCurrentMode();
  }

  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
    _isPlaying = false;
  }

  Future<void> reduceVolumeForDistraction() async {
    if (_disposed || !_isPlaying) return;
    await _player.setVolume(_volume * 0.3);
  }

  Future<void> restoreVolumeAfterFocus() async {
    if (_disposed || !_isPlaying) return;
    await _player.setVolume(_volume);
  }

  Future<void> _playCurrentMode() async {
    if (_disposed) return;
    try {
      await _player.stop();

      if (_mode == AudioMode.focusSound) {
        await _player.setAsset(_focusSound.assetPath);
        await _player.setLoopMode(LoopMode.one);
      } else if (_mode == AudioMode.music) {
        if (_musicPath == null) return;
        await _player.setFilePath(_musicPath!);
        await _player.setLoopMode(LoopMode.one);
      } else {
        return;
      }

      await _player.setVolume(_volume);
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _player.dispose();
  }
}
