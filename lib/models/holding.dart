import '../core/utils.dart';

class Holding {
  final String id;
  final String accountId;
  final String assetId;
  final double quantity;
  final double avgBuyPrice;
  final DateTime updatedAt;
  
  // Optional client-side fields for dereferencing/joining
  final String? assetSymbol;
  final String? assetName;

  Holding({
    required this.id,
    required this.accountId,
    required this.assetId,
    required this.quantity,
    required this.avgBuyPrice,
    required this.updatedAt,
    this.assetSymbol,
    this.assetName,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      assetId: json['asset_id'] as String,
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      avgBuyPrice: (json['avg_buy_price'] ?? 0.0).toDouble(),
      updatedAt: parseDateTime(json['updated_at']),
      assetSymbol: json['asset_symbol'] as String?,
      assetName: json['asset_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'asset_id': assetId,
      'quantity': quantity,
      'avg_buy_price': avgBuyPrice,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
