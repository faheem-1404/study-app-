import 'dart:collection';

import '../models/focus_metrics.dart' as old;
import '../models/advanced_focus_metrics.dart';
import '../models/focus_state.dart';

/// Intelligent focus tracking service with state machine
class IntelligentFocusTracker {
  IntelligentFocusTracker();

  // State machine timing thresholds (milliseconds)
  static const int stableRequiredMs = 2000; // 2 seconds before tracking starts
  static const int distractionWarningMs = 3000; // 3 seconds before warning
  static const int distractionPauseMs = 5000; // 5 seconds before pausing
  static const int resumeGraceMs = 5000; // 5 seconds to resume
  static const int evaluationIntervalMs = 1000; // Evaluate every 1 second

  // Head direction thresholds (degrees)
  static const double focusedYawThreshold = 25; // -25 to +25 = focused
  static const double acceptableYawThreshold = 45; // -45 to +45 = acceptable
  static const double focusedPitchThreshold = 45;

  // State tracking
  FocusState _currentState = FocusState.idle;
  DateTime? _stateStartTime;
  DateTime? _lastEvaluationTime;
  DateTime? _distractionStartTime;
  DateTime? _pauseStartTime;

  // Face stability tracking
  DateTime? _faceFirstDetectedTime;

  // History for stability calculation (last 10 seconds)
  final Queue<_HistoryEntry> _focusHistory = Queue();
  static const int historyWindowMs = 10000; // 10 seconds

  // Streak tracking for rewards
  int _focusStreakSeconds = 0;
  int _bestStreakSeconds = 0;

  /// Get current advanced metrics
  AdvancedFocusMetrics? _lastMetrics;

  AdvancedFocusMetrics? get lastMetrics => _lastMetrics;
  FocusState get currentState => _currentState;
  int get focusStreakSeconds => _focusStreakSeconds;
  int get bestStreakSeconds => _bestStreakSeconds;

  /// Process raw focus metrics and update state
  AdvancedFocusMetrics processMetrics(old.FocusMetrics rawMetrics) {
    final now = DateTime.now();

    // Initialize timing if needed
    _lastEvaluationTime ??= now;

    // Handle face detection state
    if (!rawMetrics.faceDetected) {
      _faceFirstDetectedTime = null;
      _stateStartTime = null;

      // If already in a tracking state and face disappears, reset
      if (_currentState != FocusState.idle) {
        _currentState = FocusState.idle;
        _stateStartTime = now;
        _resetStreakIfNeeded();
      }

      _lastMetrics = AdvancedFocusMetrics(
        state: FocusState.idle,
        focusScore: 0,
        focusStability: 0,
        headYaw: 0,
        headPitch: rawMetrics.headPitchAngle,
        timeInState: 0,
        isStateStable: false,
      );

      return _lastMetrics!;
    }

    // Face detected - track stability
    _faceFirstDetectedTime ??= now;
    final timeSinceFaceDetected =
        now.difference(_faceFirstDetectedTime!).inMilliseconds;

    // Only start tracking after face is stable for 2 seconds
    if (timeSinceFaceDetected < stableRequiredMs) {
      _lastMetrics = AdvancedFocusMetrics(
        state: FocusState.idle,
        focusScore: rawMetrics.focusScore,
        focusStability: 0,
        headYaw: 0,
        headPitch: rawMetrics.headPitchAngle,
        timeInState: timeSinceFaceDetected,
        isStateStable: false,
      );

      return _lastMetrics!;
    }

    // Evaluate head direction only every 1 second
    final timeSinceLastEval =
        now.difference(_lastEvaluationTime!).inMilliseconds;
    final shouldEvaluate = timeSinceLastEval >= evaluationIntervalMs;

    if (shouldEvaluate) {
      _lastEvaluationTime = now;
      _evaluateHeadDirection(rawMetrics, now);
    }

    // Add to history for stability calculation
    _addToHistory(rawMetrics.focusScore, _currentState, rawMetrics.headPitchAngle, 0);

    // Calculate focus stability
    final focusStability = _calculateFocusStability();

    // Calculate time in current state
    _stateStartTime ??= now;
    final timeInState = now.difference(_stateStartTime!).inMilliseconds;

    // Update streak if in focus state
    if (_currentState == FocusState.focus) {
      _focusStreakSeconds = timeInState ~/ 1000;
      if (_focusStreakSeconds > _bestStreakSeconds) {
        _bestStreakSeconds = _focusStreakSeconds;
      }
    } else {
      _resetStreakIfNeeded();
    }

    // Handle distraction warnings and pausing
    bool distractionWarningActive = false;
    bool isPausedDueToDistraction = false;

    if (_currentState == FocusState.distracted) {
      _distractionStartTime ??= now;
      final timeSinceDistraction =
          now.difference(_distractionStartTime!).inMilliseconds;

      // Show warning after 3 seconds
      if (timeSinceDistraction > distractionWarningMs) {
        distractionWarningActive = true;
      }

      // Pause after 5 seconds
      if (timeSinceDistraction > distractionPauseMs) {
        isPausedDueToDistraction = true;
        _pauseStartTime ??= now;
      }

      // Resume if user returns within 5 seconds of being paused
      if (isPausedDueToDistraction && _pauseStartTime != null) {
        final timeSincePause =
            now.difference(_pauseStartTime!).inMilliseconds;
        if (timeSincePause > resumeGraceMs) {
          // Grace period expired - reset session
          _resetSession();
        }
      }
    } else {
      _distractionStartTime = null;
      _pauseStartTime = null;
    }

    final isStateStable = timeInState > stableRequiredMs;

    _lastMetrics = AdvancedFocusMetrics(
      state: _currentState,
      focusScore: rawMetrics.focusScore,
      focusStability: focusStability,
      headYaw: 0, // Will be calculated from landmarks
      headPitch: rawMetrics.headPitchAngle,
      timeInState: timeInState,
      isStateStable: isStateStable,
      distractionWarningActive: distractionWarningActive,
      isPausedDueToDistraction: isPausedDueToDistraction,
    );

    return _lastMetrics!;
  }

