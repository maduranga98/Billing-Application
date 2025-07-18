import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

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

  // Loading summary
  final int totalItemsLoaded;
  final double totalValueLoaded;

  // Enhanced data - items sold and remaining stock with detailed tracking
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

  // Convert to Firestore format with enhanced structure
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

      // Sales totals
      'totalBillCount': totalBillCount,
      'totalSalesValue': totalSalesValue,
      'totalCashSales': totalCashSales,
      'totalCreditSales': totalCreditSales,
      'totalChequeSales': totalChequeSales,

      // Loading totals
      'totalItemsLoaded': totalItemsLoaded,
      'totalValueLoaded': totalValueLoaded,

      // Enhanced detailed data
      'itemsSold': itemsSold,
      'remainingStock': remainingStock,

      // Enhanced analytics
      'salesAnalytics': _generateSalesAnalytics(),
      'inventoryAnalytics': _generateInventoryAnalytics(),
      'billNumbers': _extractBillNumbers(),
      'productSummary': _generateProductSummary(),

      // Metadata
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'notes': notes,
      'status': status,

      // Version info
      'dataVersion': '2.0',
      'enhancedTracking': true,
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

  // Convert to SQLite format (for local caching)
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
      'items_sold_json': jsonEncode(itemsSold),
      'remaining_stock_json': jsonEncode(remainingStock),
      'created_at': createdAt.millisecondsSinceEpoch,
      'created_by': createdBy,
      'notes': notes,
      'status': status,
      'sync_status': 'synced',
    };
  }

  // Create from SQLite format
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
      totalBillCount: data['total_bill_count'] ?? 0,
      totalSalesValue: (data['total_sales_value'] ?? 0.0).toDouble(),
      totalCashSales: (data['total_cash_sales'] ?? 0.0).toDouble(),
      totalCreditSales: (data['total_credit_sales'] ?? 0.0).toDouble(),
      totalChequeSales: (data['total_cheque_sales'] ?? 0.0).toDouble(),
      totalItemsLoaded: data['total_items_loaded'] ?? 0,
      totalValueLoaded: (data['total_value_loaded'] ?? 0.0).toDouble(),
      itemsSold:
          data['items_sold_json'] != null
              ? List<Map<String, dynamic>>.from(
                jsonDecode(data['items_sold_json']),
              )
              : [],
      remainingStock:
          data['remaining_stock_json'] != null
              ? List<Map<String, dynamic>>.from(
                jsonDecode(data['remaining_stock_json']),
              )
              : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] ?? 0),
      createdBy: data['created_by'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'completed',
    );
  }

  // Generate sales analytics for enhanced tracking
  Map<String, dynamic> _generateSalesAnalytics() {
    int cashBillCount = 0;
    int creditBillCount = 0;
    int chequeBillCount = 0;

    // Count bill numbers by payment type from notes
    final billLines = notes.split('\n');
    for (final line in billLines) {
      if (line.contains('Cash:') && line.contains('bills')) {
        final match = RegExp(r'(\d+)\s+bills').firstMatch(line);
        if (match != null) cashBillCount = int.tryParse(match.group(1)!) ?? 0;
      } else if (line.contains('Credit:') && line.contains('bills')) {
        final match = RegExp(r'(\d+)\s+bills').firstMatch(line);
        if (match != null) creditBillCount = int.tryParse(match.group(1)!) ?? 0;
      } else if (line.contains('Cheque:') && line.contains('bills')) {
        final match = RegExp(r'(\d+)\s+bills').firstMatch(line);
        if (match != null) chequeBillCount = int.tryParse(match.group(1)!) ?? 0;
      }
    }

    return {
      'totalBills': totalBillCount,
      'cashBills': cashBillCount,
      'creditBills': creditBillCount,
      'chequeBills': chequeBillCount,
      'averageBillValue':
          totalBillCount > 0 ? totalSalesValue / totalBillCount : 0.0,
      'salesPercentage':
          totalValueLoaded > 0
              ? (totalSalesValue / totalValueLoaded) * 100
              : 0.0,
      'paymentTypeBreakdown': {
        'cash': {
          'count': cashBillCount,
          'value': totalCashSales,
          'percentage':
              totalSalesValue > 0
                  ? (totalCashSales / totalSalesValue) * 100
                  : 0,
        },
        'credit': {
          'count': creditBillCount,
          'value': totalCreditSales,
          'percentage':
              totalSalesValue > 0
                  ? (totalCreditSales / totalSalesValue) * 100
                  : 0,
        },
        'cheque': {
          'count': chequeBillCount,
          'value': totalChequeSales,
          'percentage':
              totalSalesValue > 0
                  ? (totalChequeSales / totalSalesValue) * 100
                  : 0,
        },
      },
    };
  }

  // Generate inventory analytics
  Map<String, dynamic> _generateInventoryAnalytics() {
    int totalProductsSold = 0;
    int totalProductsRemaining = 0;
    double totalSoldQuantity = 0;
    double totalRemainingQuantity = 0;

    for (final item in itemsSold) {
      totalProductsSold++;
      totalSoldQuantity += (item['quantitySold'] ?? 0).toDouble();
    }

    for (final item in remainingStock) {
      totalProductsRemaining++;
      totalRemainingQuantity += (item['remainingQuantity'] ?? 0).toDouble();
    }

    return {
      'totalProducts': totalProductsSold,
      'productsSold': totalProductsSold,
      'productsWithRemaining': totalProductsRemaining,
      'totalSoldQuantity': totalSoldQuantity,
      'totalRemainingQuantity': totalRemainingQuantity,
      'inventoryTurnover':
          totalItemsLoaded > 0
              ? (totalSoldQuantity / totalItemsLoaded) * 100
              : 0.0,
      'stockEfficiency':
          totalItemsLoaded > 0
              ? ((totalItemsLoaded - totalRemainingQuantity) /
                      totalItemsLoaded) *
                  100
              : 0.0,
    };
  }

  // Extract bill numbers from notes
  List<String> _extractBillNumbers() {
    final billNumbers = <String>[];
    final lines = notes.split('\n');
    bool inBillSection = false;

    for (final line in lines) {
      if (line.contains('BILL NUMBERS')) {
        inBillSection = true;
        continue;
      }
      if (inBillSection && line.trim().isEmpty) {
        break;
      }
      if (inBillSection && line.trim().isNotEmpty && !line.contains('=')) {
        // Extract bill numbers from line (comma separated)
        final numbers = line
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        billNumbers.addAll(numbers);
      }
    }

    return billNumbers;
  }

  // Generate product summary with enhanced details
  Map<String, dynamic> _generateProductSummary() {
    final productSummary = <String, Map<String, dynamic>>{};

    // Combine sold and remaining data for each product
    for (final soldItem in itemsSold) {
      final productCode = soldItem['productCode'] as String;
      productSummary[productCode] = {
        'productCode': productCode,
        'productName': soldItem['productName'],
        'quantitySold': soldItem['quantitySold'] ?? 0,
        'salesValue': soldItem['totalValue'] ?? 0.0,
        'salesCount': soldItem['salesCount'] ?? 0,
        'billNumbers': soldItem['billNumbers'] ?? [],
      };
    }

    // Add remaining stock data
    for (final stockItem in remainingStock) {
      final productCode = stockItem['productCode'] as String;
      if (productSummary.containsKey(productCode)) {
        productSummary[productCode]!.addAll({
          'initialQuantity': stockItem['initialQuantity'] ?? 0,
          'remainingQuantity': stockItem['remainingQuantity'] ?? 0,
          'remainingValue': stockItem['remainingValue'] ?? 0.0,
          'salesPercentage': stockItem['salesPercentage'] ?? 0.0,
          'pricePerKg': stockItem['pricePerKg'] ?? 0.0,
          'bagSize': stockItem['bagSize'] ?? 0.0,
        });
      } else {
        // Product was loaded but not sold
        productSummary[productCode] = {
          'productCode': productCode,
          'productName': stockItem['productName'],
          'quantitySold': 0,
          'salesValue': 0.0,
          'salesCount': 0,
          'billNumbers': [],
          'initialQuantity': stockItem['initialQuantity'] ?? 0,
          'remainingQuantity': stockItem['remainingQuantity'] ?? 0,
          'remainingValue': stockItem['remainingValue'] ?? 0.0,
          'salesPercentage': 0.0,
          'pricePerKg': stockItem['pricePerKg'] ?? 0.0,
          'bagSize': stockItem['bagSize'] ?? 0.0,
        };
      }
    }

    return {
      'products': productSummary.values.toList(),
      'totalProducts': productSummary.length,
      'soldProducts':
          productSummary.values.where((p) => p['quantitySold'] > 0).length,
      'unsoldProducts':
          productSummary.values.where((p) => p['quantitySold'] == 0).length,
    };
  }

  // Enhanced display helpers
  String get dateDisplay =>
      '${unloadingDate.day}/${unloadingDate.month}/${unloadingDate.year}';
  String get salesValueDisplay => 'Rs.${totalSalesValue.toStringAsFixed(2)}';
  String get cashSalesDisplay => 'Rs.${totalCashSales.toStringAsFixed(2)}';
  String get creditSalesDisplay => 'Rs.${totalCreditSales.toStringAsFixed(2)}';
  String get chequeSalesDisplay => 'Rs.${totalChequeSales.toStringAsFixed(2)}';
  String get loadedValueDisplay => 'Rs.${totalValueLoaded.toStringAsFixed(2)}';

  double get salesPercentage =>
      totalValueLoaded > 0 ? (totalSalesValue / totalValueLoaded) * 100 : 0.0;
  String get salesPercentageDisplay => '${salesPercentage.toStringAsFixed(1)}%';

  double get averageBillValue =>
      totalBillCount > 0 ? totalSalesValue / totalBillCount : 0.0;
  String get averageBillValueDisplay =>
      'Rs.${averageBillValue.toStringAsFixed(2)}';

  // Get total sold quantity across all products
  int get totalSoldQuantity {
    return itemsSold.fold(
      0,
      (sum, item) => sum + (item['quantitySold'] as int? ?? 0),
    );
  }

  // Get total remaining quantity across all products
  int get totalRemainingQuantity {
    return remainingStock.fold(
      0,
      (sum, item) => sum + (item['remainingQuantity'] as int? ?? 0),
    );
  }

  // Get bill numbers from items sold data
  List<String> get billNumbers {
    final allBillNumbers = <String>{};
    for (final item in itemsSold) {
      final billNums = item['billNumbers'] as List<dynamic>? ?? [];
      allBillNumbers.addAll(billNums.cast<String>());
    }
    return allBillNumbers.toList()..sort();
  }

  // Get top selling products
  List<Map<String, dynamic>> get topSellingProducts {
    final sorted = List<Map<String, dynamic>>.from(itemsSold);
    sorted.sort(
      (a, b) =>
          (b['totalValue'] as double).compareTo(a['totalValue'] as double),
    );
    return sorted.take(5).toList();
  }

  // Get products with high remaining stock
  List<Map<String, dynamic>> get highRemainingStock {
    final filtered =
        remainingStock.where((item) {
          final remaining = item['remainingQuantity'] as int? ?? 0;
          final initial = item['initialQuantity'] as int? ?? 0;
          return initial > 0 &&
              (remaining / initial) > 0.5; // More than 50% remaining
        }).toList();

    filtered.sort(
      (a, b) => (b['remainingQuantity'] as int).compareTo(
        a['remainingQuantity'] as int,
      ),
    );
    return filtered;
  }

  // Get comprehensive summary for reports
  Map<String, dynamic> getComprehensiveSummary() {
    return {
      'basic': {
        'date': dateDisplay,
        'route': routeName,
        'salesRep': salesRepName,
        'totalBills': totalBillCount,
        'totalSales': salesValueDisplay,
        'salesPercentage': salesPercentageDisplay,
      },
      'sales': {
        'cash': {'count': _getCashBillCount(), 'value': cashSalesDisplay},
        'credit': {'count': _getCreditBillCount(), 'value': creditSalesDisplay},
        'cheque': {'count': _getChequeBillCount(), 'value': chequeSalesDisplay},
        'average': averageBillValueDisplay,
      },
      'inventory': {
        'loaded': {'quantity': totalItemsLoaded, 'value': loadedValueDisplay},
        'sold': {'quantity': totalSoldQuantity, 'value': salesValueDisplay},
        'remaining': {
          'quantity': totalRemainingQuantity,
          'value': _getRemainingValueDisplay(),
        },
      },
      'performance': {
        'salesEfficiency': salesPercentageDisplay,
        'inventoryTurnover':
            '${((totalSoldQuantity / totalItemsLoaded) * 100).toStringAsFixed(1)}%',
        'averagePerBill': averageBillValueDisplay,
      },
      'bills': billNumbers,
      'topProducts':
          topSellingProducts
              .take(3)
              .map((p) => '${p['productName']}: ${p['quantitySold']} bags')
              .toList(),
    };
  }

  // Private helpers for bill counts
  int _getCashBillCount() {
    final analytics = _generateSalesAnalytics();
    return analytics['cashBills'] ?? 0;
  }

  int _getCreditBillCount() {
    final analytics = _generateSalesAnalytics();
    return analytics['creditBills'] ?? 0;
  }

  int _getChequeBillCount() {
    final analytics = _generateSalesAnalytics();
    return analytics['chequeBills'] ?? 0;
  }

  String _getRemainingValueDisplay() {
    final totalRemaining = remainingStock.fold(
      0.0,
      (sum, item) => sum + (item['remainingValue'] as double? ?? 0.0),
    );
    return 'Rs.${totalRemaining.toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'UnloadingSummary(id: $id, date: $dateDisplay, salesRep: $salesRepName, bills: $totalBillCount, sales: $salesValueDisplay, route: $routeName)';
  }
}
