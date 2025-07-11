// lib/models/selected_bill_item.dart (Complete Updated Version)
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
        '${item.productCode}_${DateTime.now().millisecondsSinceEpoch}';

    return SelectedBillItem(
      productId: id,
      originalProductId: item.productCode,
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

  // Convert to Map for Firebase/database storage
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

  // Create from Map (for Firebase/database retrieval)
  factory SelectedBillItem.fromMap(Map<String, dynamic> map) {
    return SelectedBillItem(
      productId: map['productId'] ?? '',
      originalProductId: map['originalProductId'] ?? map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productCode: map['productCode'] ?? '',
      quantity: map['quantity']?.toInt() ?? 0,
      unitPrice: map['unitPrice']?.toDouble() ?? 0.0,
      bagSize: map['bagSize']?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      category: map['category'] ?? '',
      totalPrice: map['totalPrice']?.toDouble() ?? 0.0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => toMap();

  // Create from JSON
  factory SelectedBillItem.fromJson(Map<String, dynamic> json) =>
      SelectedBillItem.fromMap(json);

  // Calculate weight for this item
  double get totalWeight => quantity * bagSize;

  // Display formatted total price
  String get formattedTotalPrice => 'Rs.${totalPrice.toStringAsFixed(2)}';

  // Display formatted unit price
  String get formattedUnitPrice => 'Rs.${unitPrice.toStringAsFixed(2)}/kg';

  // Display quantity with unit
  String get quantityWithUnit => '$quantity × ${bagSize}kg bags';

  // Display full item description
  String get fullDescription =>
      '$productName ($quantityWithUnit @ $formattedUnitPrice)';

  @override
  String toString() {
    return 'SelectedBillItem(productId: $productId, productName: $productName, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedBillItem && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;
}
