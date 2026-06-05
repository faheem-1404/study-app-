import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/wallet_transaction.dart';
import '../viewmodels/wallet_view_model.dart';
import 'withdraw_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _cardAnim;
  late Animation<double> _cardFloat;
  late Animation<double> _cardFade;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _cardAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _cardFloat = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _cardAnim, curve: Curves.easeInOut),
    );

    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
          ..forward(),
        curve: Curves.easeOut,
      ),
    );

    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _cardAnim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cardAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF2F4F8),
      body: Consumer<WalletViewModel>(
        builder: (context, wallet, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 60,
                backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF2F4F8),
                foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
                elevation: 0,
                title: const Text(
                  'My Wallet',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history_rounded),
                    tooltip: 'Transaction history',
                    onPressed: () {},
                  ),
                ],
              ),

              // ── Animated Wallet Card ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: AnimatedBuilder(
                    animation: _cardAnim,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _cardFloat.value),
                        child: child,
                      );
                    },
                    child: _AnimatedWalletCard(
                      balanceInr: wallet.balanceInr,
                      credits: wallet.credits,
                      shimmerAnim: _shimmer,
                    ),
                  ),
                ),
              ),

              // ── Earnings Summary ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _EarningsSummaryRow(wallet: wallet),
                ),
              ),

              // ── Pending Banner ────────────────────────────────────────────
              if (wallet.pendingWithdrawals > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _PendingBanner(count: wallet.pendingWithdrawals),
                  ),
                ),

              // ── Transaction History ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      if (wallet.transactions.isNotEmpty)
                        Text(
                          '${wallet.transactions.length} total',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              if (wallet.transactions.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyTransactions(isDark: isDark),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = wallet.transactions[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          20, 0, 20, index == wallet.transactions.length - 1 ? 100 : 12,
                        ),
                        child: _TransactionTile(tx: tx, isDark: isDark),
                      );
                    },
                    childCount: wallet.transactions.length,
                  ),
                ),
            ],
          );
        },
      ),

      // ── Withdraw FAB ───────────────────────────────────────────────────
      floatingActionButton: Consumer<WalletViewModel>(
        builder: (context, wallet, _) => _WithdrawFab(
          enabled: wallet.balanceInr >= 1.0,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const WithdrawScreen(),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Wallet Card
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedWalletCard extends StatelessWidget {
  const _AnimatedWalletCard({
    required this.balanceInr,
    required this.credits,
    required this.shimmerAnim,
  });

  final double balanceInr;
  final double credits;
  final Animation<double> shimmerAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnim,
      builder: (context, child) {
        return Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment(shimmerAnim.value * 0.2 - 1, -0.5),
              end: Alignment(shimmerAnim.value * 0.2 + 1, 1.5),
              colors: const [
                Color(0xFF1A1A6E),
                Color(0xFF0E4D45),
                Color(0xFF145E6D),
                Color(0xFF0A3D55),
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E4D45).withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 5),
                              Text('StudyEarn',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.contactless_rounded,
                            color: Colors.white54, size: 28),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${balanceInr.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${credits.toStringAsFixed(1)} credits',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Earnings Summary Row
// ─────────────────────────────────────────────────────────────────────────────
class _EarningsSummaryRow extends StatelessWidget {
  const _EarningsSummaryRow({required this.wallet});
  final WalletViewModel wallet;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: "Today's Earnings",
            value: '${wallet.todayEarnings.toStringAsFixed(1)}',
            unit: 'cr',
            icon: Icons.today_rounded,
            color: const Color(0xFF4CAF50),
            cardBg: cardBg,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'This Week',
            value: '${wallet.weeklyEarnings.toStringAsFixed(1)}',
            unit: 'cr',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF2196F3),
            cardBg: cardBg,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Withdrawn',
            value: '₹${wallet.totalWithdrawn.toStringAsFixed(0)}',
            unit: '',
            icon: Icons.south_rounded,
            color: const Color(0xFFFF9800),
            cardBg: cardBg,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.isDark,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value + (unit.isNotEmpty ? ' $unit' : ''),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Withdrawals Banner
// ─────────────────────────────────────────────────────────────────────────────
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count withdrawal${count > 1 ? 's' : ''} pending settlement',
              style: const TextStyle(
                color: Color(0xFFFF9800),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const Text(
            '1-3 days',
            style: TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Tile
// ─────────────────────────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.isDark});

  final WalletTransaction tx;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bool isCredit = tx.type == TransactionType.credit;
    final Color cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final Color amountColor =
        isCredit ? const Color(0xFF4CAF50) : const Color(0xFFFF4C4C);

    Color statusColor;
    String statusLabel;
    switch (tx.status) {
      case TransactionStatus.completed:
        statusColor = const Color(0xFF4CAF50);
        statusLabel = 'Completed';
        break;
      case TransactionStatus.processing:
        statusColor = const Color(0xFF2196F3);
        statusLabel = 'Processing';
        break;
      case TransactionStatus.pending:
        statusColor = const Color(0xFFFF9800);
        statusLabel = 'Pending';
        break;
      case TransactionStatus.failed:
        statusColor = const Color(0xFFFF4C4C);
        statusLabel = 'Failed';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isCredit ? Icons.north_east_rounded : Icons.south_west_rounded,
                color: amountColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${tx.transactionId}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // Amount + Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₹${tx.amountInr.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 36,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete a study session to earn credits and see your transactions here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Withdraw FAB
// ─────────────────────────────────────────────────────────────────────────────
class _WithdrawFab extends StatelessWidget {
  const _WithdrawFab({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 56,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF0E4D45), Color(0xFF145E6D)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF0E4D45).withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_rounded,
                color: enabled ? Colors.white : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                enabled ? 'Withdraw Money' : 'Earn credits to withdraw',
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
