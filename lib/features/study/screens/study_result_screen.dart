import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/study_session_summary.dart';
import '../../../features/shared/widgets/metric_card.dart';
import '../../home/screens/home_screen.dart';
import '../../wallet/viewmodels/wallet_view_model.dart';

class StudyResultScreen extends StatefulWidget {
  const StudyResultScreen({super.key, required this.summary});

  final StudySessionSummary summary;

  @override
  State<StudyResultScreen> createState() => _StudyResultScreenState();
}

class _StudyResultScreenState extends State<StudyResultScreen> {
  bool _committedWallet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_committedWallet) {
      return;
    }

    _committedWallet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<WalletViewModel>().commitStudySummary(widget.summary);
    });
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final StudySessionSummary summary = widget.summary;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Result')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      summary.invalidated
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: summary.invalidated
                          ? colorScheme.error
                          : colorScheme.primary,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      summary.invalidated ? 'Session invalidated' : 'Study session complete',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      summary.invalidated ? '0.0 credits earned' : '+${summary.earnedCredits.toStringAsFixed(1)} credits',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: summary.invalidated
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    title: 'Focused time',
                    value: _formatDuration(summary.focusedSeconds),
                    subtitle: 'Counts toward credits',
                    icon: Icons.timer_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Paused time',
                    value: _formatDuration(summary.pausedSeconds),
                    subtitle: 'Timer was paused',
                    icon: Icons.pause_circle_outline_rounded,
                    accentColor: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: MetricCard(
                    title: 'Face missing',
                    value: '${summary.absentSeconds}s',
                    subtitle: 'Anti-cheat monitor',
                    icon: Icons.visibility_off_rounded,
                    accentColor: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Planned',
                    value: _formatDuration(summary.plannedSeconds),
                    subtitle: 'Selected duration',
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Reward formula',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Credits = focused time x multiplier. Focus mode adds a small bonus to reward consistent study sessions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const HomeScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}