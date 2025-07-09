// lib/models/selected_bill_item.dart (Updated with Custom Price Support)
class SelectedBillItem {
  final String productId;
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
    double customPrice,
  ) {
    final totalPrice = quantity * item.bagSize * customPrice;

    return SelectedBillItem(
      productId: item.productId,
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
      'productId': productId,
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

  @override
  String toString() {
    return 'SelectedBillItem(productId: $productId, productName: $productName, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
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
