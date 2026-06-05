/// Represents focus detection metrics captured from face analysis
class FocusMetrics {
  const FocusMetrics({
    required this.focusScore,
    required this.eyesOpen,
    required this.headStable,
    required this.eyeMovement,
    required this.faceDetected,
    required this.headPitchAngle,
    this.eyesClosedDuration = Duration.zero,
    this.faceMissingDuration = Duration.zero,
  });

  /// Overall focus score (0-100)
  final int focusScore;

  /// Whether eyes are detected as open
  final bool eyesOpen;

  /// Whether head is in stable position (< 45 degrees pitch)
  final bool headStable;

  /// Eye movement level (0-1, where 0 = stable, 1 = high movement)
  final double eyeMovement;

  /// Whether face is detected
  final bool faceDetected;

  /// Head pitch angle in degrees (-90 to 90)
  final double headPitchAngle;

  /// Duration eyes have been closed
  final Duration eyesClosedDuration;

  /// Duration face has been missing
  final Duration faceMissingDuration;

  /// Whether user is considered focused (score > 60)
  bool get isFocused => focusScore > 60;

  /// Whether user is sleeping (eyes closed > 2 seconds)
  bool get isSleeping => eyesClosedDuration.inSeconds > 2;

  /// Whether grace period for face detection is exceeded (> 5 seconds)
  bool get isGraceExpired => faceMissingDuration.inSeconds > 5;

  FocusMetrics copyWith({
    int? focusScore,
    bool? eyesOpen,
    bool? headStable,
    double? eyeMovement,
    bool? faceDetected,
    double? headPitchAngle,
    Duration? eyesClosedDuration,
    Duration? faceMissingDuration,
  }) {
    return FocusMetrics(
      focusScore: focusScore ?? this.focusScore,
      eyesOpen: eyesOpen ?? this.eyesOpen,
      headStable: headStable ?? this.headStable,
      eyeMovement: eyeMovement ?? this.eyeMovement,
      faceDetected: faceDetected ?? this.faceDetected,
      headPitchAngle: headPitchAngle ?? this.headPitchAngle,
      eyesClosedDuration: eyesClosedDuration ?? this.eyesClosedDuration,
      faceMissingDuration: faceMissingDuration ?? this.faceMissingDuration,
    );
  }
}
