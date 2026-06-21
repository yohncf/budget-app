import '../core/utils.dart';

class BudgetTarget {
  final String id;
  final String categoryId;
  final double targetAmount;
  final String period; // monthly, quarterly, yearly
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  BudgetTarget({
    required this.id,
    required this.categoryId,
    required this.targetAmount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory BudgetTarget.fromJson(Map<String, dynamic> json) {
    return BudgetTarget(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      period: json['period'] as String,
      startDate: parseDateTime(json['start_date']),
      endDate: parseDateTime(json['end_date']),
      createdAt: parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'target_amount': targetAmount,
      'period': period,
      'start_date': startDate,
      'end_date': endDate,
      'created_at': createdAt,
    };
  }
}
