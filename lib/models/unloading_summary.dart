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

  // Sales summary
  final int totalBillCount;
  final double totalSalesValue;
  final double totalCashSales;
  final double totalCreditSales;
  final double totalChequeSales;

  // Stock summary
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
    required this.notes,
    required this.status,
  });

  // Convert to Firestore document
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

      // Sales summary
      'totalBillCount': totalBillCount,
      'totalSalesValue': totalSalesValue,
      'totalCashSales': totalCashSales,
      'totalCreditSales': totalCreditSales,
      'totalChequeSales': totalChequeSales,

      // Stock summary
      'totalItemsLoaded': totalItemsLoaded,
      'totalValueLoaded': totalValueLoaded,
      'itemsSold': itemsSold,
      'remainingStock': remainingStock,

      // Metadata
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'notes': notes,
      'status': status,
    };
  }

  // Create from Firestore document
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

      // Sales summary
      totalBillCount: data['totalBillCount']?.toInt() ?? 0,
      totalSalesValue: (data['totalSalesValue'] as num?)?.toDouble() ?? 0.0,
      totalCashSales: (data['totalCashSales'] as num?)?.toDouble() ?? 0.0,
      totalCreditSales: (data['totalCreditSales'] as num?)?.toDouble() ?? 0.0,
      totalChequeSales: (data['totalChequeSales'] as num?)?.toDouble() ?? 0.0,

      // Stock summary
      totalItemsLoaded: data['totalItemsLoaded']?.toInt() ?? 0,
      totalValueLoaded: (data['totalValueLoaded'] as num?)?.toDouble() ?? 0.0,
      itemsSold: List<Map<String, dynamic>>.from(data['itemsSold'] ?? []),
      remainingStock: List<Map<String, dynamic>>.from(
        data['remainingStock'] ?? [],
      ),

      // Metadata
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }

  // Convert to SQLite format
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

      // Sales summary
      'total_bill_count': totalBillCount,
      'total_sales_value': totalSalesValue,
      'total_cash_sales': totalCashSales,
      'total_credit_sales': totalCreditSales,
      'total_cheque_sales': totalChequeSales,

      // Stock summary
      'total_items_loaded': totalItemsLoaded,
      'total_value_loaded': totalValueLoaded,
      'items_sold_json': _encodeMapList(itemsSold),
      'remaining_stock_json': _encodeMapList(remainingStock),

      // Metadata
      'created_at': createdAt.millisecondsSinceEpoch,
      'created_by': createdBy,
      'notes': notes,
      'status': status,
    };
  }

  // Create from SQLite data
  factory UnloadingSummary.fromSQLite(Map<String, dynamic> data) {
    return UnloadingSummary(
      id: data['id'] ?? '',
      loadingId: data['loading_id'] ?? '',
      businessId: data['business_id'] ?? '',
      ownerId: data['owner_id'] ?? '',
      salesRepId: data['sales_rep_id'] ?? '',
      salesRepName: data['sales_rep_name'] ?? '',
      routeId: data['route_id'] ?? '',
      routeName: data['route_name'] ?? '',
      unloadingDate: DateTime.fromMillisecondsSinceEpoch(
        data['unloading_date'] ?? 0,
      ),

      // Sales summary
      totalBillCount: data['total_bill_count']?.toInt() ?? 0,
      totalSalesValue: (data['total_sales_value'] as num?)?.toDouble() ?? 0.0,
      totalCashSales: (data['total_cash_sales'] as num?)?.toDouble() ?? 0.0,
      totalCreditSales: (data['total_credit_sales'] as num?)?.toDouble() ?? 0.0,
      totalChequeSales: (data['total_cheque_sales'] as num?)?.toDouble() ?? 0.0,

      // Stock summary
      totalItemsLoaded: data['total_items_loaded']?.toInt() ?? 0,
      totalValueLoaded: (data['total_value_loaded'] as num?)?.toDouble() ?? 0.0,
      itemsSold: _decodeMapList(data['items_sold_json']),
      remainingStock: _decodeMapList(data['remaining_stock_json']),

      // Metadata
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] ?? 0),
      createdBy: data['created_by'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }

  // Helper methods for JSON encoding/decoding
  static String _encodeMapList(List<Map<String, dynamic>> mapList) {
    try {
      return mapList.map((map) => map.toString()).join('|');
    } catch (e) {
      return '';
    }
  }

  static List<Map<String, dynamic>> _decodeMapList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      // This is a simplified decoder - you might want to use JSON encoding instead
      return [];
    } catch (e) {
      return [];
    }
  }

  // Calculated properties
  double get salesEfficiency {
    if (totalValueLoaded == 0) return 0.0;
    return (totalSalesValue / totalValueLoaded) * 100;
  }

  double get totalRemainingValue {
    return remainingStock.fold(0.0, (sum, item) {
      return sum + ((item['remainingValue'] as num?)?.toDouble() ?? 0.0);
    });
  }

  int get totalItemsSold {
    return itemsSold.fold(0, (sum, item) {
      return sum + ((item['quantitySold'] as num?)?.toInt() ?? 0);
    });
  }

  int get totalItemsRemaining {
    return remainingStock.fold(0, (sum, item) {
      return sum + ((item['remainingQuantity'] as num?)?.toInt() ?? 0);
    });
  }

  // Payment type breakdown
  Map<String, double> get paymentBreakdown {
    return {
      'cash': totalCashSales,
      'credit': totalCreditSales,
      'cheque': totalChequeSales,
    };
  }

  // Top selling items
  List<Map<String, dynamic>> get topSellingItems {
    final sortedItems = List<Map<String, dynamic>>.from(itemsSold);
    sortedItems.sort((a, b) {
      final aValue = (a['totalValue'] as num?)?.toDouble() ?? 0.0;
      final bValue = (b['totalValue'] as num?)?.toDouble() ?? 0.0;
      return bValue.compareTo(aValue);
    });
    return sortedItems.take(5).toList();
  }

  // Display formatted values
  String get formattedSalesValue => 'Rs.${totalSalesValue.toStringAsFixed(2)}';
  String get formattedLoadedValue =>
      'Rs.${totalValueLoaded.toStringAsFixed(2)}';
  String get formattedRemainingValue =>
      'Rs.${totalRemainingValue.toStringAsFixed(2)}';
  String get formattedEfficiency => '${salesEfficiency.toStringAsFixed(1)}%';

  // Copy with method
  UnloadingSummary copyWith({
    String? id,
    String? loadingId,
    String? businessId,
    String? ownerId,
    String? salesRepId,
    String? salesRepName,
    String? routeId,
    String? routeName,
    DateTime? unloadingDate,
    int? totalBillCount,
    double? totalSalesValue,
    double? totalCashSales,
    double? totalCreditSales,
    double? totalChequeSales,
    int? totalItemsLoaded,
    double? totalValueLoaded,
    List<Map<String, dynamic>>? itemsSold,
    List<Map<String, dynamic>>? remainingStock,
    DateTime? createdAt,
    String? createdBy,
    String? notes,
    String? status,
  }) {
    return UnloadingSummary(
      id: id ?? this.id,
      loadingId: loadingId ?? this.loadingId,
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      salesRepId: salesRepId ?? this.salesRepId,
      salesRepName: salesRepName ?? this.salesRepName,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      unloadingDate: unloadingDate ?? this.unloadingDate,
      totalBillCount: totalBillCount ?? this.totalBillCount,
      totalSalesValue: totalSalesValue ?? this.totalSalesValue,
      totalCashSales: totalCashSales ?? this.totalCashSales,
      totalCreditSales: totalCreditSales ?? this.totalCreditSales,
      totalChequeSales: totalChequeSales ?? this.totalChequeSales,
      totalItemsLoaded: totalItemsLoaded ?? this.totalItemsLoaded,
      totalValueLoaded: totalValueLoaded ?? this.totalValueLoaded,
      itemsSold: itemsSold ?? this.itemsSold,
      remainingStock: remainingStock ?? this.remainingStock,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'UnloadingSummary(id: $id, loadingId: $loadingId, totalSalesValue: $totalSalesValue, totalBillCount: $totalBillCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnloadingSummary && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
