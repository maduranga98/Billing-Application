// lib/models/stock_item.dart
class StockItem {
  final String id;
  final String itemName;
  final String itemCode;
  final double unitPrice;
  final int currentQuantity;
  final int minQuantity;
  final String category;
  final String ownerId;
  final String businessId;
  final DateTime createdAt;
  final DateTime updatedAt;

  StockItem({
    required this.id,
    required this.itemName,
    required this.itemCode,
    required this.unitPrice,
    required this.currentQuantity,
    required this.minQuantity,
    required this.category,
    required this.ownerId,
    required this.businessId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockItem.fromFirestore(Map<String, dynamic> data, String id) {
    return StockItem(
      id: id,
      itemName: data['itemName'] ?? '',
      itemCode: data['itemCode'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      currentQuantity: data['currentQuantity'] ?? 0,
      minQuantity: data['minQuantity'] ?? 0,
      category: data['category'] ?? '',
      ownerId: data['ownerId'] ?? '',
      businessId: data['businessId'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  factory StockItem.fromSQLite(Map<String, dynamic> data) {
    return StockItem(
      id: data['id'],
      itemName: data['item_name'],
      itemCode: data['item_code'],
      unitPrice: data['unit_price'],
      currentQuantity: data['current_quantity'],
      minQuantity: data['min_quantity'],
      category: data['category'] ?? '',
      ownerId: data['owner_id'],
      businessId: data['business_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'itemCode': itemCode,
      'unitPrice': unitPrice,
      'currentQuantity': currentQuantity,
      'minQuantity': minQuantity,
      'category': category,
      'ownerId': ownerId,
      'businessId': businessId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'item_name': itemName,
      'item_code': itemCode,
      'unit_price': unitPrice,
      'current_quantity': currentQuantity,
      'min_quantity': minQuantity,
      'category': category,
      'owner_id': ownerId,
      'business_id': businessId,
      'sync_status': 'synced',
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Utility methods
  bool get isLowStock => currentQuantity <= minQuantity;
  bool get isOutOfStock => currentQuantity <= 0;

  double get totalValue => currentQuantity * unitPrice;

  StockItem copyWith({
    String? id,
    String? itemName,
    String? itemCode,
    double? unitPrice,
    int? currentQuantity,
    int? minQuantity,
    String? category,
    String? ownerId,
    String? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      unitPrice: unitPrice ?? this.unitPrice,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minQuantity: minQuantity ?? this.minQuantity,
      category: category ?? this.category,
      ownerId: ownerId ?? this.ownerId,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
