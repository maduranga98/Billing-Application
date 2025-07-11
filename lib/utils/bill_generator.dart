// lib/utils/bill_generator.dart (Updated with Loading Cost Support)
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
    double loadingCost = 0.0, // NEW: Loading cost parameter
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

    // Calculate subtotal (items only)
    final subtotalAmount = selectedItems.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );

    // Calculate total amount including loading cost
    final totalAmount =
        subtotalAmount + loadingCost - discountAmount + taxAmount;

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
      subtotalAmount: subtotalAmount, // NEW: Subtotal field
      loadingCost: loadingCost, // NEW: Loading cost field
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
    );
  }

  // Generate bill summary for display
  static Map<String, dynamic> generateBillSummary({
    required List<SelectedBillItem> selectedItems,
    double loadingCost = 0.0,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
  }) {
    final subtotalAmount = selectedItems.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );

    final totalWeight = selectedItems.fold(
      0.0,
      (sum, item) => sum + item.totalWeight,
    );

    final totalQuantity = selectedItems.fold(
      0,
      (sum, item) => sum + item.quantity,
    );

    final totalAmount =
        subtotalAmount + loadingCost - discountAmount + taxAmount;

    return {
      'itemCount': selectedItems.length,
      'totalQuantity': totalQuantity,
      'totalWeight': totalWeight,
      'subtotalAmount': subtotalAmount,
      'loadingCost': loadingCost,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'breakdown': {
        'Subtotal': 'Rs.${subtotalAmount.toStringAsFixed(2)}',
        if (loadingCost > 0)
          'Loading Cost': 'Rs.${loadingCost.toStringAsFixed(2)}',
        if (discountAmount > 0)
          'Discount': '-Rs.${discountAmount.toStringAsFixed(2)}',
        if (taxAmount > 0) 'Tax': 'Rs.${taxAmount.toStringAsFixed(2)}',
        'Total': 'Rs.${totalAmount.toStringAsFixed(2)}',
      },
    };
  }

  // Generate items breakdown by category
  static Map<String, List<SelectedBillItem>> groupItemsByCategory(
    List<SelectedBillItem> items,
  ) {
    final Map<String, List<SelectedBillItem>> grouped = {};

    for (final item in items) {
      final category = item.category.isEmpty ? 'Uncategorized' : item.category;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }

    return grouped;
  }

  // Generate items breakdown by product code (for duplicate handling)
  static Map<String, List<SelectedBillItem>> groupItemsByProductCode(
    List<SelectedBillItem> items,
  ) {
    final Map<String, List<SelectedBillItem>> grouped = {};

    for (final item in items) {
      final productCode = item.productCode;
      if (!grouped.containsKey(productCode)) {
        grouped[productCode] = [];
      }
      grouped[productCode]!.add(item);
    }

    return grouped;
  }

  // Calculate category-wise totals
  static Map<String, Map<String, dynamic>> calculateCategoryTotals(
    List<SelectedBillItem> items,
  ) {
    final grouped = groupItemsByCategory(items);
    final Map<String, Map<String, dynamic>> categoryTotals = {};

    for (final entry in grouped.entries) {
      final category = entry.key;
      final categoryItems = entry.value;

      final totalValue = categoryItems.fold(
        0.0,
        (sum, item) => sum + item.totalPrice,
      );
      final totalWeight = categoryItems.fold(
        0.0,
        (sum, item) => sum + item.totalWeight,
      );
      final totalQuantity = categoryItems.fold(
        0,
        (sum, item) => sum + item.quantity,
      );

      categoryTotals[category] = {
        'itemCount': categoryItems.length,
        'totalQuantity': totalQuantity,
        'totalWeight': totalWeight,
        'totalValue': totalValue,
        'items': categoryItems,
      };
    }

    return categoryTotals;
  }

  // Generate payment breakdown
  static Map<String, dynamic> generatePaymentBreakdown({
    required double totalAmount,
    required String paymentType,
    double paidAmount = 0.0,
  }) {
    final remainingAmount = totalAmount - paidAmount;
    final isPaidInFull = remainingAmount <= 0;

    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount > 0 ? remainingAmount : 0.0,
      'paymentType': paymentType,
      'isPaidInFull': isPaidInFull,
      'paymentStatus': isPaidInFull ? 'paid' : 'pending',
      'display': {
        'total': 'Rs.${totalAmount.toStringAsFixed(2)}',
        'paid': 'Rs.${paidAmount.toStringAsFixed(2)}',
        'remaining':
            'Rs.${(remainingAmount > 0 ? remainingAmount : 0.0).toStringAsFixed(2)}',
      },
    };
  }

  // Validate bill data before generation
  static Map<String, dynamic> validateBillData({
    required List<SelectedBillItem> items,
    required String paymentType,
    double loadingCost = 0.0,
  }) {
    final List<String> errors = [];

    // Check if items exist
    if (items.isEmpty) {
      errors.add('No items selected for the bill');
    }

    // Validate payment type
    final validPaymentTypes = ['cash', 'credit', 'cheque'];
    if (!validPaymentTypes.contains(paymentType.toLowerCase())) {
      errors.add('Invalid payment type: $paymentType');
    }

    // Validate loading cost
    if (loadingCost < 0) {
      errors.add('Loading cost cannot be negative');
    }

    // Validate item prices and quantities
    for (final item in items) {
      if (item.quantity <= 0) {
        errors.add(
          'Invalid quantity for ${item.productName}: ${item.quantity}',
        );
      }
      if (item.unitPrice < 0) {
        errors.add('Invalid price for ${item.productName}: ${item.unitPrice}');
      }
      if (item.totalPrice < 0) {
        errors.add(
          'Invalid total price for ${item.productName}: ${item.totalPrice}',
        );
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'summary':
          errors.isEmpty
              ? generateBillSummary(
                selectedItems: items,
                loadingCost: loadingCost,
              )
              : null,
    };
  }

  // Format currency for display
  static String formatCurrency(double amount) {
    return 'Rs.${amount.toStringAsFixed(2)}';
  }

  // Format weight for display
  static String formatWeight(double weight) {
    return '${weight.toStringAsFixed(1)}kg';
  }

  // Format date for display
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Format time for display
  static String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Format datetime for display
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${formatTime(date)}';
  }
}
