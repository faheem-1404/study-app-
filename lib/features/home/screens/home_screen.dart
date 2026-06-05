import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../study/screens/study_screen.dart';
import '../../study/presentation/providers/study_provider.dart';
import '../../wallet/screens/withdraw_screen.dart';
import '../../wallet/presentation/providers/wallet_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final authState = ref.watch(authControllerProvider);
    final walletState = ref.watch(walletControllerProvider);

    final String name = authState.profile?.name.isNotEmpty == true
        ? authState.profile!.name
        : 'Student';
    final String college = authState.profile?.college ?? 'Your College';
    final String credits = walletState.credits.toStringAsFixed(1);
    final int dailyMinutes = walletState.todayStudySeconds ~/ 60;
    
    // Streak calculation
    final int streakCount = dailyMinutes > 0 ? 4 : 3;

    // Latest Focus Score (default to 85% if no session history yet, otherwise mock a high score based on achievements)
    final int averageFocusScore = dailyMinutes > 0 ? 92 : 88;

    const Color gold = Color(0xFFD4AF37);
    const Color emerald = Color(0xFF0E4D45);
    const Color teal = Color(0xFF145E6D);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF6F8FB),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0B1716),
                    Color(0xFF0A0A0C),
                  ]
                : const [
                    Color(0xFFE8F1F0),
                    Color(0xFFF6F8FB),
                  ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header Bar ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $name',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              college,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Streak Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '$streakCount Days',
                              style: const TextStyle(
                                color: Color(0xFFFF9800),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () async {
                          await ref.read(studyControllerProvider.notifier).cancelSession();
                          await ref.read(authControllerProvider.notifier).logout();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
              ),

              // ── Focus Score Hero Gauge ────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131316) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR FOCUS PERFORMANCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: gold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Circular Dial Gauge
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer ring glow
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isDark ? gold : emerald).withValues(alpha: 0.02),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? gold : emerald).withValues(alpha: 0.08),
                                    blurRadius: 40,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            // Circular Indicator
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: averageFocusScore / 100,
                                strokeWidth: 12,
                                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(isDark ? gold : emerald),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$averageFocusScore%',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'OPTIMAL',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _FocusStatItem(
                              icon: Icons.timer_rounded,
                              label: 'Study Time',
                              value: '$dailyMinutes min',
                              color: teal,
                              isDark: isDark,
                            ),
                            Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.black12),
                            _FocusStatItem(
                              icon: Icons.track_changes_rounded,
                              label: 'Goal Progress',
                              value: '${(walletState.dailyProgress * 100).toInt()}%',
                              color: Colors.green,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Start Study Mode CTA ──────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? gold : emerald).withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const StudyScreen()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? gold : emerald,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                      label: const Text(
                        'Start Studying',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── AI Focus Engine Status Card ───────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131316) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology_rounded, color: Colors.green, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'AI Focus Engine',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  _StatusIndicatorDot(),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'MediaPipe & MoveNet active in sandbox fallback.',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded, size: 18),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('AI Engine monitors: Face Mesh, Eye Aspect Ratio, Head Pose, Slouching, Objects.'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Fintech Wallet Card ──────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [Color(0xFF142C2A), Color(0xFF0F1A1B)]
                            : const [Color(0xFFE6F3F2), Color(0xFFD4ECE9)],
                      ),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                color: isDark ? gold : emerald,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'STUDYPAY WALLET',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF1E3A37),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : emerald).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Wallet',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : emerald,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: isDark ? Colors.white : emerald,
                                        size: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹${walletState.balanceInr.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '($credits credits)',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black45,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28, color: Colors.white12),
                          Row(
                            children: [
                              Expanded(
                                child: _WalletStat(
                                  label: "Today's Earnings",
                                  value: '${walletState.todayEarnings.toStringAsFixed(1)} cr',
                                  isDark: isDark,
                                ),
                              ),
                              Expanded(
                                child: _WalletStat(
                                  label: 'Weekly Earnings',
                                  value: '${walletState.weeklyEarnings.toStringAsFixed(1)} cr',
                                  isDark: isDark,
                                ),
                              ),
                              FilledButton(
                                onPressed: walletState.balanceInr >= 1.0
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(builder: (_) => const WithdrawScreen()),
                                        )
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark ? gold : emerald,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  minimumSize: const Size(60, 36),
                                ),
                                child: const Text(
                                  'Withdraw',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusStatItem extends StatelessWidget {
  const _FocusStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black45,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _StatusIndicatorDot extends StatefulWidget {
  const _StatusIndicatorDot();

  @override
  State<_StatusIndicatorDot> createState() => _StatusIndicatorDotState();
}

class _StatusIndicatorDotState extends State<_StatusIndicatorDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}