import '../core/utils.dart';

class Category {
  final String id;
  final String name;
  final String type; // income, expense, transfer, reimbursement, investment
  final String? parentId;
  final String? icon;
  final String colorHex;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.icon,
    this.colorHex = '#8B5CF6',
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      parentId: json['parent_id'] as String?,
      icon: json['icon'] as String?,
      colorHex: json['color_hex'] ?? '#8B5CF6',
      createdAt: parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'parent_id': parentId,
      'icon': icon,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
