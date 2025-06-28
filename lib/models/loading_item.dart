// lib/models/loading_item.dart
class LoadingItem {
  final String productId;
  final String productName;
  final String productCode;
  final double unitPrice;
  final int loadedQuantity;
  final int soldQuantity;
  final double totalWeight;
  final String unit;
  final String category;

  LoadingItem({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.unitPrice,
    required this.loadedQuantity,
    required this.soldQuantity,
    required this.totalWeight,
    required this.unit,
    required this.category,
  });

  factory LoadingItem.fromMap(Map<String, dynamic> data) {
    return LoadingItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productCode: data['productCode'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      loadedQuantity: data['loadedQuantity'] ?? 0,
      soldQuantity: data['soldQuantity'] ?? 0,
      totalWeight: (data['totalWeight'] ?? 0).toDouble(),
      unit: data['unit'] ?? '',
      category: data['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'unitPrice': unitPrice,
      'loadedQuantity': loadedQuantity,
      'soldQuantity': soldQuantity,
      'totalWeight': totalWeight,
      'unit': unit,
      'category': category,
    };
  }

  // Calculate available quantity for sales
  int get availableQuantity => loadedQuantity - soldQuantity;

  // Calculate total value for this item
  double get totalValue => availableQuantity * unitPrice;

  // Check if item is out of stock
  bool get isOutOfStock => availableQuantity <= 0;

  // Check if item is low stock (less than 20% of loaded quantity)
  bool get isLowStock =>
      availableQuantity <= (loadedQuantity * 0.2) && !isOutOfStock;

  // Create copy with updated sold quantity
  LoadingItem copyWithSoldQuantity(int additionalSold) {
    return LoadingItem(
      productId: productId,
      productName: productName,
      productCode: productCode,
      unitPrice: unitPrice,
      loadedQuantity: loadedQuantity,
      soldQuantity: soldQuantity + additionalSold,
      totalWeight: totalWeight,
      unit: unit,
      category: category,
    );
  }

  @override
  String toString() {
    return 'LoadingItem(productId: $productId, productName: $productName, availableQuantity: $availableQuantity)';
  }
}
