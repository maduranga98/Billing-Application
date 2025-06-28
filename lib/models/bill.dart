class Bill {
  final String id;
  final String billNumber;
  final String outletId;
  final String outletName;
  final String outletAddress;
  final String outletPhone;
  final double totalAmount;
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
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.paymentType,
    this.paymentStatus = 'pending',
    required this.ownerId,
    required this.businessId,
    required this.createdBy,
    required this.salesRepName,
    required this.salesRepPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'billNumber': billNumber,
      'outletId': outletId,
      'outletName': outletName,
      'outletAddress': outletAddress,
      'outletPhone': outletPhone,
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

  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'bill_number': billNumber,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'outlet_address': outletAddress,
      'outlet_phone': outletPhone,
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
      'sync_status': 'pending',
    };
  }
}
