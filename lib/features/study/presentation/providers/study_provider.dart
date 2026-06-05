import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/focus_metrics.dart';
import '../../../../core/models/study_session_summary.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/credit_calculator.dart';
import '../../../../core/services/focus_audio_service.dart';
import '../../../../domain/services/ml_service_interfaces.dart';
import '../../../../domain/services/focus_analyzer.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';

class StudyState {
  const StudyState({
    this.cameraReady = false,
    this.sessionActive = false,
    this.faceVisible = false,
    this.invalidated = false,
    this.targetSeconds = AppConstants.defaultStudyMinutes * 60,
    this.remainingSeconds = AppConstants.defaultStudyMinutes * 60,
    this.focusedSeconds = 0,
    this.pausedSeconds = 0,
    this.absentSeconds = 0,
    this.focusScore = 0,
    this.statusMessage = 'Ready to start',
    this.latestSummary,
    this.currentFocusMetrics,
  });

  final bool cameraReady;
  final bool sessionActive;
  final bool faceVisible;
  final bool invalidated;
  final int targetSeconds;
  final int remainingSeconds;
  final int focusedSeconds;
  final int pausedSeconds;
  final int absentSeconds;
  final int focusScore;
  final String statusMessage;
  final StudySessionSummary? latestSummary;
  final FocusMetrics? currentFocusMetrics;

  int get targetMinutes => targetSeconds ~/ 60;
  double get focusPercentage => focusScore / 100.0;

  StudyState copyWith({
    bool? cameraReady,
    bool? sessionActive,
    bool? faceVisible,
    bool? invalidated,
    int? targetSeconds,
    int? remainingSeconds,
    int? focusedSeconds,
    int? pausedSeconds,
    int? absentSeconds,
    int? focusScore,
    String? statusMessage,
    StudySessionSummary? latestSummary,
    FocusMetrics? currentFocusMetrics,
  }) {
    return StudyState(
      cameraReady: cameraReady ?? this.cameraReady,
      sessionActive: sessionActive ?? this.sessionActive,
      faceVisible: faceVisible ?? this.faceVisible,
      invalidated: invalidated ?? this.invalidated,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      focusedSeconds: focusedSeconds ?? this.focusedSeconds,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      absentSeconds: absentSeconds ?? this.absentSeconds,
      focusScore: focusScore ?? this.focusScore,
      statusMessage: statusMessage ?? this.statusMessage,
      latestSummary: latestSummary ?? this.latestSummary,
      currentFocusMetrics: currentFocusMetrics ?? this.currentFocusMetrics,
    );
  }
}

class StudyController extends StateNotifier<StudyState> {
  StudyController(this._ref) : super(const StudyState()) {
    _faceService = _ref.read(faceLandmarkerServiceProvider);
    _postureService = _ref.read(postureTrackerServiceProvider);
    _objectService = _ref.read(objectDetectorServiceProvider);
    _analyzer = _ref.read(focusAnalyzerProvider);
  }

  final Ref _ref;
  final FocusAudioService audioService = FocusAudioService();

  late final FaceLandmarkerService _faceService;
  late final PostureTrackerService _postureService;
  late final ObjectDetectorService _objectService;
  late final FocusAnalyzer _analyzer;

  CameraController? _cameraController;
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  bool _faceAnalysisBusy = false;
  bool _lastFocusState = true;

  CameraController? get cameraController => _cameraController;

  Future<void> initializeCamera() async {
    if (state.cameraReady) return;

    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (_) {}
      _cameraController = null;
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(
          cameraReady: false,
          statusMessage: 'No camera found on this device',
        );
        return;
      }

