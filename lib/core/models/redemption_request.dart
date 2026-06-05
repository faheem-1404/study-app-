import 'dart:convert';

import 'payout_method.dart';

enum RedemptionStatus {
  pending,
  processing,
  completed,
  rejected,
}

class RedemptionRequest {
  const RedemptionRequest({
    required this.id,
    required this.credits,
    required this.cashValue,
    required this.method,
    required this.destination,
    required this.status,
    required this.createdAt,
    required this.estimatedPayoutAt,
  });

  final String id;
  final double credits;
  final double cashValue;
  final PayoutMethod method;
  final String destination;
  final RedemptionStatus status;
  final DateTime createdAt;
  final DateTime estimatedPayoutAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'credits': credits,
      'cashValue': cashValue,
      'method': method.name,
      'destination': destination,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'estimatedPayoutAt': estimatedPayoutAt.toIso8601String(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory RedemptionRequest.fromMap(Map<String, dynamic> map) {
    return RedemptionRequest(
      id: map['id']?.toString() ?? '',
      credits: (map['credits'] as num?)?.toDouble() ?? 0,
      cashValue: (map['cashValue'] as num?)?.toDouble() ?? 0,
      method: PayoutMethod.values.firstWhere(
        (PayoutMethod method) => method.name == map['method'],
        orElse: () => PayoutMethod.upi,
      ),
      destination: map['destination']?.toString() ?? '',
      status: RedemptionStatus.values.firstWhere(
        (RedemptionStatus status) => status.name == map['status'],
        orElse: () => RedemptionStatus.pending,
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      estimatedPayoutAt:
          DateTime.tryParse(map['estimatedPayoutAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory RedemptionRequest.fromJson(String source) {
    return RedemptionRequest.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  RedemptionRequest copyWith({RedemptionStatus? status}) {
    return RedemptionRequest(
      id: id,
      credits: credits,
      cashValue: cashValue,
      method: method,
      destination: destination,
      status: status ?? this.status,
      createdAt: createdAt,
      estimatedPayoutAt: estimatedPayoutAt,
    );
  }
}