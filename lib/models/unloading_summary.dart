// lib/models/unloading_summary.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UnloadingSummary {
  final String id;
  final String loadingId;
  final String businessId;
  final String ownerId;
  final String salesRepId;
  final String salesRepName;
  final String routeId;
  final String routeName;
  final DateTime unloadingDate;

  // Sales totals
  final int totalBillCount;
  final double totalSalesValue;
  final double totalCashSales;
  final double totalCreditSales;
  final double totalChequeSales;

  // Stock information
  final int totalItemsLoaded;
  final double totalValueLoaded;
  final List<Map<String, dynamic>> itemsSold;
  final List<Map<String, dynamic>> remainingStock;

  // Metadata
  final DateTime createdAt;
  final String createdBy;
  final String notes;
  final String status;

  UnloadingSummary({
    required this.id,
    required this.loadingId,
    required this.businessId,
    required this.ownerId,
    required this.salesRepId,
    required this.salesRepName,
    required this.routeId,
    required this.routeName,
    required this.unloadingDate,
    required this.totalBillCount,
    required this.totalSalesValue,
    required this.totalCashSales,
    required this.totalCreditSales,
    required this.totalChequeSales,
    required this.totalItemsLoaded,
    required this.totalValueLoaded,
    required this.itemsSold,
    required this.remainingStock,
    required this.createdAt,
    required this.createdBy,
    this.notes = '',
    this.status = 'completed',
  });

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'loadingId': loadingId,
      'businessId': businessId,
      'ownerId': ownerId,
      'salesRepId': salesRepId,
      'salesRepName': salesRepName,
      'routeId': routeId,
      'routeName': routeName,
      'unloadingDate': Timestamp.fromDate(unloadingDate),
      'totalBillCount': totalBillCount,
      'totalSalesValue': totalSalesValue,
      'totalCashSales': totalCashSales,
      'totalCreditSales': totalCreditSales,
      'totalChequeSales': totalChequeSales,
      'totalItemsLoaded': totalItemsLoaded,
      'totalValueLoaded': totalValueLoaded,
      'itemsSold': itemsSold,
      'remainingStock': remainingStock,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'notes': notes,
      'status': status,
    };
  }

  // Factory constructor from Firestore
  factory UnloadingSummary.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return UnloadingSummary(
      id: documentId,
      loadingId: data['loadingId'] ?? '',
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      salesRepId: data['salesRepId'] ?? '',
      salesRepName: data['salesRepName'] ?? '',
      routeId: data['routeId'] ?? '',
      routeName: data['routeName'] ?? '',
      unloadingDate:
          (data['unloadingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalBillCount: data['totalBillCount'] ?? 0,
      totalSalesValue: (data['totalSalesValue'] ?? 0.0).toDouble(),
      totalCashSales: (data['totalCashSales'] ?? 0.0).toDouble(),
      totalCreditSales: (data['totalCreditSales'] ?? 0.0).toDouble(),
      totalChequeSales: (data['totalChequeSales'] ?? 0.0).toDouble(),
      totalItemsLoaded: data['totalItemsLoaded'] ?? 0,
      totalValueLoaded: (data['totalValueLoaded'] ?? 0.0).toDouble(),
      itemsSold: List<Map<String, dynamic>>.from(data['itemsSold'] ?? []),
      remainingStock: List<Map<String, dynamic>>.from(
        data['remainingStock'] ?? [],
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'completed',
    );
  }

  // Convert to SQLite format (for local caching if needed)
  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'loading_id': loadingId,
      'business_id': businessId,
      'owner_id': ownerId,
      'sales_rep_id': salesRepId,
      'sales_rep_name': salesRepName,
      'route_id': routeId,
      'route_name': routeName,
      'unloading_date': unloadingDate.millisecondsSinceEpoch,
      'total_bill_count': totalBillCount,
      'total_sales_value': totalSalesValue,
      'total_cash_sales': totalCashSales,
      'total_credit_sales': totalCreditSales,
      'total_cheque_sales': totalChequeSales,
      'total_items_loaded': totalItemsLoaded,
      'total_value_loaded': totalValueLoaded,
      'items_sold': itemsSold.toString(), // JSON string
      'remaining_stock': remainingStock.toString(), // JSON string
      'created_at': createdAt.millisecondsSinceEpoch,
      'created_by': createdBy,
      'notes': notes,
      'status': status,
    };
  }

  // Display helpers
  String get dateDisplay =>
      '${unloadingDate.day}/${unloadingDate.month}/${unloadingDate.year}';
  String get salesValueDisplay => 'Rs.${totalSalesValue.toStringAsFixed(2)}';
  String get cashSalesDisplay => 'Rs.${totalCashSales.toStringAsFixed(2)}';
  String get creditSalesDisplay => 'Rs.${totalCreditSales.toStringAsFixed(2)}';
  String get chequeSalesDisplay => 'Rs.${totalChequeSales.toStringAsFixed(2)}';

  double get salesPercentage =>
      totalValueLoaded > 0 ? (totalSalesValue / totalValueLoaded) * 100 : 0.0;

  String get salesPercentageDisplay => '${salesPercentage.toStringAsFixed(1)}%';

  @override
  String toString() {
    return 'UnloadingSummary(id: $id, salesRep: $salesRepName, totalSales: $totalSalesValue, bills: $totalBillCount)';
  }
}
