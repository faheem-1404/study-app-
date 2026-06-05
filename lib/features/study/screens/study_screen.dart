import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/focus_sound.dart';
import '../../../core/models/study_session_summary.dart';
import '../../../core/services/focus_audio_service.dart';
import '../viewmodels/study_view_model.dart';
import 'study_result_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late final StudyViewModel _vm;
  bool _cameraPermissionGranted = false;
  bool _isPreparing = true;
  bool _isListenerAttached = false;
  bool _sessionStarted = false;
  bool _showAudioPanel = false;
  final ValueNotifier<int> _minutesNotifier =
      ValueNotifier<int>(AppConstants.defaultStudyMinutes);

  late AnimationController _panelAnim;
  late Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();
    _vm = context.read<StudyViewModel>();
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
    if (_isListenerAttached) _vm.removeListener(_handleStudyUpdate);
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
    if (!_isListenerAttached) {
      _vm.addListener(_handleStudyUpdate);
      _isListenerAttached = true;
    }
    try {
      await _vm.initializeCamera();
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  void _handleStudyUpdate() {
    final StudySessionSummary? summary = _vm.latestSummary;
    if (summary == null || !mounted) return;
    _vm.clearLatestSummary();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
          builder: (_) => StudyResultScreen(summary: summary)),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_vm.isSessionActive) return true;
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
              child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) await _vm.cancelSession();
    return false;
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _togglePanel() {
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: darkBg,
        body: Consumer<StudyViewModel>(
          builder: (context, vm, _) {
            if (_isPreparing) {
              return const Center(child: CircularProgressIndicator());
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
                vm: vm,
                minutesNotifier: _minutesNotifier,
                onStartSession: () async {
                  setState(() => _sessionStarted = true);
                  await vm.startSession(minutes: _minutesNotifier.value);
                },
              );
            }

            final CameraController? ctrl = vm.cameraController;
            final bool ready = ctrl != null && ctrl.value.isInitialized;

            if (!ready) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(vm.statusMessage,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        await vm.cancelSession();
                        if (mounted) setState(() => _sessionStarted = false);
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final bool isFocused = vm.focusScore > 60;

            return GestureDetector(
              onTap: () {
                if (_showAudioPanel) {
                  setState(() => _showAudioPanel = false);
                  _panelAnim.reverse();
                }
              },
              child: Stack(
                children: [
                  // ── Camera preview ──────────────────────────────────────
                  SizedBox.expand(child: CameraPreview(ctrl!)),

                  // ── Focus glow border ───────────────────────────────────
                  if (isFocused)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: green.withOpacity(0.35),
                              width: 2,
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
                      time: _fmt(vm.remainingSeconds),
                      focusPct: (vm.focusPercentage * 100).toInt(),
                      credits: vm.focusedSeconds ~/ 60,
                    ),
                  ),

                  // ── Bottom-right: 🎧 Audio button ───────────────────────
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: _AudioFab(
                      audioService: vm.audioService,
                      onTap: _togglePanel,
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
                          audioService: vm.audioService,
                          onChanged: () => setState(() {}),
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
                                  child: const Text('End')),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await vm.cancelSession();
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.3)),
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
          color: active ? gold : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? gold : Colors.white.withOpacity(0.3), width: 1.5),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: gold.withOpacity(0.4),
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
            color: cardBg.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(0.25), width: 1),
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
                      color: gold.withOpacity(0.15),
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
                              ? gold.withOpacity(0.18)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel
                                  ? gold.withOpacity(0.6)
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
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gold.withOpacity(0.3)),
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
                        overlayColor: gold.withOpacity(0.15),
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
          color: active ? gold.withOpacity(0.22) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? gold.withOpacity(0.8) : Colors.transparent),
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
          color: Colors.red.withOpacity(0.82),
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
    required this.vm,
    required this.minutesNotifier,
    required this.onStartSession,
  });

  final StudyViewModel vm;
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
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Study Session'),
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
