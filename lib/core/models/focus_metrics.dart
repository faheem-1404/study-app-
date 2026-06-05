import 'dart:ui';

/// Represents focus detection metrics captured from face and object analysis
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
    
    // Upgraded ML detection fields
    this.multipleFaces = false,
    this.phoneDetected = false,
    this.bookDetected = false,
    this.laptopDetected = false,
    this.leavingChair = false,
    this.slouching = false,
    this.headYaw = 0.0,
    this.headRoll = 0.0,
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

  // Upgraded ML detection fields
  final bool multipleFaces;
  final bool phoneDetected;
  final bool bookDetected;
  final bool laptopDetected;
  final bool leavingChair;
  final bool slouching;
  final double headYaw;
  final double headRoll;

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
    bool? multipleFaces,
    bool? phoneDetected,
    bool? bookDetected,
    bool? laptopDetected,
    bool? leavingChair,
    bool? slouching,
    double? headYaw,
    double? headRoll,
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
      multipleFaces: multipleFaces ?? this.multipleFaces,
      phoneDetected: phoneDetected ?? this.phoneDetected,
      bookDetected: bookDetected ?? this.bookDetected,
      laptopDetected: laptopDetected ?? this.laptopDetected,
      leavingChair: leavingChair ?? this.leavingChair,
      slouching: slouching ?? this.slouching,
      headYaw: headYaw ?? this.headYaw,
      headRoll: headRoll ?? this.headRoll,
    );
  }
}
