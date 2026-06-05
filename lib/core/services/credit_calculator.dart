import '../constants/app_constants.dart';

class CreditCalculator {
  static double calculateCredits({
    required int focusedSeconds,
    required bool focusModeEnabled,
  }) {
    final double focusedMinutes = focusedSeconds / 60.0;
    final double multiplier = focusModeEnabled
        ? AppConstants.focusModeMultiplier
        : 1.0;
    final double totalCredits =
        focusedMinutes * AppConstants.creditsPerMinute * multiplier;
    return double.parse(totalCredits.toStringAsFixed(1));
  }
}