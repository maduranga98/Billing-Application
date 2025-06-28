// lib/models/loading.dart
import 'dart:convert';
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
  final double totalBags;
  final double totalValue;
  final List<LoadingItem> items;
  final TodayRoute? todayRoute;
  final DateTime createdAt;
  final String createdBy;

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
    required this.items,
    this.todayRoute,
    required this.createdAt,
    required this.createdBy,
  });

  factory Loading.fromFirestore(Map<String, dynamic> data, String id) {
    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items =
        itemsData
            .map((item) => LoadingItem.fromMap(item as Map<String, dynamic>))
            .toList();

    TodayRoute? todayRoute;
    if (data['todayRoute'] != null) {
      todayRoute = TodayRoute.fromMap(
        data['todayRoute'] as Map<String, dynamic>,
      );
    }

    return Loading(
      loadingId: id,
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      routeId: data['routeId'] ?? '',
      salesRepId: data['salesRepId'] ?? '',
      salesRepName: data['salesRepName'] ?? '',
      salesRepEmail: data['salesRepEmail'] ?? '',
      salesRepPhone: data['salesRepPhone'] ?? '',
      status: data['status'] ?? '',
      itemCount: data['itemCount'] ?? 0,
      totalBags: (data['totalBags'] ?? 0).toDouble(),
      totalValue: (data['totalValue'] ?? 0).toDouble(),
      items: items,
      todayRoute: todayRoute,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  factory Loading.fromSQLite(Map<String, dynamic> data) {
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
      totalBags: data['total_bags'],
      totalValue: data['total_value'],
      items: items,
      todayRoute: todayRoute,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
      createdBy: data['created_by'],
    );
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
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
      'today_route':
          todayRoute != null ? jsonEncode(todayRoute!.toMap()) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'created_by': createdBy,
      'sync_status': 'synced',
    };
  }

  // Get available items for billing
  List<LoadingItem> get availableItems {
    return items.where((item) => item.availableQuantity > 0).toList();
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

  @override
  String toString() {
    return 'Loading(loadingId: $loadingId, routeId: $routeId, itemCount: $itemCount, status: $status)';
  }
}
