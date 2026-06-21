import '../core/utils.dart';

class RecurringTransaction {
  final String id;
  final String accountId;
  final String categoryId;
  final double amount;
  final String frequency; // daily, weekly, biweekly, monthly, yearly
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final String status; // active, paused, completed
  final String description;

  RecurringTransaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.frequency,
    required this.interval,
    required this.startDate,
    this.endDate,
    required this.nextDueDate,
    required this.status,
    required this.description,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      categoryId: json['category_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      frequency: json['frequency'] as String,
      interval: json['interval'] as int? ?? 1,
      startDate: parseDateTime(json['start_date']),
      endDate: json['end_date'] != null ? parseDateTime(json['end_date']) : null,
      nextDueDate: parseDateTime(json['next_due_date']),
      status: json['status'] as String? ?? 'active',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'amount': amount,
      'frequency': frequency,
      'interval': interval,
      'start_date': startDate,
      'end_date': endDate,
      'next_due_date': nextDueDate,
      'status': status,
      'description': description,
    };
  }
}
