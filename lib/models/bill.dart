// lib/models/bill.dart (Updated with Loading Cost Support)
class Bill {
  final String id;
  final String billNumber;
  final String outletId;
  final String outletName;
  final String outletAddress;
  final String outletPhone;
  final double subtotalAmount; // NEW: Items subtotal
  final double loadingCost; // NEW: Loading/delivery cost
  final double totalAmount; // Total including loading cost
  final double discountAmount;
  final double taxAmount;
  final String paymentType;
  final String paymentStatus;
  final String ownerId;
  final String businessId;
  final String createdBy;
  final String salesRepName;
  final String salesRepPhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bill({
    required this.id,
    required this.billNumber,
    required this.outletId,
    required this.outletName,
    required this.outletAddress,
    required this.outletPhone,
    required this.subtotalAmount,
    required this.loadingCost,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.paymentType,
    this.paymentStatus = 'pending',
    required this.ownerId,
    required this.businessId,
    required this.createdBy,
    required this.salesRepName,
    this.salesRepPhone = '',
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor from Firestore
  factory Bill.fromFirestore(Map<String, dynamic> data) {
    return Bill(
      id: data['id'] ?? '',
      billNumber: data['billNumber'] ?? '',
      outletId: data['outletId'] ?? '',
      outletName: data['outletName'] ?? '',
      outletAddress: data['outletAddress'] ?? '',
      outletPhone: data['outletPhone'] ?? '',
      subtotalAmount: (data['subtotalAmount'] ?? 0.0).toDouble(),
      loadingCost: (data['loadingCost'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      discountAmount: (data['discountAmount'] ?? 0.0).toDouble(),
      taxAmount: (data['taxAmount'] ?? 0.0).toDouble(),
      paymentType: data['paymentType'] ?? 'cash',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      ownerId: data['ownerId'] ?? '',
      businessId: data['businessId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      salesRepName: data['salesRepName'] ?? '',
      salesRepPhone: data['salesRepPhone'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  // Factory constructor from SQLite
  factory Bill.fromSQLite(Map<String, dynamic> data) {
    // Handle backward compatibility for bills without subtotal/loading cost
    final totalAmount = (data['total_amount'] ?? 0.0).toDouble();
    final loadingCost = (data['loading_cost'] ?? 0.0).toDouble();
    final subtotalAmount =
        (data['subtotal_amount'] ?? (totalAmount - loadingCost)).toDouble();

    return Bill(
      id: data['id'] ?? '',
      billNumber: data['bill_number'] ?? '',
      outletId: data['outlet_id'] ?? '',
      outletName: data['outlet_name'] ?? '',
      outletAddress: data['outlet_address'] ?? '',
      outletPhone: data['outlet_phone'] ?? '',
      subtotalAmount: subtotalAmount,
      loadingCost: loadingCost,
      totalAmount: totalAmount,
      discountAmount: (data['discount_amount'] ?? 0.0).toDouble(),
      taxAmount: (data['tax_amount'] ?? 0.0).toDouble(),
      paymentType: data['payment_type'] ?? 'cash',
      paymentStatus: data['payment_status'] ?? 'pending',
      ownerId: data['owner_id'] ?? '',
      businessId: data['business_id'] ?? '',
      createdBy: data['created_by'] ?? '',
      salesRepName: data['sales_rep_name'] ?? '',
      salesRepPhone: data['sales_rep_phone'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] ?? 0),
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'billNumber': billNumber,
      'outletId': outletId,
      'outletName': outletName,
      'outletAddress': outletAddress,
      'outletPhone': outletPhone,
      'subtotalAmount': subtotalAmount,
      'loadingCost': loadingCost,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'paymentType': paymentType,
      'paymentStatus': paymentStatus,
      'ownerId': ownerId,
      'businessId': businessId,
      'createdBy': createdBy,
      'salesRepName': salesRepName,
      'salesRepPhone': salesRepPhone,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Convert to SQLite format
  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'bill_number': billNumber,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'outlet_address': outletAddress,
      'outlet_phone': outletPhone,
      'subtotal_amount': subtotalAmount,
      'loading_cost': loadingCost,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'payment_type': paymentType,
      'payment_status': paymentStatus,
      'owner_id': ownerId,
      'business_id': businessId,
      'created_by': createdBy,
      'sales_rep_name': salesRepName,
      'sales_rep_phone': salesRepPhone,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create copy with updated values
  Bill copyWith({
    String? id,
    String? billNumber,
    String? outletId,
    String? outletName,
    String? outletAddress,
    String? outletPhone,
    double? subtotalAmount,
    double? loadingCost,
    double? totalAmount,
    double? discountAmount,
    double? taxAmount,
    String? paymentType,
    String? paymentStatus,
    String? ownerId,
    String? businessId,
    String? createdBy,
    String? salesRepName,
    String? salesRepPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      outletAddress: outletAddress ?? this.outletAddress,
      outletPhone: outletPhone ?? this.outletPhone,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      loadingCost: loadingCost ?? this.loadingCost,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      paymentType: paymentType ?? this.paymentType,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      ownerId: ownerId ?? this.ownerId,
      businessId: businessId ?? this.businessId,
      createdBy: createdBy ?? this.createdBy,
      salesRepName: salesRepName ?? this.salesRepName,
      salesRepPhone: salesRepPhone ?? this.salesRepPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Display helpers
  String get formattedBillNumber => 'LB$billNumber';
  String get formattedDate =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
  String get formattedTime =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  String get formattedDateTime => '$formattedDate $formattedTime';

  String get subtotalDisplay => 'Rs.${subtotalAmount.toStringAsFixed(2)}';
  String get loadingCostDisplay => 'Rs.${loadingCost.toStringAsFixed(2)}';
  String get totalAmountDisplay => 'Rs.${totalAmount.toStringAsFixed(2)}';
  String get discountDisplay => 'Rs.${discountAmount.toStringAsFixed(2)}';
  String get taxDisplay => 'Rs.${taxAmount.toStringAsFixed(2)}';

  // Payment status helpers
  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isPending => paymentStatus.toLowerCase() == 'pending';
  bool get isCancelled => paymentStatus.toLowerCase() == 'cancelled';

  // Payment type helpers
  bool get isCashPayment => paymentType.toLowerCase() == 'cash';
  bool get isCreditPayment => paymentType.toLowerCase() == 'credit';
  bool get isChequePayment => paymentType.toLowerCase() == 'cheque';

  // Status colors for UI
  String get paymentStatusColor {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        return 'green';
      case 'pending':
        return 'orange';
      case 'cancelled':
        return 'red';
      default:
        return 'grey';
    }
  }

  // Breakdown display
  Map<String, String> get amountBreakdown {
    return {
      'Subtotal': subtotalDisplay,
      if (loadingCost > 0) 'Loading Cost': loadingCostDisplay,
      if (discountAmount > 0) 'Discount': '-${discountDisplay}',
      if (taxAmount > 0) 'Tax': taxDisplay,
      'Total': totalAmountDisplay,
    };
  }

  @override
  String toString() {
    return 'Bill(id: $id, billNumber: $billNumber, totalAmount: $totalAmount, loadingCost: $loadingCost, paymentType: $paymentType, paymentStatus: $paymentStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bill && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
