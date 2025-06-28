// lib/providers/loading_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/loading.dart';
import '../models/loading_item.dart';
import '../models/user_session.dart';
import '../services/loading/loading_service.dart';
import '../services/auth/auth_service.dart';

enum LoadingState { idle, loading, loaded, noLoading, error }

class LoadingProvider with ChangeNotifier {
  Loading? _currentLoading;
  List<LoadingItem> _availableItems = [];
  List<LoadingItem> _searchResults = [];

  LoadingState _loadingState = LoadingState.idle;
  String _errorMessage = '';
  String _lastSearchQuery = '';
  DateTime? _lastUpdateTime;

  // Route context from loading
  String? _currentRouteId;
  String? _currentRouteName;
  List<String> _currentRouteAreas = [];

  // Getters
  Loading? get currentLoading => _currentLoading;
  List<LoadingItem> get availableItems => _availableItems;
  List<LoadingItem> get searchResults => _searchResults;
  LoadingState get loadingState => _loadingState;
  String get errorMessage => _errorMessage;
  String get lastSearchQuery => _lastSearchQuery;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  // Route context getters
  String? get currentRouteId => _currentRouteId;
  String? get currentRouteName => _currentRouteName;
  List<String> get currentRouteAreas => _currentRouteAreas;
  bool get hasRouteContext =>
      _currentRouteId != null && _currentRouteId!.isNotEmpty;

  bool get isLoading => _loadingState == LoadingState.loading;
  bool get hasError => _loadingState == LoadingState.error;
  bool get hasLoading =>
      _loadingState == LoadingState.loaded && _currentLoading != null;
  bool get hasNoLoading => _loadingState == LoadingState.noLoading;

  // Statistics
  int get totalItems => _currentLoading?.itemCount ?? 0;
  double get totalValue =>
      _availableItems.fold(0.0, (sum, item) => sum + item.totalValue);
  double get totalLoadedValue => _currentLoading?.totalValue ?? 0.0;
  int get availableItemCount => _availableItems.length;
  int get lowStockCount =>
      _availableItems.where((item) => item.isLowStock).length;
  int get outOfStockCount =>
      _currentLoading?.items.where((item) => item.isOutOfStock).length ?? 0;

  // Route display information
  String get routeDisplayName => _currentRouteName ?? 'Unknown Route';
  String get routeAreasText =>
      _currentRouteAreas.isNotEmpty
          ? _currentRouteAreas.join(', ')
          : 'No areas defined';

  String get routeFullDisplayText =>
      hasRouteContext
          ? '$routeDisplayName (${routeAreasText})'
          : 'No route assigned';

  // Load today's loading and extract route context
  Future<void> loadTodaysLoading(UserSession session) async {
    _loadingState = LoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _currentLoading = await LoadingService.getTodaysLoading(session);

      if (_currentLoading != null) {
        _availableItems = _currentLoading!.availableItems;
        _loadingState = LoadingState.loaded;
        _lastUpdateTime = DateTime.now();

        // Extract route context from loading
        await _extractRouteContext(_currentLoading!, session);
      } else {
        _availableItems = [];
        _loadingState = LoadingState.noLoading;
        _clearRouteContext();
      }

      _errorMessage = '';
    } catch (e) {
      _loadingState = LoadingState.error;
      _errorMessage = e.toString();
      _clearRouteContext();
      print('Error loading today\'s loading: $e');
    }

