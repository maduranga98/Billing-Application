// lib/models/print_bill.dart
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
  final double totalAmount;
  final double discountAmount;
  final double taxAmount;
  final double finalAmount;

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
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
  }) : finalAmount = totalAmount - discountAmount + taxAmount;
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
}
