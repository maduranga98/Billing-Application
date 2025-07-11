// lib/models/print_bill.dart (Updated with Loading Cost Support)
class PrintBill {
  final String billNumber;
  final String outletName;
  final String outletAddress;
  final String outletPhone;
  final String customerName;
  final String salesRepName;
  final String salesRepPhone;
  final DateTime billDate;
  final String paymentType;
  final List<PrintBillItem> items;
  final double subtotalAmount; // NEW: Items subtotal
  final double loadingCost; // NEW: Loading/delivery cost
  final double totalAmount; // Total including loading cost
  final double discountAmount;
  final double taxAmount;

  PrintBill({
    required this.billNumber,
    required this.outletName,
    required this.outletAddress,
    required this.outletPhone,
    required this.customerName,
    required this.salesRepName,
    required this.salesRepPhone,
    required this.billDate,
    required this.paymentType,
    required this.items,
    required this.subtotalAmount,
    required this.loadingCost,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
  });

  // Get formatted bill number for printing
  String get formattedBillNumber => 'LB$billNumber';

  // Get formatted date for printing
  String get formattedDate {
    return '${billDate.day.toString().padLeft(2, '0')}/${billDate.month.toString().padLeft(2, '0')}/${billDate.year}';
  }

  // Get formatted time for printing
  String get formattedTime {
    return '${billDate.hour.toString().padLeft(2, '0')}:${billDate.minute.toString().padLeft(2, '0')}';
  }

  // Get formatted datetime for printing
  String get formattedDateTime => '$formattedDate $formattedTime';

  // Get payment type for display
  String get formattedPaymentType {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return 'Cash Payment';
      case 'credit':
        return 'Credit Payment';
      case 'cheque':
        return 'Cheque Payment';
      default:
        return paymentType.toUpperCase();
    }
  }

  // Get total item count
  int get totalItemCount => items.length;

  // Get total quantity (sum of all item quantities)
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  // Get total weight (sum of all item weights)
  double get totalWeight =>
      items.fold(0.0, (sum, item) => sum + item.totalWeight);

  // Get amount breakdown for printing
  List<Map<String, String>> get amountBreakdown {
    final List<Map<String, String>> breakdown = [];

    // Subtotal
    breakdown.add({
      'label': 'Subtotal',
      'value': 'Rs.${subtotalAmount.toStringAsFixed(2)}',
    });

    // Loading cost (only if > 0)
    if (loadingCost > 0) {
      breakdown.add({
        'label': 'Loading Cost',
        'value': 'Rs.${loadingCost.toStringAsFixed(2)}',
      });
    }

    // Discount (only if > 0)
    if (discountAmount > 0) {
      breakdown.add({
        'label': 'Discount',
        'value': '-Rs.${discountAmount.toStringAsFixed(2)}',
      });
    }

    // Tax (only if > 0)
    if (taxAmount > 0) {
      breakdown.add({
        'label': 'Tax',
        'value': 'Rs.${taxAmount.toStringAsFixed(2)}',
      });
    }

    // Total
    breakdown.add({
      'label': 'Total Amount',
      'value': 'Rs.${totalAmount.toStringAsFixed(2)}',
    });

    return breakdown;
  }

  // Get summary line for quick display
  String get summaryLine {
    return '$totalItemCount items • ${totalWeight.toStringAsFixed(1)}kg • Rs.${totalAmount.toStringAsFixed(2)}';
  }

  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'billNumber': billNumber,
      'outletName': outletName,
      'outletAddress': outletAddress,
      'outletPhone': outletPhone,
      'customerName': customerName,
      'salesRepName': salesRepName,
      'salesRepPhone': salesRepPhone,
      'billDate': billDate.toIso8601String(),
      'paymentType': paymentType,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotalAmount': subtotalAmount,
      'loadingCost': loadingCost,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
    };
  }

  // Create from map
  factory PrintBill.fromMap(Map<String, dynamic> map) {
    return PrintBill(
      billNumber: map['billNumber'] ?? '',
      outletName: map['outletName'] ?? '',
      outletAddress: map['outletAddress'] ?? '',
      outletPhone: map['outletPhone'] ?? '',
      customerName: map['customerName'] ?? '',
      salesRepName: map['salesRepName'] ?? '',
      salesRepPhone: map['salesRepPhone'] ?? '',
      billDate: DateTime.parse(
        map['billDate'] ?? DateTime.now().toIso8601String(),
      ),
      paymentType: map['paymentType'] ?? 'cash',
      items:
          (map['items'] as List<dynamic>? ?? [])
              .map(
                (item) => PrintBillItem.fromMap(item as Map<String, dynamic>),
              )
              .toList(),
      subtotalAmount: (map['subtotalAmount'] ?? 0.0).toDouble(),
      loadingCost: (map['loadingCost'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0.0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'PrintBill(billNumber: $billNumber, outletName: $outletName, totalAmount: $totalAmount, loadingCost: $loadingCost, itemCount: ${items.length})';
  }
}

class PrintBillItem {
  final int itemNumber;
  final String itemName;
  final String itemCode;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  PrintBillItem({
    required this.itemNumber,
    required this.itemName,
    required this.itemCode,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  // Get bag size from unit (e.g., "5kg bags" -> 5.0)
  double get bagSize {
    if (unit.contains('kg')) {
      final match = RegExp(r'(\d+(?:\.\d+)?)kg').firstMatch(unit);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '0') ?? 0.0;
      }
    }
    return 0.0;
  }

  // Get total weight for this item
  double get totalWeight => quantity * bagSize;

  // Get formatted display strings
  String get quantityDisplay => '$quantity $unit';
  String get priceDisplay => 'Rs.${unitPrice.toStringAsFixed(2)}/kg';
  String get totalDisplay => 'Rs.${totalPrice.toStringAsFixed(2)}';
  String get weightDisplay => '${totalWeight.toStringAsFixed(1)}kg';

  // Get shortened item name for printing (if needed)
  String getShortName(int maxLength) {
    if (itemName.length <= maxLength) return itemName;
    return '${itemName.substring(0, maxLength - 3)}...';
  }

  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'itemNumber': itemNumber,
      'itemName': itemName,
      'itemCode': itemCode,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  // Create from map
  factory PrintBillItem.fromMap(Map<String, dynamic> map) {
    return PrintBillItem(
      itemNumber: map['itemNumber'] ?? 0,
      itemName: map['itemName'] ?? '',
      itemCode: map['itemCode'] ?? '',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'PrintBillItem(itemNumber: $itemNumber, itemName: $itemName, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrintBillItem &&
        other.itemNumber == itemNumber &&
        other.itemName == itemName &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice;
  }

  @override
  int get hashCode {
    return itemNumber.hashCode ^
        itemName.hashCode ^
        quantity.hashCode ^
        unitPrice.hashCode;
  }
}
