import '../../core/models/redemption_request.dart';
import '../../core/models/wallet_transaction.dart';
import '../../core/models/study_session_summary.dart';

abstract class WalletRepository {
  Future<double> getCredits();
  Future<int> getTodayStudySeconds();
  Future<List<RedemptionRequest>> getRedemptions();
  Future<List<WalletTransaction>> getTransactions();
  
  Future<void> commitStudySummary(StudySessionSummary summary);
  Future<void> saveRedemption(RedemptionRequest redemption);
  Future<void> updateRedemptionStatus(String id, RedemptionStatus status);
  Future<void> deductCredits(double credits);
  Future<void> resetWallet();
}
