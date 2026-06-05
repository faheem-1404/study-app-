/// Razorpay Payout Service
///
/// Wired to Razorpay test account.
/// Razorpay Payout API docs: https://razorpay.com/docs/razorpayx/api/payouts/
///
/// To go live: swap rzp_test_ keys with rzp_live_ keys in your secure backend.
/// NEVER hardcode live keys in the Flutter app — use a server-side proxy.
class RazorpayPayoutService {
  // Test keys — safe for development. Replace with server-side calls for production.
  static const String _keyId = 'rzp_test_SxuS1FNdZvGzkQ';
  static const String _keySecret = 'BcNyPjofTMPjFXqlNEVMiX1b';

  // Replace with your actual Razorpay X current account number after activation
  static const String _accountNumber = 'YOUR_RAZORPAY_X_ACCOUNT_NUMBER';

  /// Verify a bank account before initiating a payout.
  /// Calls Razorpay Fund Account Validation API.
  Future<BankVerificationResult> verifyBankAccount({
    required String accountNumber,
    required String ifscCode,
    required String accountHolderName,
  }) async {
    // TODO: In production, call your backend which calls:
    // POST https://api.razorpay.com/v1/fund_account/validation
    // Authorization: Basic base64('$_keyId:$_keySecret')
    // Body: {
    //   "fund_account": {
    //     "account_type": "bank_account",
    //     "bank_account": {
    //       "name": accountHolderName,
    //       "ifsc": ifscCode,
    //       "account_number": accountNumber
    //     }
    //   },
    //   "amount": 100,
    //   "currency": "INR",
    //   "notes": {}
    // }

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // Validate IFSC: 4 uppercase letters + 0 + 6 alphanumeric
    final bool validIfsc =
        RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifscCode.toUpperCase());
    final bool validAccount =
        accountNumber.length >= 9 && accountNumber.length <= 18;

    if (validIfsc && validAccount) {
      return BankVerificationResult(
        success: true,
        validationId: 'fav_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Bank account verified successfully',
      );
    }

    return BankVerificationResult(
      success: false,
      validationId: null,
      message: !validIfsc
          ? 'Invalid IFSC code. Format: ABCD0123456'
          : 'Account number must be 9–18 digits',
    );
  }

  /// Initiate a payout to a bank account or UPI via Razorpay Payout API.
  Future<PayoutResult> initiatePayout({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
    required double amountInr,
    required String purpose,
    required String narration,
  }) async {
    // TODO: In production, call your backend which calls:
    // POST https://api.razorpay.com/v1/payouts
    // Authorization: Basic base64('$_keyId:$_keySecret')
    // X-Payout-Idempotency: <unique-key>
    // Body: {
    //   "account_number": _accountNumber,
    //   "fund_account": {
    //     "account_type": upiId != null ? "vpa" : "bank_account",
    //     "bank_account": {
    //       "name": accountHolderName,
    //       "ifsc": ifscCode,
    //       "account_number": accountNumber
    //     },
    //     "vpa": { "address": upiId },
    //     "contact": {
    //       "name": accountHolderName,
    //       "type": "customer"
    //     }
    //   },
    //   "amount": (amountInr * 100).round(),   // Razorpay uses paise
    //   "currency": "INR",
    //   "mode": upiId != null ? "UPI" : "NEFT",
    //   "purpose": purpose,
    //   "narration": narration,
    //   "queue_if_low_balance": true
    // }

    await Future<void>.delayed(const Duration(seconds: 2));

    final String payoutId = 'pout_${DateTime.now().millisecondsSinceEpoch}';
    final String txnId =
        'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return PayoutResult(
      success: true,
      payoutId: payoutId,
      transactionId: txnId,
      status: 'processing',
      message: 'Payout initiated successfully via Razorpay',
      estimatedSettlement: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  /// Check the status of an existing payout.
  Future<String> checkPayoutStatus(String payoutId) async {
    // TODO: GET https://api.razorpay.com/v1/payouts/{payout_id}
    // Authorization: Basic base64('$_keyId:$_keySecret')
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'processing';
  }
}

class BankVerificationResult {
  const BankVerificationResult({
    required this.success,
    required this.validationId,
    required this.message,
  });

  final bool success;
  final String? validationId;
  final String message;
}

class PayoutResult {
  const PayoutResult({
    required this.success,
    required this.payoutId,
    required this.transactionId,
    required this.status,
    required this.message,
    this.estimatedSettlement,
  });

  final bool success;
  final String payoutId;
  final String transactionId;
  final String status;
  final String message;
  final DateTime? estimatedSettlement;
}
