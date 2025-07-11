// lib/models/selected_bill_item.dart (Updated with Original Product ID Support)
class SelectedBillItem {
  final String productId; // Unique ID for this bill item instance
  final String originalProductId; // Original product ID from LoadingItem
  final String productName;
  final String productCode;
  final int quantity; // Number of bags
  final double
  unitPrice; // Price per kg (can be customized within min-max range)
  final double bagSize; // Size of each bag in kg
  final String unit;
  final String category;
  final double totalPrice; // quantity * bagSize * unitPrice

  SelectedBillItem({
    required this.productId,
    required this.originalProductId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.bagSize,
    required this.unit,
    required this.category,
    required this.totalPrice,
  });

  // Factory constructor from LoadingItem with custom price
  factory SelectedBillItem.fromLoadingItem(
    dynamic item, // LoadingItem
    int quantity,
    double customPrice, {
    String? uniqueId,
  }) {
    final totalPrice = quantity * item.bagSize * customPrice;
    final id =
        uniqueId ??
        '${item.productId}_${DateTime.now().millisecondsSinceEpoch}';

    return SelectedBillItem(
      productId: id,
      originalProductId: item.productId,
      productName: item.productName,
      productCode: item.productCode,
      quantity: quantity,
      unitPrice: customPrice,
      bagSize: item.bagSize,
      unit: item.unit,
      category: item.category,
      totalPrice: totalPrice,
    );
  }

  // Copy with new values
  SelectedBillItem copyWith({
    String? productId,
    String? originalProductId,
    String? productName,
    String? productCode,
    int? quantity,
    double? unitPrice,
    double? bagSize,
    String? unit,
    String? category,
    double? totalPrice,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    final newBagSize = bagSize ?? this.bagSize;

    return SelectedBillItem(
      productId: productId ?? this.productId,
      originalProductId: originalProductId ?? this.originalProductId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      quantity: newQuantity,
      unitPrice: newUnitPrice,
      bagSize: newBagSize,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      totalPrice: totalPrice ?? (newQuantity * newBagSize * newUnitPrice),
    );
  }

  // Convert to map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'originalProductId': originalProductId,
      'productName': productName,
      'productCode': productCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'bagSize': bagSize,
      'unit': unit,
      'category': category,
      'totalPrice': totalPrice,
    };
  }

  // Factory constructor from map
  factory SelectedBillItem.fromMap(Map<String, dynamic> map) {
    return SelectedBillItem(
      productId: map['productId'] ?? '',
      originalProductId:
          map['originalProductId'] ??
          map['productId'] ??
          '', // Fallback for backward compatibility
      productName: map['productName'] ?? '',
      productCode: map['productCode'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      bagSize: (map['bagSize'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? '',
      category: map['category'] ?? '',
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
    );
  }

  // Convert to BillItem for database/API
  Map<String, dynamic> toBillItem() {
    return {
      'productId': originalProductId, // Use original product ID for database
      'productName': productName,
      'productCode': productCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'bagSize': bagSize,
      'unit': unit,
    };
  }

  // Display helpers
  String get quantityDisplay => '$quantity ${unit}';
  String get priceDisplay => 'Rs.${unitPrice.toStringAsFixed(2)}/kg';
  String get totalDisplay => 'Rs.${totalPrice.toStringAsFixed(2)}';

  // Calculate total weight
  double get totalWeight => quantity * bagSize;
  String get weightDisplay => '${totalWeight.toStringAsFixed(1)}kg';

  // Price validation helpers
  bool isPriceValid(double minPrice, double maxPrice) {
    return unitPrice >= minPrice && unitPrice <= maxPrice;
  }

  String getPriceStatus(double minPrice, double maxPrice) {
    if (unitPrice < minPrice) return 'Below minimum price';
    if (unitPrice > maxPrice) return 'Above maximum price';
    if (unitPrice == minPrice) return 'Minimum price';
    if (unitPrice == maxPrice) return 'Maximum price';
    return 'Custom price';
  }

  // Check if using default/suggested price
  bool isUsingPrice(double checkPrice) {
    return (unitPrice - checkPrice).abs() <
        0.01; // Account for floating point precision
  }

  // Display name with instance info (for showing multiple items of same product)
  String get displayNameWithInstance {
    return '$productName (${quantityDisplay} @ ${priceDisplay})';
  }

  // Check if this is a duplicate item (same product code but different instance)
  bool isDuplicateOf(SelectedBillItem other) {
    return productCode == other.productCode && productId != other.productId;
  }

  @override
  String toString() {
    return 'SelectedBillItem(productId: $productId, originalProductId: $originalProductId, productName: $productName, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedBillItem &&
        other.productId == productId &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice;
  }

  @override
  int get hashCode {
    return productId.hashCode ^ quantity.hashCode ^ unitPrice.hashCode;
  }
}