    notifyListeners();
  }

  // Extract and update route context from loading
  Future<void> _extractRouteContext(
    Loading loading,
    UserSession session,
  ) async {
    try {
      _currentRouteId = loading.routeId;

      if (loading.todayRoute != null) {
        // Route info is already loaded in loading
        _currentRouteName = loading.todayRoute!.name;
        _currentRouteAreas = loading.todayRoute!.areas;
      } else if (loading.routeId.isNotEmpty) {
        // Load route info separately
        final routeInfo = await LoadingService.getRouteInfo(
          session,
          loading.routeId,
        );
        if (routeInfo != null) {
          _currentRouteName = routeInfo.name;
          _currentRouteAreas = routeInfo.areas;
        }
      }

      // Update user session with route context
      await _updateSessionWithRouteContext(session);
    } catch (e) {
      print('Error extracting route context: $e');
      _clearRouteContext();
    }
  }

  Color getItemStatusColor(LoadingItem item) {
    if (item.isOutOfStock) {
      return Colors.red.shade600;
    } else if (item.isLowStock) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  // Get item status text
  String getItemStatusText(LoadingItem item) {
    if (item.isOutOfStock) {
      return 'Out of Stock';
    } else if (item.isLowStock) {
      return 'Low Stock';
    } else {
      return 'Available';
    }
  }

  // Update user session with current route context
  Future<void> _updateSessionWithRouteContext(UserSession session) async {
    if (!hasRouteContext) return;

    try {
      await AuthService.updateSessionWithRoute(
        routeId: _currentRouteId!,
        routeName: _currentRouteName ?? '',
        routeAreas: _currentRouteAreas,
      );
    } catch (e) {
      print('Error updating session with route context: $e');
    }
  }

  // Clear route context
  void _clearRouteContext() {
    _currentRouteId = null;
    _currentRouteName = null;
    _currentRouteAreas = [];
  }

  // Refresh loading data and route context
  Future<void> refreshLoading(UserSession session) async {
    await loadTodaysLoading(session);
  }

  // Search items in current loading
  Future<void> searchItems(UserSession session, String query) async {
    _lastSearchQuery = query;

    try {
      _searchResults = await LoadingService.searchItems(
        session: session,
        query: query,
      );
    } catch (e) {
      _searchResults = [];
      print('Error searching items: $e');
    }

    notifyListeners();
  }

  // Clear search
  void clearSearch() {
    _searchResults = [];
    _lastSearchQuery = '';
    notifyListeners();
  }

  // Update sold quantities (when creating bills)
  Future<bool> updateSoldQuantities({
    required UserSession session,
    required Map<String, int> itemQuantities, // productId -> quantity sold
  }) async {
    if (_currentLoading == null) return false;

    try {
      final success = await LoadingService.updateSoldQuantities(
        session: session,
        loadingId: _currentLoading!.loadingId,
        itemQuantities: itemQuantities,
      );

      if (success) {
        // Update local state
        final updatedItems = <LoadingItem>[];

        for (final item in _currentLoading!.items) {
          if (itemQuantities.containsKey(item.productId)) {
            final soldQuantity = itemQuantities[item.productId]!;
            updatedItems.add(item.copyWithSoldQuantity(soldQuantity));
          } else {
            updatedItems.add(item);
          }
        }

        // Update current loading with new items
        _currentLoading = Loading(
          loadingId: _currentLoading!.loadingId,
          businessId: _currentLoading!.businessId,
          ownerId: _currentLoading!.ownerId,
          routeId: _currentLoading!.routeId,
          salesRepId: _currentLoading!.salesRepId,
          salesRepName: _currentLoading!.salesRepName,
          salesRepEmail: _currentLoading!.salesRepEmail,
          salesRepPhone: _currentLoading!.salesRepPhone,
          status: _currentLoading!.status,
          itemCount: _currentLoading!.itemCount,
          totalBags: _currentLoading!.totalBags,
          totalValue: _currentLoading!.totalValue,
          items: updatedItems,
          todayRoute: _currentLoading!.todayRoute,
          createdAt: _currentLoading!.createdAt,
          createdBy: _currentLoading!.createdBy,
        );

        // Update available items
        _availableItems = _currentLoading!.availableItems;

        notifyListeners();
      }

      return success;
    } catch (e) {
      print('Error updating sold quantities: $e');
      return false;
    }
  }

  // Get item by product ID
  LoadingItem? getItemByProductId(String productId) {
    if (_currentLoading == null) return null;

    try {
      return _currentLoading!.items.firstWhere(
        (item) => item.productId == productId,
      );
    } catch (e) {
      return null;
    }
  }

  // Check if sufficient quantity is available
  bool hasSufficientQuantity(String productId, int requiredQuantity) {
    final item = getItemByProductId(productId);
    return item != null && item.availableQuantity >= requiredQuantity;
  }

  // Get items by category
  Map<String, List<LoadingItem>> get itemsByCategory {
    final Map<String, List<LoadingItem>> categorizedItems = {};

    for (final item in _availableItems) {
      final category = item.category.isEmpty ? 'Uncategorized' : item.category;
      if (!categorizedItems.containsKey(category)) {
        categorizedItems[category] = [];
      }
      categorizedItems[category]!.add(item);
    }

    return categorizedItems;
  }

  // Get all categories
  List<String> get categories {
    return itemsByCategory.keys.toList()..sort();
  }

  // Get low stock items
  List<LoadingItem> get lowStockItems {
    return _availableItems.where((item) => item.isLowStock).toList();
  }

  // Get out of stock items
  List<LoadingItem> get outOfStockItems {
    return _currentLoading?.items.where((item) => item.isOutOfStock).toList() ??
        [];
  }

  // Validate items before bill creation
  Future<Map<String, dynamic>> validateItemsForBill({
    required UserSession session,
    required Map<String, int> itemQuantities, // productId -> required quantity
  }) async {
    try {
      return await LoadingService.validateItemsForBill(
        session: session,
        itemQuantities: itemQuantities,
      );
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
        'insufficientItems': [],
        'unavailableItems': [],
      };
    }
  }

  // Get loading statistics with route context
  Map<String, dynamic> getLoadingStatistics() {
    if (_currentLoading == null) {
      return {
        'hasLoading': false,
        'totalItems': 0,
        'totalValue': 0.0,
        'availableItems': 0,
        'soldItems': 0,
        'routeName': 'No Loading',
        'routeId': null,
        'routeAreas': <String>[],
        'status': 'No Loading',
      };
    }

    final soldItems =
        _currentLoading!.items.where((item) => item.soldQuantity > 0).length;

    return {
      'hasLoading': true,
      'totalItems': totalItems,
      'totalValue': totalValue,
      'totalLoadedValue': totalLoadedValue,
      'availableItems': availableItemCount,
      'soldItems': soldItems,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
      'routeName': routeDisplayName,
      'routeId': _currentRouteId,
      'routeAreas': _currentRouteAreas,
      'routeAreasText': routeAreasText,
      'routeFullDisplay': routeFullDisplayText,
      'status': _currentLoading!.status,
    };
  }

  // Get sales progress (percentage of items sold)
  double get salesProgress {
    if (_currentLoading == null || _currentLoading!.totalValue == 0) return 0.0;

    final totalSoldValue = _currentLoading!.items.fold(0.0, (sum, item) {
      return sum + (item.soldQuantity * item.unitPrice);
    });

    return (totalSoldValue / _currentLoading!.totalValue) * 100;
  }

  // Check if loading is ready for sales
  bool get isReadyForSales {
    return _currentLoading?.isReadyForSales ?? false;
  }

  // Get summary text for dashboard
  String get loadingSummaryText {
    if (_currentLoading == null) {
      return 'No loading assigned for today';
    }

    return '$availableItemCount items • $routeDisplayName';
  }

  // Get route context for other operations
  Map<String, dynamic>? get routeContext {
    if (!hasRouteContext) return null;

    return {
      'routeId': _currentRouteId,
      'routeName': _currentRouteName,
      'routeAreas': _currentRouteAreas,
    };
  }

  // Reset provider state
  void reset() {
    _currentLoading = null;
    _availableItems = [];
    _searchResults = [];
    _loadingState = LoadingState.idle;
    _errorMessage = '';
    _lastSearchQuery = '';
    _lastUpdateTime = null;
    _clearRouteContext();
    notifyListeners();
  }

  // Clear error and retry
  void clearErrorAndRetry(UserSession session) {
    _errorMessage = '';
    loadTodaysLoading(session);
  }

  // Check if items need attention (low stock or out of stock)
  bool get hasItemsNeedingAttention {
    return lowStockCount > 0 || outOfStockCount > 0;
  }

  // Get items needing attention
  List<LoadingItem> get itemsNeedingAttention {
    if (_currentLoading == null) return [];

    return _currentLoading!.items
        .where((item) => item.isLowStock || item.isOutOfStock)
        .toList();
  }
}
