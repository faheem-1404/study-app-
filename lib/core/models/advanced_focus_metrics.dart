import 'focus_state.dart';

/// Represents historical focus data for stability calculation
class FocusHistoryEntry {
  FocusHistoryEntry({
    required this.timestamp,
    required this.focusScore,
    required this.state,
    required this.headYaw,
    required this.headPitch,
  });

  final DateTime timestamp;
  final int focusScore;
  final FocusState state;
  final double headYaw;
  final double headPitch;
}

/// Advanced tracking data with stability metrics
class AdvancedFocusMetrics {
  AdvancedFocusMetrics({
    required this.state,
    required this.focusScore,
    required this.focusStability,
    required this.headYaw,
    required this.headPitch,
    required this.timeInState,
    required this.isStateStable,
    this.distractionWarningActive = false,
    this.isPausedDueToDistraction = false,
  });

  /// Current focus state (IDLE, FOCUS, DISTRACTED)
  final FocusState state;

  /// Focus score (0-100)
  final int focusScore;

  /// Focus stability (0-100%) based on last 10 seconds
  final double focusStability;

  /// Head rotation left/right (-90 to 90)
  final double headYaw;

  /// Head rotation up/down (-90 to 90)
  final double headPitch;

  /// How long in current state (milliseconds)
  final int timeInState;

  /// Whether current state is stable
  final bool isStateStable;

  /// Whether distraction warning is active
  final bool distractionWarningActive;

  /// Whether session is paused due to distraction
  final bool isPausedDueToDistraction;

  /// Whether time should be counted
  bool get isCountingTime => state == FocusState.focus && focusStability > 70;

  /// Reward multiplier based on focus quality
  double get rewardMultiplier {
    if (state != FocusState.focus) return 0.5; // 50% for distracted
    if (focusStability > 90) return 1.5; // 150% for excellent focus
    if (focusStability > 80) return 1.25; // 125% for very good focus
    if (focusStability > 70) return 1.0; // 100% for good focus
    return 0.75; // 75% for acceptable focus
  }

  AdvancedFocusMetrics copyWith({
    FocusState? state,
    int? focusScore,
    double? focusStability,
    double? headYaw,
    double? headPitch,
    int? timeInState,
    bool? isStateStable,
    bool? distractionWarningActive,
    bool? isPausedDueToDistraction,
  }) {
    return AdvancedFocusMetrics(
      state: state ?? this.state,
      focusScore: focusScore ?? this.focusScore,
      focusStability: focusStability ?? this.focusStability,
      headYaw: headYaw ?? this.headYaw,
      headPitch: headPitch ?? this.headPitch,
      timeInState: timeInState ?? this.timeInState,
      isStateStable: isStateStable ?? this.isStateStable,
      distractionWarningActive: distractionWarningActive ?? this.distractionWarningActive,
      isPausedDueToDistraction: isPausedDueToDistraction ?? this.isPausedDueToDistraction,
    );
  }
}
