import 'dart:async';

/// Pomodoro session state
enum PomodoroPhase {
  idle,     // Not in a session
  focus,    // 25-minute focus period
  breakTime, // 5-minute break period
}

/// Manages Pomodoro sessions (25 min focus + 5 min break)
class PomodoroService {
  PomodoroService();

  static const int focusMinutes = 25;
  static const int breakMinutes = 5;

  PomodoroPhase _phase = PomodoroPhase.idle;
  Timer? _timer;
  int _remainingSeconds = 0;
  int _sessionsCompleted = 0;

  // Callbacks
  VoidCallback? onPhaseChange;
  VoidCallback? onTimeUpdate;
  VoidCallback? onSessionComplete;
  VoidCallback? onBreakComplete;

  PomodoroPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  int get sessionsCompleted => _sessionsCompleted;
  bool get isActive => _phase != PomodoroPhase.idle;

  /// Start a new Pomodoro session (only auto-triggers on valid focus)
  void startSession() {
    if (_phase != PomodoroPhase.idle) {
      return; // Already running
    }

    _phase = PomodoroPhase.focus;
    _remainingSeconds = focusMinutes * 60;
    _startTimer();
    onPhaseChange?.call();
  }

  /// Start break phase
  void startBreak() {
    if (_phase != PomodoroPhase.focus) {
      return;
    }

    _phase = PomodoroPhase.breakTime;
    _remainingSeconds = breakMinutes * 60;
    _sessionsCompleted++;
    onSessionComplete?.call();
    _startTimer();
    onPhaseChange?.call();
  }

  /// Pause current session
  void pause() {
    _timer?.cancel();
  }

  /// Resume current session
  void resume() {
    if (_phase != PomodoroPhase.idle) {
      _startTimer();
    }
  }

  /// Reset to idle
  void reset() {
    _timer?.cancel();
    _phase = PomodoroPhase.idle;
    _remainingSeconds = 0;
  }

  /// Check if focus phase is complete
  bool isFocusPhaseComplete() => _phase == PomodoroPhase.focus && _remainingSeconds <= 0;

  /// Check if break phase is complete
  bool isBreakPhaseComplete() => _phase == PomodoroPhase.breakTime && _remainingSeconds <= 0;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      onTimeUpdate?.call();

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        if (_phase == PomodoroPhase.focus) {
          startBreak();
        } else if (_phase == PomodoroPhase.breakTime) {
          onBreakComplete?.call();
          reset();
        }
      }
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Type definition for callback
typedef VoidCallback = void Function();
