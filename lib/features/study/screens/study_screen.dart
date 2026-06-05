import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/focus_sound.dart';
import '../../../core/models/focus_metrics.dart';
import '../../../core/models/study_session_summary.dart';
import '../../../core/services/focus_audio_service.dart';
import '../../shared/widgets/metric_card.dart';
import '../presentation/providers/study_provider.dart';
import '../../../data/services/simulated_ml_service.dart';
import 'study_result_screen.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with SingleTickerProviderStateMixin {
  bool _cameraPermissionGranted = false;
  bool _isPreparing = true;
  bool _sessionStarted = false;
  bool _showAudioPanel = false;
  bool _showDevPanel = true; // Show simulation panel by default on web/sim
  final ValueNotifier<int> _minutesNotifier =
      ValueNotifier<int>(AppConstants.defaultStudyMinutes);

  late AnimationController _panelAnim;
  late Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _panelFade = CurvedAnimation(parent: _panelAnim, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareCamera();
    });
  }

  @override
  void dispose() {
    _minutesNotifier.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  Future<void> _prepareCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermissionGranted = status.isGranted);
    if (!status.isGranted) {
      setState(() => _isPreparing = false);
      return;
    }

    try {
      await ref.read(studyControllerProvider.notifier).initializeCamera();
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  Future<bool> _onWillPop() async {
    final studyState = ref.read(studyControllerProvider);
    if (!studyState.sessionActive) return true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End study session?'),
        content: const Text(
            'Leaving now will stop the session and no credits will be awarded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) {
      await ref.read(studyControllerProvider.notifier).cancelSession();
      return true;
    }
    return false;
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _toggleAudioPanel() {
    setState(() => _showAudioPanel = !_showAudioPanel);
    if (_showAudioPanel) {
      _panelAnim.forward();
    } else {
      _panelAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFD4AF37);
    const Color darkBg = Color(0xFF0D0D0D);
    const Color green = Color(0xFF4CAF50);
    
    final studyState = ref.watch(studyControllerProvider);

    // Listen for session result and redirect to summary screen
    ref.listen<StudyState>(studyControllerProvider, (previous, next) {
      if (next.latestSummary != null) {
        final summary = next.latestSummary!;
        ref.read(studyControllerProvider.notifier).clearLatestSummary();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => StudyResultScreen(summary: summary),
          ),
        );
      }
    });

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: darkBg,
        body: Builder(
          builder: (context) {
            if (_isPreparing) {
              return const Center(child: CircularProgressIndicator(color: gold));
            }

            if (!_cameraPermissionGranted) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 48, color: gold),
                    const SizedBox(height: 16),
                    const Text('Camera permission required',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: openAppSettings,
                        child: const Text('Open Settings')),
                  ],
                ),
              );
            }

            if (!_sessionStarted) {
              return _PreSessionPanel(
                state: studyState,
                minutesNotifier: _minutesNotifier,
                onStartSession: () async {
                  setState(() => _sessionStarted = true);
                  await ref.read(studyControllerProvider.notifier).startSession(minutes: _minutesNotifier.value);
                },
              );
            }

            final CameraController? ctrl = ref.read(studyControllerProvider.notifier).cameraController;
            final bool ready = ctrl != null && ctrl.value.isInitialized;

            if (!ready) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(studyState.statusMessage,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        await ref.read(studyControllerProvider.notifier).cancelSession();
                        if (mounted) setState(() => _sessionStarted = false);
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final bool isFocused = studyState.focusScore > 50;

            return Stack(
              children: [
                // ── Camera preview ──────────────────────────────────────
                SizedBox.expand(child: CameraPreview(ctrl)),

                // ── Face Mesh and Bounding Box Canvas Painter Overlay ────
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MlOverlayPainter(metrics: studyState.currentFocusMetrics),
                    ),
                  ),
                ),

                // ── Focus glow border ───────────────────────────────────
                if (isFocused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: green.withValues(alpha: 0.35),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Top-right HUD ───────────────────────────────────────
                Positioned(
                  top: 16,
                  right: 16,
                  child: _HudOverlay(
                    time: _fmt(studyState.remainingSeconds),
                    focusPct: studyState.focusScore,
                    credits: studyState.focusedSeconds ~/ 60,
                  ),
                ),

                // ── Bottom-right: 🎧 Audio button ───────────────────────
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _AudioFab(
                    audioService: ref.read(studyControllerProvider.notifier).audioService,
                    onTap: _toggleAudioPanel,
                  ),
                ),

                // ── Audio panel (glass) ─────────────────────────────────
                if (_showAudioPanel)
                  Positioned(
                    bottom: 72,
                    right: 16,
                    child: FadeTransition(
                      opacity: _panelFade,
                      child: _AudioPanel(
                        audioService: ref.read(studyControllerProvider.notifier).audioService,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ),

                // ── Collapsible Developer Simulation Panel ───────────────
                if (_showDevPanel)
                  Positioned(
                    left: 16,
                    top: 16,
                    bottom: 80,
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.settings_suggest_rounded, color: gold, size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  'ML Simulator',
                                  style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 14),
                                  onPressed: () => setState(() => _showDevPanel = false),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 12),
                            _DevToggle(
                              label: 'Face Present',
                              value: MlSimulatorConfig.faceDetected,
                              onChanged: (v) => setState(() => MlSimulatorConfig.faceDetected = v),
                            ),
                            _DevToggle(
                              label: 'Multiple Faces',
                              value: MlSimulatorConfig.multipleFaces,
                              onChanged: (v) => setState(() => MlSimulatorConfig.multipleFaces = v),
                            ),
                            _DevToggle(
                              label: 'Eyes Closed',
                              value: MlSimulatorConfig.eyesClosed,
                              onChanged: (v) => setState(() => MlSimulatorConfig.eyesClosed = v),
                            ),
                            _DevToggle(
                              label: 'Looking Away',
                              value: MlSimulatorConfig.lookingAway,
                              onChanged: (v) => setState(() => MlSimulatorConfig.lookingAway = v),
                            ),
                            _DevToggle(
                              label: 'Phone Present',
                              value: MlSimulatorConfig.phonePresent,
                              onChanged: (v) => setState(() => MlSimulatorConfig.phonePresent = v),
                            ),
                            _DevToggle(
                              label: 'Book Present',
                              value: MlSimulatorConfig.bookPresent,
                              onChanged: (v) => setState(() => MlSimulatorConfig.bookPresent = v),
                            ),
                            _DevToggle(
                              label: 'Laptop Present',
                              value: MlSimulatorConfig.laptopPresent,
                              onChanged: (v) => setState(() => MlSimulatorConfig.laptopPresent = v),
                            ),
                            _DevToggle(
                              label: 'Leave Chair',
                              value: MlSimulatorConfig.leavingChair,
                              onChanged: (v) => setState(() => MlSimulatorConfig.leavingChair = v),
                            ),
                            _DevToggle(
                              label: 'Slouching',
                              value: MlSimulatorConfig.slouching,
                              onChanged: (v) => setState(() => MlSimulatorConfig.slouching = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 16,
                    top: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: Colors.black87,
                      foregroundColor: gold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.settings_suggest_rounded, size: 20),
                      onPressed: () => setState(() => _showDevPanel = true),
                    ),
                  ),

                // ── Status Message HUD at Top Center ─────────────────────
                Positioned(
                  top: 16,
                  left: 200,
                  right: 110,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      studyState.statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isFocused ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // ── Bottom-left: End session ────────────────────────────
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _EndButton(
                    onEnd: () async {
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('End session?'),
                          content: const Text(
                              'Are you sure you want to end this study session?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Continue')),
                            FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('End')),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await ref.read(studyControllerProvider.notifier).stopSession();
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── ML Overlay Painter (computes facial meshes + joint lines + box trackers)
class _MlOverlayPainter extends CustomPainter {
  _MlOverlayPainter({required this.metrics});

  final FocusMetrics? metrics;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics == null) return;

    final paintFace = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    final paintLine = Paint()
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 1. Draw Simulated Face Mesh (478 pts circle projected visually)
    if (metrics!.faceDetected && !metrics!.leavingChair) {
      for (int i = 0; i < 40; i++) {
        final double angle = (i / 40) * 2 * math.pi;
        final double rx = size.width * 0.5 + size.width * 0.15 * math.cos(angle);
        final double ry = size.height * 0.35 + size.height * 0.12 * math.sin(angle);
        canvas.drawCircle(Offset(rx, ry), 2.5, paintFace);
      }
      // Nose
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.35), 4.0, Paint()..color = Colors.red);
      // Eyes
      final leftEyeOpen = metrics!.eyesOpen;
      canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.32), leftEyeOpen ? 5.0 : 2.0, Paint()..color = Colors.green);
      canvas.drawCircle(Offset(size.width * 0.56, size.height * 0.32), leftEyeOpen ? 5.0 : 2.0, Paint()..color = Colors.green);
    }

    // 2. Draw Posture Tracker Keypoint Skeleton Lines
    if (metrics!.faceDetected && !metrics!.leavingChair) {
      final nose = Offset(size.width * 0.5, size.height * 0.35);
      // If slouching, lower shoulders significantly
      final double shoulderY = metrics!.slouching ? size.height * 0.62 : size.height * 0.54;
      final leftShoulder = Offset(size.width * 0.35, shoulderY);
      final rightShoulder = Offset(size.width * 0.65, shoulderY);

      canvas.drawLine(nose, leftShoulder, paintLine);
      canvas.drawLine(nose, rightShoulder, paintLine);
      canvas.drawLine(leftShoulder, rightShoulder, paintLine);
    }

    // 3. Draw YOLOv8 Object Bounding Boxes
    if (metrics!.phoneDetected) {
      _drawBoundingBox(canvas, size, 0.68, 0.48, 0.18, 0.28, "Cell Phone", Colors.red, textPainter);
    }
    if (metrics!.bookDetected) {
      _drawBoundingBox(canvas, size, 0.3, 0.68, 0.4, 0.2, "Book", Colors.blue, textPainter);
    }
    if (metrics!.laptopDetected) {
      _drawBoundingBox(canvas, size, 0.2, 0.45, 0.6, 0.35, "Laptop", Colors.green, textPainter);
    }
    if (metrics!.leavingChair) {
      _drawBoundingBox(canvas, size, 0.15, 0.25, 0.7, 0.65, "Empty Chair", Colors.amber, textPainter);
    }
  }

  void _drawBoundingBox(
    Canvas canvas,
    Size size,
    double rx,
    double ry,
    double rw,
    double rh,
    String label,
    Color color,
    TextPainter textPainter,
  ) {
    final rect = Rect.fromLTWH(
      size.width * rx,
      size.height * ry,
      size.width * rw,
      size.height * rh,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    textPainter.text = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white,
        backgroundColor: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width * rx + 4, size.height * ry + 4));
  }

  @override
  bool shouldRepaint(covariant _MlOverlayPainter oldDelegate) => true;
}

