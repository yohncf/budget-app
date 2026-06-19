import '../core/utils.dart';

class Transaction {
  final String id;
  final String accountId;
  final String categoryId;
  final double amount; // negative for expense, positive for income/reimbursement
  final String currency;
  final double exchangeRate;
  final DateTime date;
  final String? description;
  final String status; // pending, cleared, flagged
  final bool isRecurring;
  final String? recurringId;
  final List<String> tags;
  final int? sheetsRowId; // Rule 1.1 tracking
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.currency,
    this.exchangeRate = 1.0,
    required this.date,
    this.description,
    this.status = 'cleared',
    this.isRecurring = false,
    this.recurringId,
    this.tags = const [],
    this.sheetsRowId,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    var tagsFromJson = json['tags'];
    List<String> tagsList = [];
    if (tagsFromJson != null) {
      if (tagsFromJson is List) {
        tagsList = tagsFromJson.map((e) => e.toString()).toList();
      } else if (tagsFromJson is String) {
        // Handle postgres array output format: {tag1,tag2}
        if (tagsFromJson.startsWith('{') && tagsFromJson.endsWith('}')) {
          tagsList = tagsFromJson.substring(1, tagsFromJson.length - 1).split(',').where((s) => s.isNotEmpty).toList();
        }
      }
    }

    return Transaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      categoryId: json['category_id'] as String,
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] as String,
      exchangeRate: (json['exchange_rate'] ?? 1.0).toDouble(),
      date: parseDateTime(json['date']),
      description: json['description'] as String?,
      status: json['status'] ?? 'cleared',
      isRecurring: json['is_recurring'] ?? false,
      recurringId: json['recurring_id'] as String?,
      tags: tagsList,
      sheetsRowId: json['sheets_row_id'] as int?,
      createdAt: parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'date': date,
      'description': description,
      'status': status,
      'is_recurring': isRecurring,
      'recurring_id': recurringId,
      'tags': tags,
      'sheets_row_id': sheetsRowId,
      'created_at': createdAt,
    };
  }

  Transaction copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    double? amount,
    String? currency,
    double? exchangeRate,
    DateTime? date,
    String? description,
    String? status,
    bool? isRecurring,
    String? recurringId,
    List<String>? tags,
    int? sheetsRowId,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      date: date ?? this.date,
      description: description ?? this.description,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
      tags: tags ?? this.tags,
      sheetsRowId: sheetsRowId ?? this.sheetsRowId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

