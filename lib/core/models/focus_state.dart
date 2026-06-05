/// Represents the different focus states
enum FocusState {
  idle,        // Not tracking or face not detected
  focus,       // User is focused and head direction is acceptable
  distracted,  // User is distracted or head direction is off
}

/// Extension for FocusState string representation
extension FocusStateExtension on FocusState {
  String get label {
    switch (this) {
      case FocusState.idle:
        return 'Idle';
      case FocusState.focus:
        return 'Focused';
      case FocusState.distracted:
        return 'Distracted';
    }
  }
}