// ── Developer Toggle Switch
class _DevToggle extends StatelessWidget {
  const _DevToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          SizedBox(
            height: 20,
            width: 32,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFD4AF37),
              activeTrackColor: Colors.amber.withOpacity(0.3),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD overlay (top-right)
// ─────────────────────────────────────────────────────────────────────────────
class _HudOverlay extends StatelessWidget {
  const _HudOverlay({
    required this.time,
    required this.focusPct,
    required this.credits,
  });

  final String time;
  final int focusPct;
  final int credits;

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFD4AF37);
    const Color silver = Color(0xFFC0C0C0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(time,
              style: const TextStyle(
                  color: gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Courier')),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.remove_red_eye, size: 13, color: silver),
            const SizedBox(width: 4),
            Text('$focusPct%',
                style: const TextStyle(
                    color: silver, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monetization_on, size: 13, color: gold),
            const SizedBox(width: 4),
            Text('$credits credits',
                style: const TextStyle(
                    color: gold, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎧 FAB
// ─────────────────────────────────────────────────────────────────────────────
class _AudioFab extends StatelessWidget {
  const _AudioFab({required this.audioService, required this.onTap});

  final FocusAudioService audioService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFD4AF37);
    final bool active = audioService.mode != AudioMode.off;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? gold : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? gold : Colors.white.withValues(alpha: 0.3), width: 1.5),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Icon(Icons.headphones_rounded,
            color: active ? Colors.black : Colors.white, size: 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Panel (glass card)
// ─────────────────────────────────────────────────────────────────────────────
class _AudioPanel extends StatefulWidget {
  const _AudioPanel({required this.audioService, required this.onChanged});

  final FocusAudioService audioService;
  final VoidCallback onChanged;

  @override
  State<_AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<_AudioPanel> {
  FocusAudioService get _svc => widget.audioService;

  Future<void> _pickMusic() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      await _svc.setMusicPath(result.files.single.path!);
      await _svc.setMode(AudioMode.music);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFD4AF37);
    const Color cardBg = Color(0xFF111111);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(children: [
                const Icon(Icons.music_note_rounded, color: gold, size: 18),
                const SizedBox(width: 6),
                const Text('Focus Audio',
                    style: TextStyle(
                        color: gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                // Play / pause toggle
                GestureDetector(
                  onTap: () async {
                    if (_svc.mode == AudioMode.off) return;
                    if (_svc.isPlaying) {
                      await _svc.pause();
                    } else {
                      await _svc.play();
                    }
                    setState(() {});
                    widget.onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _svc.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: gold,
                      size: 20,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 14),

              // ── Mode selector ──────────────────────────────────────────
              const Text('Mode',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _ModeChip(
                  label: 'Off',
                  icon: Icons.volume_off_rounded,
                  active: _svc.mode == AudioMode.off,
                  onTap: () async {
                    await _svc.setMode(AudioMode.off);
                    setState(() {});
                    widget.onChanged();
                  },
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  label: 'Sounds',
                  icon: Icons.waves_rounded,
                  active: _svc.mode == AudioMode.focusSound,
                  onTap: () async {
                    await _svc.setMode(AudioMode.focusSound);
                    setState(() {});
                    widget.onChanged();
                  },
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  label: 'Music',
                  icon: Icons.library_music_rounded,
                  active: _svc.mode == AudioMode.music,
                  onTap: () async {
                    if (_svc.musicPath != null) {
                      await _svc.setMode(AudioMode.music);
                      setState(() {});
                      widget.onChanged();
                    } else {
                      await _pickMusic();
                      setState(() {});
                    }
                  },
                ),
              ]),

              // ── Focus sound selector ───────────────────────────────────
              if (_svc.mode == AudioMode.focusSound) ...[
                const SizedBox(height: 14),
                const Text('Sound',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Column(
                  children: FocusSound.values.map((sound) {
                    final bool sel = _svc.focusSound == sound;
                    return GestureDetector(
                      onTap: () async {
                        await _svc.setFocusSound(sound);
                        setState(() {});
                        widget.onChanged();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? gold.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel
                                  ? gold.withValues(alpha: 0.6)
                                  : Colors.transparent),
                        ),
                        child: Row(children: [
                          Text(sound.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(sound.label,
                              style: TextStyle(
                                  color: sel ? gold : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                          if (sel) ...[
                            const Spacer(),
                            const Icon(Icons.check_circle_rounded,
                                color: gold, size: 16),
                          ],
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // ── Music file picker ──────────────────────────────────────
              if (_svc.mode == AudioMode.music) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickMusic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.folder_open_rounded,
                          color: gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _svc.musicPath != null
                              ? _svc.musicPath!.split('/').last
                              : 'Pick a music file',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],

              // ── Volume slider ──────────────────────────────────────────
              if (_svc.mode != AudioMode.off) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.volume_down_rounded,
                      color: Colors.white38, size: 16),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: gold,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: gold,
                        overlayColor: gold.withValues(alpha: 0.15),
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: _svc.volume,
                        min: 0,
                        max: 1,
                        onChanged: (v) async {
                          await _svc.setVolume(v);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded,
                      color: Colors.white38, size: 16),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode chip
// ─────────────────────────────────────────────────────────────────────────────
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFD4AF37);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? gold.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? gold.withValues(alpha: 0.8) : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? gold : Colors.white54, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: active ? gold : Colors.white54,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// End session button
// ─────────────────────────────────────────────────────────────────────────────
class _EndButton extends StatelessWidget {
  const _EndButton({required this.onEnd});
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEnd,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.stop_rounded, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text('End',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-session panel
// ─────────────────────────────────────────────────────────────────────────────
class _PreSessionPanel extends StatelessWidget {
  const _PreSessionPanel({
    required this.state,
    required this.minutesNotifier,
    required this.onStartSession,
  });

  final StudyState state;
  final ValueNotifier<int> minutesNotifier;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFD4AF37);
    const Color cardBg = Color(0xFF1A1A1A);
    const Color silver = Color(0xFFC0C0C0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: cardBg,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Smart Study Mode',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: gold, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                ValueListenableBuilder<int>(
                  valueListenable: minutesNotifier,
                  builder: (_, value, __) => Column(children: [
                    Text('$value minutes',
                        style: const TextStyle(
                            color: gold,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Slider(
                      min: AppConstants.minimumStudyMinutes.toDouble(),
                      max: AppConstants.maximumStudyMinutes.toDouble(),
                      divisions: (AppConstants.maximumStudyMinutes -
                              AppConstants.minimumStudyMinutes) ~/
                          5,
                      value: value.toDouble(),
                      label: '$value min',
                      onChanged: (v) => minutesNotifier.value = v.round(),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                const Text(
                  '🎧 You can control audio during the session',
                  style: TextStyle(color: silver, fontSize: 12),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onStartSession,
                    style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Study Session', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
