// lib/models/loading_item.dart (Fixed itemName/displayName mapping)
class LoadingItem {
  final int bagQuantity;
  final double bagSize; // Changed to double since you have 0.5kg bags
  final int bagsCount;
  final List<BagUsed> bagsUsed;
  final String
  displayName; // Contains batch info: "Sudu Kakulu 5kg (Batch: B250705-003)"
  final String itemName; // Clean name: "Sudu Kakulu 5kg"
  final double maxPrice;
  final double minPrice;
  final double pricePerKg;
  final String productCode;
  final String productType;
  final String? riceType;
  final String? sourceBatchId;
  final String? sourceBatchNumber;
  final double totalValue;
  final double totalWeight;

  LoadingItem({
    required this.bagQuantity,
    required this.bagSize,
    required this.bagsCount,
    required this.bagsUsed,
    required this.displayName,
    required this.itemName,
    required this.maxPrice,
    required this.minPrice,
    required this.pricePerKg,
    required this.productCode,
    required this.productType,
    this.riceType,
    this.sourceBatchId,
    this.sourceBatchNumber,
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
        bagSize: _parseDouble(data['bagSize']),
        bagsCount: _parseInt(data['bagsCount']),
        bagsUsed: bags,
        displayName:
            data['displayName'] ?? '', // "Sudu Kakulu 5kg (Batch: B250705-003)"
        itemName: data['itemName'] ?? '', // "Sudu Kakulu 5kg"
        maxPrice: _parseDouble(data['maxPrice']),
        minPrice: _parseDouble(data['minPrice']),
        pricePerKg: _parseDouble(data['pricePerKg']),
        productCode: data['productCode'] ?? '',
        productType: data['productType'] ?? '',
        riceType: data['riceType'],
        sourceBatchId: data['sourceBatchId'],
        sourceBatchNumber: data['sourceBatchNumber'],
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
      'itemName': itemName,
      'maxPrice': maxPrice,
      'minPrice': minPrice,
      'pricePerKg': pricePerKg,
      'productCode': productCode,
      'productType': productType,
      'riceType': riceType,
      'sourceBatchId': sourceBatchId,
      'sourceBatchNumber': sourceBatchNumber,
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
  String get category => productType;

  // For compatibility with existing billing code - FIXED MAPPING
  String get productName => itemName; // Use clean itemName for billing/printing
  String get productId => productCode;
  int get loadedQuantity => bagQuantity;
  int get soldQuantity => 0; // No sold quantity in this structure
  int get availableQuantity => bagQuantity;
  String get unit => '${bagSize}kg bags';

  // Display methods for different contexts
  String get printName =>
      itemName; // Clean name for printing: "Sudu Kakulu 5kg"
  String get detailName =>
      displayName; // Full name with batch for details: "Sudu Kakulu 5kg (Batch: B250705-003)"
  String get listName => itemName; // Clean name for item lists and selection

  // Status checks
  bool get isOutOfStock => bagQuantity <= 0;
  bool get isLowStock => false; // No low stock concept for daily loading

  // Values
  double get totalLoadedValue => totalValue;
  double get totalSoldValue => 0.0;
  double get totalAvailableValue => totalValue;

  // Batch information
  String get batchInfo {
    if (sourceBatchNumber != null) {
      return 'Batch: $sourceBatchNumber';
    }
    return 'No batch info';
  }

  // Price range info
  String get priceRangeInfo {
    return 'Rs.${minPrice.toStringAsFixed(2)} - Rs.${maxPrice.toStringAsFixed(2)}';
  }

  // Full display info
  String get fullDisplayInfo {
    return '$displayName (${unit}) - $batchInfo';
  }

  // Create copy with updated sold quantity (for future use)
  LoadingItem copyWithSoldQuantity(int additionalSold) {
    // For this structure, we don't track sold quantities in the loading item
    return this;
  }

  @override
  String toString() {
    return 'LoadingItem(productCode: $productCode, itemName: $itemName, displayName: $displayName, bagQuantity: $bagQuantity, bagSize: ${bagSize}kg)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoadingItem &&
        other.productCode == productCode &&
        other.sourceBatchId == sourceBatchId;
  }

  @override
  int get hashCode => productCode.hashCode ^ (sourceBatchId?.hashCode ?? 0);
}

// lib/models/bag_used.dart (Updated)
class BagUsed {
  final String bagDocId;
  final String? bagId; // Nullable since it can be null in your data
  final double bagSize; // Changed to double
  final double pricePerKg;
  final double weight;

  BagUsed({
    required this.bagDocId,
    this.bagId,
    required this.bagSize,
    required this.pricePerKg,
    required this.weight,
  });

  factory BagUsed.fromMap(Map<String, dynamic> data) {
    return BagUsed(
      bagDocId: data['bagDocId'] ?? '',
      bagId: data['bagId'], // Can be null
      bagSize: _parseDouble(data['bagSize']),
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

  // Display information
  String get bagInfo {
    final id = bagId ?? 'No ID';
    return '${bagSize}kg bag (ID: $id)';
  }

  double get totalValue {
    return weight * pricePerKg;
  }

  @override
  String toString() {
    return 'BagUsed(bagDocId: $bagDocId, bagSize: ${bagSize}kg, weight: ${weight}kg)';
  }
}
