// lib/models/selected_bill_item.dart
class SelectedBillItem {
  final String productId;
  final String productName;
  final String productCode;
  final double unitPrice;
  int quantity;
  final String unit;
  final String category;

  SelectedBillItem({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.unitPrice,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  double get totalPrice => unitPrice * quantity;

  SelectedBillItem copyWith({
    String? productId,
    String? productName,
    String? productCode,
    double? unitPrice,
    int? quantity,
    String? unit,
    String? category,
  }) {
    return SelectedBillItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
    );
  }
}
