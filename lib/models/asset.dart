class Asset {
  final String id;
  final String symbol;
  final String name;
  final String type; // crypto, stock, etf

  Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'type': type,
    };
  }
}
