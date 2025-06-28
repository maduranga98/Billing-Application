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

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  Map<String, dynamic> toSQLite() {
    return {
      'bill_id': billId,
      'product_id': productId,
      'product_name': productName,
      'product_code': productCode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}