      final CameraDescription selectedCamera = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      state = state.copyWith(
        cameraReady: true,
        statusMessage: 'Camera ready',
      );
    } catch (e) {
      _cameraController = null;
      state = state.copyWith(
        cameraReady: false,
        statusMessage: 'Failed to open camera: $e',
      );
    }
  }

  Future<void> startSession({required int minutes}) async {
    if (state.sessionActive) return;

    state = StudyState(
      cameraReady: state.cameraReady,
      sessionActive: true,
      targetSeconds: minutes * 60,
      remainingSeconds: minutes * 60,
      statusMessage: 'Looking for your face...',
    );

    _analyzer.reset();
    _lastFocusState = true;

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await initializeCamera();
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      state = state.copyWith(
        sessionActive: false,
        statusMessage: 'Camera unavailable',
      );
      return;
    }

    // Process camera stream
    if (kIsWeb) {
      _startWebFocusPolling();
    } else {
      try {
        await _cameraController!.startImageStream(_processCameraImage);
      } catch (e) {
        // Fallback to polling on native platforms if stream fails
        _startWebFocusPolling();
      }
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), _tick);

    if (audioService.mode != AudioMode.off) {
      await audioService.play();
    }
  }

  void _startWebFocusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!state.sessionActive) {
        timer.cancel();
        return;
      }
      
      // Build a simulated CameraImage or pass dummy parameters
      // Simulated ML runs instantly from simulator config toggles
      final FaceMeshResult faceResult = await _faceService.processImage(
        null as dynamic, 
        _cameraController!.description,
      );
      final PostureResult postureResult = await _postureService.processImage(
        null as dynamic,
        _cameraController!.description,
      );
      final List<DetectedObject> objects = await _objectService.processImage(
        null as dynamic,
        _cameraController!.description,
      );

      final FocusMetrics metrics = _analyzer.analyzeFrame(
        faceResult: faceResult,
        postureResult: postureResult,
        objects: objects,
      );

      _applyFocusMetrics(metrics);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_faceAnalysisBusy || !state.sessionActive) return;

    _faceAnalysisBusy = true;
    try {
      final CameraDescription desc = _cameraController!.description;
      
      // Async predictions from models
      final FaceMeshResult faceResult = await _faceService.processImage(image, desc);
      final PostureResult postureResult = await _postureService.processImage(image, desc);
      final List<DetectedObject> objects = await _objectService.processImage(image, desc);

      final FocusMetrics metrics = _analyzer.analyzeFrame(
        faceResult: faceResult,
        postureResult: postureResult,
        objects: objects,
      );

      _applyFocusMetrics(metrics);
    } catch (e) {
      // Graceful error logging
    } finally {
      _faceAnalysisBusy = false;
    }
  }

  void _applyFocusMetrics(FocusMetrics metrics) {
    if (!state.sessionActive) return;

    final bool isFocused = metrics.focusScore > 50;

    // Vibrate on focus loss
    if (_lastFocusState && !isFocused) {
      _triggerFocusLossVibration();
    }

    // Vibrate on prolonged eye closure
    if (metrics.eyesClosedDuration.inSeconds >= 2 &&
        metrics.eyesClosedDuration.inMilliseconds < 2200) {
      _triggerSleepVibration();
    }

    // Volume reduction
    if (audioService.mode != AudioMode.off && audioService.isPlaying) {
      if (!isFocused) {
        audioService.reduceVolumeForDistraction();
      } else {
        audioService.restoreVolumeAfterFocus();
      }
    }

    _lastFocusState = isFocused;

    bool faceVisibleState = true;
    String status = 'Focused. Timer running.';

    // Grace periods:
    // Face Missing > 3 sec
    // Multiple Faces > 5 sec
    // Phone Usage > 10 sec
    // Eyes Closed (Sleeping) > 5 sec

    if (metrics.faceMissingDuration.inSeconds > 3 || metrics.leavingChair) {
      faceVisibleState = false;
      status = 'Face not detected. Session paused.';
    } else if (metrics.multipleFacesDuration.inSeconds > 5) {
      faceVisibleState = false;
      status = 'Multiple faces detected. Session paused.';
    } else if (metrics.phoneDuration.inSeconds > 10) {
      faceVisibleState = false;
      status = 'Phone usage detected. Session paused.';
    } else if (metrics.eyesClosedDuration.inSeconds > 5) {
      faceVisibleState = false;
      status = 'Sleeping detected! Sleep alert active.';
    } else if (metrics.phoneDetected) {
      final int remaining = 10 - metrics.phoneDuration.inSeconds;
      status = 'Phone detected! Put it away (Grace: ${remaining}s)';
    } else if (metrics.multipleFaces) {
      final int remaining = 5 - metrics.multipleFacesDuration.inSeconds;
      status = 'Multiple faces! Remove others (Grace: ${remaining}s)';
    } else if (!metrics.faceDetected) {
      final int remaining = 3 - metrics.faceMissingDuration.inSeconds;
      status = 'Face lost! Return to screen (Grace: ${remaining}s)';
    } else if (metrics.eyesClosedDuration.inSeconds > 0) {
      final int remaining = 5 - metrics.eyesClosedDuration.inSeconds;
      status = 'Eyes closed! Wake up (Grace: ${remaining}s)';
    } else if (metrics.slouching) {
      status = 'Warning: Bad posture detected!';
    } else if (!isFocused) {
      status = 'Low focus level. Pay attention.';
    }

    state = state.copyWith(
      focusScore: metrics.focusScore,
      faceVisible: faceVisibleState,
      currentFocusMetrics: metrics,
      statusMessage: status,
    );
  }

  void _tick(Timer timer) {
    if (!state.sessionActive) return;

    if (state.faceVisible) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          focusedSeconds: state.focusedSeconds + 1,
          absentSeconds: 0,
        );
      } else {
        stopSession();
      }
    } else {
      final int newPaused = state.pausedSeconds + 1;
      final int newAbsent = state.absentSeconds + 1;

      // Invalidation check (if absent for antiCheatGraceSeconds = 8s)
      if (newAbsent >= AppConstants.antiCheatGraceSeconds) {
        state = state.copyWith(
          pausedSeconds: newPaused,
          absentSeconds: newAbsent,
          statusMessage: 'Session invalidated: distraction limit exceeded.',
        );
        stopSession(markAsInvalidated: true);
      } else {
        state = state.copyWith(
          pausedSeconds: newPaused,
          absentSeconds: newAbsent,
        );
      }
    }
  }

  Future<void> stopSession({bool markAsInvalidated = false}) async {
    if (!state.sessionActive && state.latestSummary == null) return;

    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    if (_cameraController?.value.isStreamingImages == true) {
      try {
        await _cameraController?.stopImageStream();
      } catch (_) {}
    }

    await audioService.stop();

    final bool isInvalid = markAsInvalidated || state.invalidated;

    final double credits = isInvalid
        ? 0.0
        : CreditCalculator.calculateCredits(
            focusedSeconds: state.focusedSeconds,
            focusModeEnabled: audioService.mode != AudioMode.off,
          );

    final summary = StudySessionSummary(
      plannedSeconds: state.targetSeconds,
      focusedSeconds: state.focusedSeconds,
      pausedSeconds: state.pausedSeconds,
      absentSeconds: state.absentSeconds,
      earnedCredits: credits,
      invalidated: isInvalid,
      message: state.statusMessage,
    );

    state = state.copyWith(
      sessionActive: false,
      invalidated: isInvalid,
      latestSummary: summary,
    );

    // Commit credits to wallet repository
    if (!isInvalid && credits > 0) {
      await _ref.read(walletControllerProvider.notifier).commitStudySummary(summary);
    }
  }

  Future<void> cancelSession() async {
    await stopSession(markAsInvalidated: true);
  }

  void clearLatestSummary() {
    state = state.copyWith(latestSummary: null);
  }

  Future<void> _triggerFocusLossVibration() async {
    try {
      final bool has = await Vibration.hasVibrator();
      if (has) await Vibration.vibrate(duration: 80);
    } catch (_) {}
  }

  Future<void> _triggerSleepVibration() async {
    try {
      final bool has = await Vibration.hasVibrator();
      if (has) {
        await Vibration.vibrate(duration: 50);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 50);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    audioService.dispose();
    _cameraController?.dispose();
    super.dispose();
  }
}

/// Global StudyController Provider
final studyControllerProvider = StateNotifierProvider<StudyController, StudyState>((ref) {
  return StudyController(ref);
});
