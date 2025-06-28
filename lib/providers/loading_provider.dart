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

  // Statistics (updated for real data structure)
  int get totalItems => _currentLoading?.itemCount ?? 0;
  int get totalBags => _currentLoading?.totalBags ?? 0;
  double get totalValue => _currentLoading?.totalValue ?? 0.0;
  double get totalWeight => _currentLoading?.totalWeight ?? 0.0;
  int get availableItemCount => _availableItems.length;

  // No low stock or out of stock concepts for daily loading
  int get lowStockCount => 0;
  int get outOfStockCount => 0;
  bool get hasItemsNeedingAttention =>
      false; // No alerts needed for daily loading

  // Sales progress (0% since no sold tracking in current structure)
  double get salesProgress => 0.0;

  // Route display information
  String get routeDisplayName => _currentRouteName ?? 'Unknown Route';
  String get routeAreasText =>
      _currentRouteAreas.isNotEmpty
          ? _currentRouteAreas.join(', ')
          : 'No areas defined';
  String get routeFullDisplayText =>
      hasRouteContext
          ? '$routeDisplayName ($routeAreasText)'
          : 'No Route Assigned';

  // Get items by category (product type)
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

  // Get low stock items (empty for daily loading)
  List<LoadingItem> get lowStockItems {
    return [];
  }

  // Get out of stock items (empty for daily loading)
  List<LoadingItem> get outOfStockItems {
    return [];
  }

  // Get item status color (simplified for daily loading)
  Color getItemStatusColor(LoadingItem item) {
    return Colors.green.shade600; // All items are available
  }

  // Get item status text (simplified for daily loading)
  String getItemStatusText(LoadingItem item) {
    return 'Available';
  }

  // Load today's loading for the sales rep
  Future<void> loadTodaysLoading(UserSession session) async {
    _loadingState = LoadingState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      print(
        'LoadingProvider: Loading today\'s loading for ${session.employeeId}',
      );

      final loading = await LoadingService.getTodaysLoading(session);

      if (loading != null) {
        _currentLoading = loading;
        _availableItems = loading.availableItems;
        _lastUpdateTime = DateTime.now();
        _loadingState = LoadingState.loaded;

        // Update route context
        _updateRouteContext(loading);

        print(
          'LoadingProvider: Loading loaded successfully with ${loading.items.length} items',
        );
      } else {
        _currentLoading = null;
        _availableItems = [];
        _loadingState = LoadingState.noLoading;
        _clearRouteContext();

        print('LoadingProvider: No loading found');
      }
    } catch (e) {
      _loadingState = LoadingState.error;
      _errorMessage = e.toString();
      _clearRouteContext();

      print('LoadingProvider: Error loading: $e');
    }

    notifyListeners();
  }

  // Update route context from loading
  void _updateRouteContext(Loading loading) {
    try {
      _currentRouteId = loading.routeId;
      _currentRouteName = loading.todayRoute?.name ?? loading.routeDisplayName;
      _currentRouteAreas = loading.routeAreas;

      // Update session with route context if needed
      AuthService.updateSessionWithRoute(
        routeId: _currentRouteId ?? '',
        routeName: _currentRouteName,
        routeAreas: _currentRouteAreas,
      );
    } catch (e) {
      print('Error updating route context: $e');
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

  // Clear error and retry loading
  Future<void> clearErrorAndRetry(UserSession session) async {
    _errorMessage = '';
    await loadTodaysLoading(session);
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

  // Check if sufficient quantity is available (updated for bag-based system)
  bool hasSufficientQuantity(String productId, int requiredBags) {
    final item = getItemByProductId(productId);
    return item != null && item.availableQuantity >= requiredBags;
  }

  // Get loading statistics with route context
  Map<String, dynamic> getLoadingStatistics() {
    if (_currentLoading == null) {
      return {
        'hasLoading': false,
        'totalItems': 0,
        'totalBags': 0,
        'totalValue': 0.0,
        'totalWeight': 0.0,
        'availableItems': 0,
        'routeName': 'No Loading',
        'routeId': null,
        'routeAreas': <String>[],
        'status': 'No Loading',
      };
    }

    return {
      'hasLoading': true,
      'totalItems': totalItems,
      'totalBags': totalBags,
      'totalValue': totalValue,
      'totalWeight': totalWeight,
      'availableItems': availableItemCount,
      'routeName': routeDisplayName,
      'routeId': _currentRouteId,
      'routeAreas': _currentRouteAreas,
      'routeAreasText': routeAreasText,
      'routeFullDisplay': routeFullDisplayText,
      'status': _currentLoading!.status,
    };
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

    return '$availableItemCount items • $totalBags bags • $routeDisplayName';
  }

  // Get route context for other operations
  Map<String, dynamic>? get routeContext {
    if (!hasRouteContext) return null;

    return {
      'routeId': _currentRouteId,
      'routeName': _currentRouteName,
      'routeAreas': _currentRouteAreas,
      'routeAreasText': routeAreasText,
      'routeFullDisplay': routeFullDisplayText,
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

  // Force notification (for debugging)
  void forceNotify() {
    notifyListeners();
  }
}
