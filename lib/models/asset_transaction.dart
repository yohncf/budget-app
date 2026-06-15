class AssetTransaction {
  final String id;
  final String? transactionId; // Links to cash ledger transaction
  final String accountId;
  final String assetId;
  final String type; // buy, sell, dividend_reinvest, split, reward
  final double quantity;
  final double unitPrice;
  final DateTime executedAt;

  // Optional client-side fields for joins
  final String? assetSymbol;
  final String? assetName;

  AssetTransaction({
    required this.id,
    this.transactionId,
    required this.accountId,
    required this.assetId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.executedAt,
    this.assetSymbol,
    this.assetName,
  });

  factory AssetTransaction.fromJson(Map<String, dynamic> json) {
    return AssetTransaction(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      accountId: json['account_id'] as String,
      assetId: json['asset_id'] as String,
      type: json['type'] as String,
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      executedAt: json['executed_at'] != null ? DateTime.parse(json['executed_at']) : DateTime.now(),
      assetSymbol: json['asset_symbol'] as String?,
      assetName: json['asset_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'asset_id': assetId,
      'type': type,
      'quantity': quantity,
      'unit_price': unitPrice,
      'executed_at': executedAt.toIso8601String(),
    };
  }
}
