// lib/models/loading_item.dart (Updated for real structure)
class LoadingItem {
  final int bagQuantity;
  final int bagSize;
  final int bagsCount;
  final List<BagUsed> bagsUsed;
  final String displayName;
  final double pricePerKg;
  final String productCode;
  final String productType;
  final String? riceType;
  final double totalValue;
  final double totalWeight;

  LoadingItem({
    required this.bagQuantity,
    required this.bagSize,
    required this.bagsCount,
    required this.bagsUsed,
    required this.displayName,
    required this.pricePerKg,
    required this.productCode,
    required this.productType,
    this.riceType,
    required this.totalValue,
    required this.totalWeight,
  });

  factory LoadingItem.fromMap(Map<String, dynamic> data) {
    try {
      final bagsUsedList = data['bagsUsed'] as List<dynamic>? ?? [];
      final bags =
          bagsUsedList
              .map((bag) => BagUsed.fromMap(bag as Map<String, dynamic>))
              .toList();

      return LoadingItem(
        bagQuantity: _parseInt(data['bagQuantity']),
        bagSize: _parseInt(data['bagSize']),
        bagsCount: _parseInt(data['bagsCount']),
        bagsUsed: bags,
        displayName: data['displayName'] ?? '',
        pricePerKg: _parseDouble(data['pricePerKg']),
        productCode: data['productCode'] ?? '',
        productType: data['productType'] ?? '',
        riceType: data['riceType'],
        totalValue: _parseDouble(data['totalValue']),
        totalWeight: _parseDouble(data['totalWeight']),
      );
    } catch (e) {
      print('Error parsing LoadingItem: $e');
      print('Data: $data');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'bagQuantity': bagQuantity,
      'bagSize': bagSize,
      'bagsCount': bagsCount,
      'bagsUsed': bagsUsed.map((bag) => bag.toMap()).toList(),
      'displayName': displayName,
      'pricePerKg': pricePerKg,
      'productCode': productCode,
      'productType': productType,
      'riceType': riceType,
      'totalValue': totalValue,
      'totalWeight': totalWeight,
    };
  }

  // Helper methods for safe parsing
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Business logic methods
  int get availableBags =>
      bagsCount; // All bags are available since there's no sold quantity
  double get unitPrice => pricePerKg;
  String get itemName => displayName;
  String get category => productType;

  // For compatibility with existing code
  String get productName => displayName;
  String get productId => productCode;
  int get loadedQuantity => bagQuantity;
  int get soldQuantity => 0; // No sold quantity in this structure
  int get availableQuantity => bagQuantity;
  String get unit => '${bagSize}kg bags';

  // Status checks
  bool get isOutOfStock => bagQuantity <= 0;
  bool get isLowStock => false; // No low stock concept for daily loading

  // Values
  double get totalLoadedValue => totalValue;
  double get totalSoldValue => 0.0;
  double get totalAvailableValue => totalValue;

  // Create copy with updated sold quantity (for future use)
  LoadingItem copyWithSoldQuantity(int additionalSold) {
    // For this structure, we don't track sold quantities
    return this;
  }

  @override
  String toString() {
    return 'LoadingItem(productCode: $productCode, displayName: $displayName, bagQuantity: $bagQuantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoadingItem && other.productCode == productCode;
  }

  @override
  int get hashCode => productCode.hashCode;
}

// lib/models/bag_used.dart
class BagUsed {
  final String bagDocId;
  final String bagId;
  final int bagSize;
  final double pricePerKg;
  final double weight;

  BagUsed({
    required this.bagDocId,
    required this.bagId,
    required this.bagSize,
    required this.pricePerKg,
    required this.weight,
  });

  factory BagUsed.fromMap(Map<String, dynamic> data) {
    return BagUsed(
      bagDocId: data['bagDocId'] ?? '',
      bagId: data['bagId'] ?? '',
      bagSize: _parseInt(data['bagSize']),
      pricePerKg: _parseDouble(data['pricePerKg']),
      weight: _parseDouble(data['weight']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bagDocId': bagDocId,
      'bagId': bagId,
      'bagSize': bagSize,
      'pricePerKg': pricePerKg,
      'weight': weight,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  String toString() {
    return 'BagUsed(bagId: $bagId, weight: $weight kg)';
  }
}
