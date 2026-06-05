import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/payout_method.dart';
import '../../../core/models/redemption_request.dart';
import '../../../core/models/study_session_summary.dart';
import '../../../core/models/wallet_transaction.dart';
import '../../../core/services/app_storage_service.dart';
import '../../../core/services/razorpay_payout_service.dart';

class WalletViewModel extends ChangeNotifier {
  WalletViewModel(this._storage);

  final AppStorageService _storage;
  final RazorpayPayoutService _razorpayService = RazorpayPayoutService();

  double _credits = 0.0;
  int _todayStudySeconds = 0;
  List<RedemptionRequest> _redemptions = <RedemptionRequest>[];
  final List<WalletTransaction> _transactions = <WalletTransaction>[];
  bool _isLoading = true;

  // ── Getters ──────────────────────────────────────────────────────────────

  double get credits => _credits;
  int get todayStudySeconds => _todayStudySeconds;
  List<RedemptionRequest> get redemptions =>
      List<RedemptionRequest>.unmodifiable(_redemptions);
  List<WalletTransaction> get transactions =>
      List<WalletTransaction>.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  bool canRedeem(double credits) => _credits >= credits;

  double get dailyProgress {
    final int goalSeconds = AppConstants.dailyGoalMinutes * 60;
    if (goalSeconds == 0) return 0;
    return (_todayStudySeconds / goalSeconds).clamp(0.0, 1.0);
  }

  /// Balance in INR (1 credit = ₹0.10)
  double get balanceInr => _credits * 0.10;

  /// Credits earned today (derived from todayStudySeconds via credit calculator)
  double get todayEarnings {
    // Rough estimate: 1 credit per focused minute
    return (_todayStudySeconds / 60.0).clamp(0.0, double.infinity);
  }

  /// Credits earned this week (sum of completed + processing debit transactions this week)
  double get weeklyEarnings {
    final DateTime weekStart =
        DateTime.now().subtract(const Duration(days: 7));
    return _transactions
        .where((t) =>
            t.type == TransactionType.credit && t.date.isAfter(weekStart))
        .fold(0.0, (sum, t) => sum + t.credits);
  }

  /// Total credits withdrawn (completed debits)
  double get totalWithdrawn {
    return _redemptions
        .where((r) => r.status == RedemptionStatus.completed)
        .fold(0.0, (sum, r) => sum + r.cashValue);
  }

  /// Count of pending/processing withdrawals
  int get pendingWithdrawals {
    return _redemptions
        .where((r) =>
            r.status == RedemptionStatus.pending ||
            r.status == RedemptionStatus.processing)
        .length;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> loadWallet() async {
    _credits = _storage.readCredits();
    _todayStudySeconds = _storage.readTodayStudySeconds();
    _redemptions = _storage.readRedemptions();
    _buildTransactionsFromRedemptions();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> commitStudySummary(StudySessionSummary summary) async {
    if (summary.invalidated) return;

    _credits = await _storage.addCredits(summary.earnedCredits);
    _todayStudySeconds =
        await _storage.addTodayStudySeconds(summary.focusedSeconds);

    // Record a credit transaction
    _transactions.insert(
      0,
      WalletTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: TransactionType.credit,
        amountInr: summary.earnedCredits * 0.10,
        credits: summary.earnedCredits,
        date: DateTime.now(),
        status: TransactionStatus.completed,
        description: 'Study session earnings',
        transactionId: 'SE${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    notifyListeners();
  }

  Future<void> resetWallet() async {
    await _storage.resetWallet();
    _credits = 0.0;
    _todayStudySeconds = 0;
    _redemptions = <RedemptionRequest>[];
    _transactions.clear();
    notifyListeners();
  }

  // ── Redemption (legacy credits flow) ─────────────────────────────────────

  Future<RedemptionRequest> createRedemption({
    required double credits,
    required PayoutMethod method,
    required String destination,
  }) async {
    if (credits <= 0) throw StateError('Amount must be greater than zero');
    if (!canRedeem(credits)) throw StateError('Insufficient credits');

    final double cashValue =
        double.parse((credits / 10.0).toStringAsFixed(2));
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

    _credits = await _storage.subtractCredits(credits);
    _redemptions = <RedemptionRequest>[request, ..._redemptions];
    await _storage.saveRedemptions(_redemptions);
    _buildTransactionsFromRedemptions();
    notifyListeners();
    return request;
  }

  Future<void> updateRedemptionStatus(
      String id, RedemptionStatus status) async {
    final int idx =
        _redemptions.indexWhere((RedemptionRequest r) => r.id == id);
    if (idx == -1) return;
    final RedemptionRequest changed = _redemptions[idx].copyWith(status: status);
    _redemptions = List<RedemptionRequest>.from(_redemptions);
    _redemptions[idx] = changed;
    await _storage.saveRedemptions(_redemptions);
    _buildTransactionsFromRedemptions();
    notifyListeners();
  }

  // ── Bank Withdrawal (Razorpay flow) ──────────────────────────────────────

  /// Verify bank account via Razorpay Fund Account Validation.
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

  /// Initiate a bank withdrawal via Razorpay Payout API.
  Future<PayoutResult> withdraw({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
    required double amountInr,
  }) async {
    final double creditsNeeded = amountInr / 0.10;
    if (!canRedeem(creditsNeeded)) {
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
      narration: 'StudyEarn Payout',
    );

    if (result.success) {
      // Deduct credits and record transaction
      _credits = await _storage.subtractCredits(creditsNeeded);

      final WalletTransaction tx = WalletTransaction(
        id: result.payoutId,
        type: TransactionType.debit,
        amountInr: amountInr,
        credits: creditsNeeded,
        date: DateTime.now(),
        status: TransactionStatus.processing,
        description: 'Withdrawal to $bankName ••••${accountNumber.length > 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber}',
        transactionId: result.transactionId,
      );

      _transactions.insert(0, tx);

      // Also create a redemption record for history
      final RedemptionRequest req = RedemptionRequest(
        id: result.payoutId,
        credits: creditsNeeded,
        cashValue: amountInr,
        method: upiId != null ? PayoutMethod.upi : PayoutMethod.upi,
        destination: upiId ?? accountNumber,
        status: RedemptionStatus.processing,
        createdAt: DateTime.now(),
        estimatedPayoutAt:
            result.estimatedSettlement ?? DateTime.now().add(const Duration(hours: 24)),
      );
      _redemptions = <RedemptionRequest>[req, ..._redemptions];
      await _storage.saveRedemptions(_redemptions);

      notifyListeners();
    }

    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _buildTransactionsFromRedemptions() {
    _transactions.clear();
    for (final RedemptionRequest r in _redemptions) {
      _transactions.add(WalletTransaction(
        id: r.id,
        type: TransactionType.debit,
        amountInr: r.cashValue,
        credits: r.credits,
        date: r.createdAt,
        status: _mapStatus(r.status),
        description: 'Withdrawal via ${r.method.label}',
        transactionId: 'TXN${r.id.substring(r.id.length > 8 ? r.id.length - 8 : 0)}',
      ));
    }
  }

  TransactionStatus _mapStatus(RedemptionStatus s) {
    switch (s) {
      case RedemptionStatus.completed:
        return TransactionStatus.completed;
      case RedemptionStatus.pending:
        return TransactionStatus.pending;
      case RedemptionStatus.processing:
        return TransactionStatus.processing;
      case RedemptionStatus.rejected:
        return TransactionStatus.failed;
    }
  }
}