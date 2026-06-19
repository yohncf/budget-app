import '../core/utils.dart';

class AccountSnapshot {
  final String id;
  final String accountId;
  final DateTime snapshotDate;
  final double balance;
  final String currency;
  final DateTime createdAt;

  AccountSnapshot({
    required this.id,
    required this.accountId,
    required this.snapshotDate,
    required this.balance,
    required this.currency,
    required this.createdAt,
  });

  factory AccountSnapshot.fromJson(Map<String, dynamic> json) {
    return AccountSnapshot(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      snapshotDate: parseDateTime(json['snapshot_date']),
      balance: (json['balance'] ?? 0.0).toDouble(),
      currency: json['currency'] as String,
      createdAt: parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'snapshot_date': snapshotDate.toIso8601String().split('T')[0],
      'balance': balance,
      'currency': currency,
      'created_at': createdAt,
    };
  }
}
