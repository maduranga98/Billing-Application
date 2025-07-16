// lib/models/loading.dart (Updated with new parser)
import 'dart:convert';
import '../utils/timestamp_parser.dart';
import 'loading_item.dart';
import 'today_route.dart';

class Loading {
  final String loadingId;
  final String businessId;
  final String ownerId;
  final String routeId;
  final String salesRepId;
  final String salesRepName;
  final String salesRepEmail;
  final String salesRepPhone;
  final String status;
  final int itemCount;
  final int totalBags;
  final double totalValue;
  final double totalWeight;
  final List<LoadingItem> items;
  final TodayRoute? todayRoute;
  final DateTime createdAt;
  final String createdBy;
  // Additional fields from your data
  final String? paddyPriceDate;
  final Map<String, String>? todayPaddyPrices;

  Loading({
    required this.loadingId,
    required this.businessId,
    required this.ownerId,
    required this.routeId,
    required this.salesRepId,
    required this.salesRepName,
    required this.salesRepEmail,
    required this.salesRepPhone,
    required this.status,
    required this.itemCount,
    required this.totalBags,
    required this.totalValue,
    required this.totalWeight,
    required this.items,
    this.todayRoute,
    required this.createdAt,
    required this.createdBy,
    this.paddyPriceDate,
    this.todayPaddyPrices,
  });

  factory Loading.fromFirestore(Map<String, dynamic> data, String id) {
    try {
      print('Parsing Loading from Firestore with ID: $id');

      // Handle items array - could be empty or null
      final itemsData = data['items'] as List<dynamic>? ?? [];
      print('Found ${itemsData.length} items in loading data');

      final items =
          itemsData
              .map((item) => LoadingItem.fromMap(item as Map<String, dynamic>))
              .toList();

      // Handle todayRoute - could be null or a map
      TodayRoute? todayRoute;
      if (data['todayRoute'] != null && data['todayRoute'] is Map) {
        print('Parsing todayRoute from data');
        todayRoute = TodayRoute.fromMap(
          data['todayRoute'] as Map<String, dynamic>,
        );
      }

      // Handle todayPaddyPrices
      Map<String, String>? paddyPrices;
      if (data['todayPaddyPrices'] != null && data['todayPaddyPrices'] is Map) {
        final pricesMap = data['todayPaddyPrices'] as Map<String, dynamic>;
        paddyPrices = pricesMap.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }

      print('Parsing createdAt timestamp: ${data['createdAt']}');
      final createdAt = TimestampParser.parseTimestamp(
        data['createdAt'],
        context: 'Loading',
      );

      return Loading(
        loadingId: id, // Use document ID as loadingId
        businessId: data['businessId'] ?? '',
        ownerId: data['ownerId'] ?? '',
        routeId: data['routeId'] ?? '',
        salesRepId: data['salesRepId'] ?? '',
        salesRepName: data['salesRepName'] ?? '',
        salesRepEmail: data['salesRepEmail'] ?? '',
        salesRepPhone: data['salesRepPhone'] ?? '',
        status: data['status'] ?? '',
        itemCount: data['itemCount'] ?? items.length,
        totalBags: _parseInt(data['totalBags']),
        totalValue: _parseDouble(data['totalValue']),
        totalWeight: _parseDouble(data['totalWeight']),
        items: items,
        todayRoute: todayRoute,
        createdAt: createdAt,
        createdBy: data['createdBy'] ?? '',
        paddyPriceDate: data['paddyPriceDate'],
        todayPaddyPrices: paddyPrices,
      );
    } catch (e) {
      print('Error parsing Loading from Firestore: $e');
      print('Data: $data');
      rethrow;
    }
  }

  factory Loading.fromSQLite(Map<String, dynamic> data) {
    try {
      // Parse items from JSON string
      final itemsJson = data['items'] as String? ?? '[]';
      final itemsList = jsonDecode(itemsJson) as List<dynamic>;
      final items =
          itemsList
              .map((item) => LoadingItem.fromMap(item as Map<String, dynamic>))
              .toList();

      // Parse todayRoute from JSON string
      TodayRoute? todayRoute;
      if (data['today_route'] != null) {
        final routeJson = jsonDecode(data['today_route'] as String);
        todayRoute = TodayRoute.fromMap(routeJson as Map<String, dynamic>);
      }

      // Parse todayPaddyPrices from JSON string
      Map<String, String>? paddyPrices;
      if (data['today_paddy_prices'] != null) {
        final pricesJson = jsonDecode(data['today_paddy_prices'] as String);
        paddyPrices = Map<String, String>.from(pricesJson);
      }

      return Loading(
        loadingId: data['loading_id'],
        businessId: data['business_id'],
        ownerId: data['owner_id'],
        routeId: data['route_id'],
        salesRepId: data['sales_rep_id'],
        salesRepName: data['sales_rep_name'],
        salesRepEmail: data['sales_rep_email'],
        salesRepPhone: data['sales_rep_phone'],
        status: data['status'],
        itemCount: data['item_count'],
        totalBags: data['total_bags']?.toInt() ?? 0,
        totalValue: data['total_value']?.toDouble() ?? 0.0,
        totalWeight: data['total_weight']?.toDouble() ?? 0.0,
        items: items,
        todayRoute: todayRoute,
        createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
        createdBy: data['created_by'],
        paddyPriceDate: data['paddy_price_date'],
        todayPaddyPrices: paddyPrices,
      );
    } catch (e) {
      print('Error parsing Loading from SQLite: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toSQLite() {
    return {
      'loading_id': loadingId,
      'business_id': businessId,
      'owner_id': ownerId,
      'route_id': routeId,
      'sales_rep_id': salesRepId,
      'sales_rep_name': salesRepName,
      'sales_rep_email': salesRepEmail,
      'sales_rep_phone': salesRepPhone,
      'status': status,
      'item_count': itemCount,
      'total_bags': totalBags,
      'total_value': totalValue,
      'total_weight': totalWeight,
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
      'today_route':
          todayRoute != null ? jsonEncode(todayRoute!.toMap()) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'created_by': createdBy,
      'paddy_price_date': paddyPriceDate,
      'today_paddy_prices':
          todayPaddyPrices != null ? jsonEncode(todayPaddyPrices) : null,
      'sync_status': 'synced',
    };
  }

  // Helper methods for safe parsing
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Get available items for billing (all items are available)
  List<LoadingItem> get availableItems {
    return items; // All items are available in daily loading
  }

  // Check if loading is prepared and ready for sales
  bool get isReadyForSales {
    return status == 'prepared' && items.isNotEmpty;
  }

  // Get route display information
  String get routeDisplayName {
    return todayRoute?.name ?? 'Unknown Route';
  }

  List<String> get routeAreas {
    return todayRoute?.areas ?? [];
  }

  String get routeAreasText {
    return todayRoute?.areasDisplayText ?? 'No areas';
  }

  // Get total loaded value
  double get totalLoadedValue {
    return totalValue;
  }

  // Get total sold value (0 for now since no sold tracking)
  double get totalSoldValue {
    return 0.0;
  }

  // Get total available value
  double get totalAvailableValue {
    return totalValue;
  }

  // Get paddy prices display text
  String get paddyPricesText {
    if (todayPaddyPrices == null || todayPaddyPrices!.isEmpty) {
      return 'No prices set';
    }
    return todayPaddyPrices!.entries
        .map((entry) => '${entry.key}: Rs.${entry.value}')
        .join(', ');
  }

  @override
  String toString() {
    return 'Loading(loadingId: $loadingId, routeId: $routeId, itemCount: $itemCount, status: $status)';
  }
}
