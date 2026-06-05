import 'dart:convert';

enum TransactionType { credit, debit }

enum TransactionStatus { completed, pending, processing, failed }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amountInr,
    required this.credits,
    required this.date,
    required this.status,
    required this.description,
    required this.transactionId,
  });

  final String id;
  final TransactionType type;
  final double amountInr;
  final double credits;
  final DateTime date;
  final TransactionStatus status;
  final String description;
  final String transactionId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'amountInr': amountInr,
        'credits': credits,
        'date': date.toIso8601String(),
        'status': status.name,
        'description': description,
        'transactionId': transactionId,
      };

  String toJson() => jsonEncode(toMap());

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id']?.toString() ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.credit,
      ),
      amountInr: (map['amountInr'] as num?)?.toDouble() ?? 0,
      credits: (map['credits'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.pending,
      ),
      description: map['description']?.toString() ?? '',
      transactionId: map['transactionId']?.toString() ?? '',
    );
  }

  factory WalletTransaction.fromJson(String source) =>
      WalletTransaction.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
