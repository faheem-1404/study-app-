enum PayoutMethod {
  upi,
  paypal,
  giftCard,
}

extension PayoutMethodLabel on PayoutMethod {
  String get label {
    switch (this) {
      case PayoutMethod.upi:
        return 'UPI transfer';
      case PayoutMethod.paypal:
        return 'PayPal';
      case PayoutMethod.giftCard:
        return 'Gift card';
    }
  }

  String get subtitle {
    switch (this) {
      case PayoutMethod.upi:
        return 'Mock bank-to-bank style payout';
      case PayoutMethod.paypal:
        return 'Mock wallet transfer';
      case PayoutMethod.giftCard:
        return 'Amazon or Play Store code';
    }
  }

  String get iconAsset {
    switch (this) {
      case PayoutMethod.upi:
        return 'upi';
      case PayoutMethod.paypal:
        return 'paypal';
      case PayoutMethod.giftCard:
        return 'giftcard';
    }
  }
}