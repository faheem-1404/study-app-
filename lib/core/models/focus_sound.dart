enum FocusSound {
  whiteNoise,
  rain,
  brownNoise,
}

extension FocusSoundLabel on FocusSound {
  String get label {
    switch (this) {
      case FocusSound.whiteNoise:
        return 'White Noise';
      case FocusSound.rain:
        return 'Rain';
      case FocusSound.brownNoise:
        return 'Brown Noise';
    }
  }

  String get assetPath {
    switch (this) {
      case FocusSound.whiteNoise:
        return 'assets/sounds/white_noise.mp3';
      case FocusSound.rain:
        return 'assets/sounds/rain.mp3';
      case FocusSound.brownNoise:
        return 'assets/sounds/brown_noise.mp3';
    }
  }

  String get emoji {
    switch (this) {
      case FocusSound.whiteNoise:
        return '🌫️';
      case FocusSound.rain:
        return '🌧️';
      case FocusSound.brownNoise:
        return '🌊';
    }
  }
}