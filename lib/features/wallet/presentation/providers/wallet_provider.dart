import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/payout_method.dart';
import '../../../../core/models/redemption_request.dart';
import '../../../../core/models/study_session_summary.dart';
import '../../../../core/models/wallet_transaction.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/razorpay_payout_service.dart';
import '../../../../domain/repositories/wallet_repository.dart';

class WalletState {
  const WalletState({
    this.credits = 0.0,
    this.todayStudySeconds = 0,
    this.redemptions = const [],
    this.transactions = const [],
    this.isLoading = true,
  });

  final double credits;
  final int todayStudySeconds;
  final List<RedemptionRequest> redemptions;
  final List<WalletTransaction> transactions;
  final bool isLoading;

  double get balanceInr => credits * 0.10;

  double get todayEarnings {
    return (todayStudySeconds / 60.0).clamp(0.0, double.infinity);
  }

  double get weeklyEarnings {
    final DateTime weekStart = DateTime.now().subtract(const Duration(days: 7));
    return transactions
        .where((t) =>
            t.type == TransactionType.credit && t.date.isAfter(weekStart))
        .fold(0.0, (sum, t) => sum + t.credits);
  }

  double get totalWithdrawn {
    return redemptions
        .where((r) => r.status == RedemptionStatus.completed)
        .fold(0.0, (sum, r) => sum + r.cashValue);
  }

  int get pendingWithdrawals {
    return redemptions
        .where((r) =>
            r.status == RedemptionStatus.pending ||
            r.status == RedemptionStatus.processing)
        .length;
  }

  double get dailyProgress {
    const int goalSeconds = 45 * 60; // 45 minutes daily goal
    return (todayStudySeconds / goalSeconds).clamp(0.0, 1.0);
  }

  WalletState copyWith({
    double? credits,
    int? todayStudySeconds,
    List<RedemptionRequest>? redemptions,
    List<WalletTransaction>? transactions,
    bool? isLoading,
  }) {
    return WalletState(
      credits: credits ?? this.credits,
      todayStudySeconds: todayStudySeconds ?? this.todayStudySeconds,
      redemptions: redemptions ?? this.redemptions,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalletController extends StateNotifier<WalletState> {
  WalletController(this._repository) : super(const WalletState()) {
    loadWallet();
  }

  final WalletRepository _repository;
  final RazorpayPayoutService _razorpayService = RazorpayPayoutService();

  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true);
    final credits = await _repository.getCredits();
    final todayStudySeconds = await _repository.getTodayStudySeconds();
    final redemptions = await _repository.getRedemptions();
    final transactions = await _repository.getTransactions();
    
    state = WalletState(
      credits: credits,
      todayStudySeconds: todayStudySeconds,
      redemptions: redemptions,
      transactions: transactions,
      isLoading: false,
    );
  }

  Future<void> commitStudySummary(StudySessionSummary summary) async {
    if (summary.invalidated) return;
    await _repository.commitStudySummary(summary);
    await loadWallet();
  }

  Future<void> resetWallet() async {
    await _repository.resetWallet();
    await loadWallet();
  }

  Future<BankVerificationResult> verifyBankAccount({
    required String accountNumber,
    required String ifscCode,
    required String accountHolderName,
  }) {
    return _razorpayService.verifyBankAccount(
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      accountHolderName: accountHolderName,
    );
  }

  Future<PayoutResult> withdraw({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
    required double amountInr,
  }) async {
    final double creditsNeeded = amountInr / 0.10;
    if (state.credits < creditsNeeded) {
      throw StateError('Insufficient balance for this withdrawal');
    }

    final PayoutResult result = await _razorpayService.initiatePayout(
      accountHolderName: accountHolderName,
      bankName: bankName,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      upiId: upiId,
      amountInr: amountInr,
      purpose: 'education',
      narration: 'StudyPay Payout',
    );

    if (result.success) {
      // Deduct credits in repository
      await _repository.deductCredits(creditsNeeded);

      // Save redemption record
      final RedemptionRequest req = RedemptionRequest(
        id: result.payoutId,
        credits: creditsNeeded,
        cashValue: amountInr,
        method: PayoutMethod.upi,
        destination: upiId ?? accountNumber,
        status: RedemptionStatus.processing,
        createdAt: DateTime.now(),
        estimatedPayoutAt:
            result.estimatedSettlement ?? DateTime.now().add(const Duration(hours: 24)),
      );
      
      await _repository.saveRedemption(req);
      await loadWallet();
    }

    return result;
  }

  Future<void> createRedemption({
    required double credits,
    required PayoutMethod method,
    required String destination,
  }) async {
    if (credits <= 0) throw StateError('Amount must be greater than zero');
    if (state.credits < credits) throw StateError('Insufficient credits');

    final double cashValue = double.parse((credits / 10.0).toStringAsFixed(2));
    final DateTime now = DateTime.now();
    final RedemptionRequest request = RedemptionRequest(
      id: now.microsecondsSinceEpoch.toString(),
      credits: credits,
      cashValue: cashValue,
      method: method,
      destination: destination,
      status: RedemptionStatus.processing,
      createdAt: now,
      estimatedPayoutAt: now.add(const Duration(hours: 24)),
    );

    await _repository.deductCredits(credits);
    await _repository.saveRedemption(request);
    await loadWallet();
  }

  Future<void> updateRedemptionStatus(String id, RedemptionStatus status) async {
    await _repository.updateRedemptionStatus(id, status);
    await loadWallet();
  }
}

/// Global WalletController Provider
final walletControllerProvider = StateNotifierProvider<WalletController, WalletState>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletController(repository);
});
