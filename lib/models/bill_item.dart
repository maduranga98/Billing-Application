// lib/models/bill_item.dart (FIXED - Remove ID from SQLite insert)
class BillItem {
  final String id;
  final String billId;
  final String productId;
  final String productName;
  final String productCode;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  BillItem({
    required this.id,
    required this.billId,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  // Factory constructor from Firestore
  factory BillItem.fromFirestore(Map<String, dynamic> data) {
    return BillItem(
      id: data['id'] ?? '',
      billId: data['billId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productCode: data['productCode'] ?? '',
      quantity: data['quantity'] ?? 0,
      unitPrice: (data['unitPrice'] ?? 0.0).toDouble(),
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
    );
  }

  // Factory constructor from SQLite
  factory BillItem.fromSQLite(Map<String, dynamic> data) {
    return BillItem(
      id: (data['id'] ?? 0).toString(), // Convert integer ID to string
      billId: data['bill_id'] ?? '',
      productId: data['item_id'] ?? '',
      productName: data['item_name'] ?? '',
      productCode: data['product_code'] ?? '',
      quantity: data['quantity'] ?? 0,
      unitPrice: (data['unit_price'] ?? 0.0).toDouble(),
      totalPrice: (data['total_price'] ?? 0.0).toDouble(),
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'billId': billId,
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  // FIXED: Convert to SQLite format - Remove ID to let auto-increment work
  Map<String, dynamic> toSQLite() {
    return {
      // 'id': id, // REMOVED: Let SQLite auto-increment handle this
      'bill_id': billId,
      'item_id': productId,
      'item_name': productName,
      'product_code': productCode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  // Display helpers
  String get quantityDisplay => '$quantity bags';
  String get unitPriceDisplay => 'Rs.${unitPrice.toStringAsFixed(2)}/kg';
  String get totalPriceDisplay => 'Rs.${totalPrice.toStringAsFixed(2)}';

  // Calculate total weight (assuming 25kg bags)
  double get totalWeight => quantity * 25.0;
  String get totalWeightDisplay => '${totalWeight.toStringAsFixed(1)}kg';

  @override
  String toString() {
    return 'BillItem(id: $id, productCode: $productCode, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