  /// Evaluate head direction and update state
  void _evaluateHeadDirection(old.FocusMetrics metrics, DateTime now) {
    final pitch = metrics.headPitchAngle;

    // Simplified: use focus score to determine state
    // In production, would calculate actual yaw/pitch from landmarks
    final headYaw = 0.0; // Placeholder

    // Determine if focused based on head direction
    final isFocused = _isHeadDirectionFocused(headYaw, pitch);

    if (isFocused && metrics.focusScore > 60) {
      // Transition to FOCUS
      if (_currentState != FocusState.focus) {
        _currentState = FocusState.focus;
        _stateStartTime = now;
      }
    } else if (metrics.focusScore < 50) {
      // Transition to DISTRACTED
      if (_currentState == FocusState.focus) {
        _currentState = FocusState.distracted;
        _stateStartTime = now;
        _distractionStartTime = now;
      }
    } else {
      // Stay in current state if score is between 50-60
    }
  }

  /// Check if head direction indicates focus
  bool _isHeadDirectionFocused(double yaw, double pitch) {
    final isYawFocused = yaw.abs() < focusedYawThreshold;
    final isPitchFocused = pitch.abs() < focusedPitchThreshold;
    return isYawFocused && isPitchFocused;
  }

  /// Calculate focus stability based on history
  double _calculateFocusStability() {
    if (_focusHistory.isEmpty) return 0;

    // Count entries that are in FOCUS state
    final focusCount = _focusHistory.where((e) => e.state == FocusState.focus).length;
    return (focusCount / _focusHistory.length) * 100;
  }

  /// Add metrics to history with cleanup
  void _addToHistory(
      int focusScore, FocusState state, double pitch, double yaw) {
    final now = DateTime.now();

    _focusHistory.addLast(
      _HistoryEntry(
        timestamp: now,
        focusScore: focusScore,
        state: state,
        headPitch: pitch,
        headYaw: yaw,
      ),
    );

    // Remove old entries outside 10-second window
    while (_focusHistory.isNotEmpty) {
      final oldest = _focusHistory.first;
      final age = now.difference(oldest.timestamp).inMilliseconds;
      if (age > historyWindowMs) {
        _focusHistory.removeFirst();
      } else {
        break;
      }
    }
  }

  /// Reset streak if not in focus state
  void _resetStreakIfNeeded() {
    if (_currentState != FocusState.focus) {
      _focusStreakSeconds = 0;
    }
  }

  /// Reset entire session (called when grace period expires)
  void _resetSession() {
    _currentState = FocusState.idle;
    _stateStartTime = null;
    _distractionStartTime = null;
    _pauseStartTime = null;
    _faceFirstDetectedTime = null;
    _focusHistory.clear();
    _focusStreakSeconds = 0;
  }

  /// Reset tracker state
  void reset() {
    _resetSession();
    _bestStreakSeconds = 0;
    _lastMetrics = null;
  }
}

/// Internal history entry
class _HistoryEntry {
  _HistoryEntry({
    required this.timestamp,
    required this.focusScore,
    required this.state,
    required this.headPitch,
    required this.headYaw,
  });

  final DateTime timestamp;
  final int focusScore;
  final FocusState state;
  final double headPitch;
  final double headYaw;
}
