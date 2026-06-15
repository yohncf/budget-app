class Account {
  final String id;
  final String name;
  final String type; // checking, savings, credit_card, investment, crypto_wallet, retirement
  final String? institution;
  final String currency;
  final double currentBalance;
  final String status; // active, archived
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.institution,
    required this.currency,
    this.currentBalance = 0.0,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      institution: json['institution'] as String?,
      currency: json['currency'] as String,
      currentBalance: (json['current_balance'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'institution': institution,
      'currency': currency,
      'current_balance': currentBalance,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Account copyWith({
    String? name,
    String? type,
    String? institution,
    String? currency,
    double? currentBalance,
    String? status,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      institution: institution ?? this.institution,
      currency: currency ?? this.currency,
      currentBalance: currentBalance ?? this.currentBalance,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
