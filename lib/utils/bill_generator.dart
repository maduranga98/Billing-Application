// lib/utils/bill_generator.dart
import '../models/print_bill.dart';
import '../models/selected_bill_item.dart';
import '../models/outlet.dart';
import '../models/user_session.dart';

class BillGenerator {
  static PrintBill generatePrintBill({
    required String billNumber,
    required Outlet outlet,
    required UserSession salesRep,
    required List<SelectedBillItem> selectedItems,
    required String paymentType,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
  }) {
    // Convert selected items to print items
    final printItems =
        selectedItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return PrintBillItem(
            itemNumber: index + 1,
            itemName: item.productName,
            itemCode: item.productCode,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          );
        }).toList();

    // Calculate total amount
    final totalAmount = selectedItems.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );

    return PrintBill(
      billNumber: billNumber,
      outletName: outlet.outletName,
      outletAddress: outlet.address,
      outletPhone: outlet.phoneNumber,
      customerName: outlet.ownerName,
      salesRepName: salesRep.name,
      salesRepPhone: salesRep.phone,
      billDate: DateTime.now(),
      paymentType: paymentType,
      items: printItems,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
    );
  }
}
