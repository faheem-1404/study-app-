import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/redemption_request.dart';
import '../../../core/models/payout_method.dart';
import '../../../features/shared/widgets/metric_card.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../study/screens/study_screen.dart';
import '../../study/viewmodels/study_view_model.dart';
import '../../wallet/screens/redemption_screen.dart';
import '../../wallet/viewmodels/wallet_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.primary.withValues(alpha: 0.18),
              colorScheme.secondary.withValues(alpha: 0.12),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer2<AuthViewModel, WalletViewModel>(
            builder: (context, authViewModel, walletViewModel, _) {
              final String name = authViewModel.profile?.name.isNotEmpty == true
                  ? authViewModel.profile!.name
                  : 'Student';
              final String college = authViewModel.profile?.college ?? 'Your college';
              final String credits = walletViewModel.credits.toStringAsFixed(1);
              final int dailyMinutes = walletViewModel.todayStudySeconds ~/ 60;
              final int pendingRedemptions = walletViewModel.redemptions
                  .where((RedemptionRequest request) => request.status != RedemptionStatus.completed)
                  .length;

              return CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Welcome back, $name',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  college,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
                                },
                                icon: const Icon(Icons.account_balance_wallet_rounded),
                                tooltip: 'My Wallet',
                              ),
                              IconButton(
                                onPressed: () async {
                                  await context.read<StudyViewModel>().cancelSession();
                                  await context.read<AuthViewModel>().logout();
                                },
                                icon: const Icon(Icons.logout_rounded),
                                tooltip: 'Log out',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Earning dashboard',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '$credits credits',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Study minutes turn into redeemable credits.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: MetricCard(
                        title: 'Daily progress',
                        value: '$dailyMinutes / ${AppConstants.dailyGoalMinutes} min',
                        subtitle: 'Focused study time for today',
                        icon: Icons.track_changes_rounded,
                        accentColor: colorScheme.tertiary,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: walletViewModel.dailyProgress,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: MetricCard(
                              title: 'Today',
                              value: '$dailyMinutes min',
                              subtitle: 'Logged study time',
                              icon: Icons.schedule_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricCard(
                              title: 'Credits',
                              value: credits,
                              subtitle: 'Wallet balance',
                              icon: Icons.account_balance_wallet_rounded,
                              accentColor: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const StudyScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text('Start Study Mode'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RedemptionScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.verified_user_rounded),
                              label: const Text('Redeem'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Redemption lounge',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (pendingRedemptions > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '$pendingRedemptions pending',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                              color: colorScheme.secondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                walletViewModel.redemptions.isEmpty
                                    ? 'No payout requests yet. Redeem credits after a study session to create a mock payout record.'
                                    : 'Latest request: ${walletViewModel.redemptions.first.method.label} • ${walletViewModel.redemptions.first.credits.toStringAsFixed(0)} credits',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}