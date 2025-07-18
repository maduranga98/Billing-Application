// lib/providers/outlet_provider.dart
// Fixed version to work with the updated outlet service

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lumorabiz_billing/services/local/database_service.dart';
import '../models/outlet.dart';
import '../models/user_session.dart';
import '../services/outlet/outlet_service.dart'; // FIXED: Use correct import

class OutletProvider with ChangeNotifier {
  List<Outlet> _outlets = [];
  List<Outlet> _filteredOutlets = [];
  bool _isLoading = false;
  bool _isConnected = true;
  int _offlineOutletCount = 0;
  String _searchQuery = '';
  String _selectedOutletType = 'All';
  String? _errorMessage;

  // Getters
  List<Outlet> get outlets => _filteredOutlets;
  List<Outlet> get allOutlets => _outlets;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  int get offlineOutletCount => _offlineOutletCount;
  String get searchQuery => _searchQuery;
  String get selectedOutletType => _selectedOutletType;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String _selectedRouteId = '';
  String get selectedRouteId => _selectedRouteId;

  // Outlet types for filtering
  List<String> get outletTypes => [
    'All',
    'Retail',
    'Wholesale',
    'Hotel',
    'Restaurant',
    'Supermarket',
    'Pharmacy',
    'Hardware',
    'Other',
  ];

  OutletProvider() {
    _initializeConnectivity();
  }

  void _initializeConnectivity() {
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final wasConnected = _isConnected;
      _isConnected = !results.contains(ConnectivityResult.none);

      if (!wasConnected && _isConnected) {
        // Just came online, sync pending outlets and refresh data
        _syncPendingOutlets();
      }

      if (!_isLoading) {
        notifyListeners();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isConnected = !connectivityResult.contains(ConnectivityResult.none);
  }

  // FIXED: Load all outlets using correct service method
  Future<void> loadOutlets(UserSession userSession) async {
    try {
      print(
        'OutletProvider: Loading outlets for session: ${userSession.employeeId}',
      );
      _setLoading(true);
      _clearError();

      // FIXED: Use the correct method name from OutletService
      _outlets = await OutletService.getOutlets(userSession);
      print('OutletProvider: Loaded ${_outlets.length} outlets');

      // Load offline outlet count
      await _loadOfflineOutletCount();

      // Apply current filters
      _applyFilters();

      print(
        'OutletProvider: After filtering, showing ${_filteredOutlets.length} outlets',
      );
    } catch (e) {
      _setError('Failed to load outlets: $e');
      print('OutletProvider: Error loading outlets: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load offline outlet count
  Future<void> _loadOfflineOutletCount() async {
    try {
      // Count outlets with sync_status = 'pending' from local database
      final db = await DatabaseService().database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM outlets WHERE sync_status = ?',
        ['pending'],
      );
      _offlineOutletCount = result.first['count'] as int? ?? 0;
      print('OutletProvider: Found $_offlineOutletCount offline outlets');
    } catch (e) {
      print('OutletProvider: Error getting offline outlet count: $e');
      _offlineOutletCount = 0;
    }
  }

  Future<void> syncOfflineOutlets(UserSession userSession) async {
    try {
      print('OutletProvider: Syncing offline outlets...');
      _setLoading(true);
      _clearError();

      // Call the service method to sync pending outlets
      await OutletService.syncPendingOutlets(userSession);

      // Reload outlets to reflect the sync status changes
      await loadOutlets(userSession);

      print('OutletProvider: Offline outlets synced successfully');
    } catch (e) {
      _setError('Failed to sync offline outlets: $e');
      print('OutletProvider: Error syncing offline outlets: $e');
      rethrow; // Let the UI handle the error
    } finally {
      _setLoading(false);
    }
  }

  // Refresh outlets
  Future<void> refreshOutlets([UserSession? userSession]) async {
    if (userSession != null) {
      print('OutletProvider: Refreshing outlets...');
      await loadOutlets(userSession);
    }
  }

  // Add new outlet
  Future<bool> addOutlet({
    required Map<String, dynamic> outletData,
    required UserSession userSession,
    String? imageBase64,
    String? routeId, // ADDED: Route ID parameter
    String? routeName, // ADDED: Route Name parameter
  }) async {
    try {
      print(
        'OutletProvider: Adding outlet: ${outletData['outletName']} to route: $routeName',
      );
      _setLoading(true);
      _clearError();

      // UPDATED: Pass route information to service
      final outletId = await OutletService.addOutlet(
        session: userSession,
        outletData: outletData,
        imageBase64: imageBase64,
        routeId: routeId,
        routeName: routeName,
      );

      print('OutletProvider: Outlet added successfully with ID: $outletId');

      // Reload outlets to show the new one
      await loadOutlets(userSession);
      return true;
    } catch (e) {
      _setError('Failed to add outlet: $e');
      print('OutletProvider: Error adding outlet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadOutletsByRoute(
    UserSession userSession,
    String routeId,
  ) async {
    try {
      print('OutletProvider: Loading outlets for route: $routeId');
      _setLoading(true);
      _clearError();

      _outlets = await OutletService.getOutletsByRoute(userSession, routeId);
      print(
        'OutletProvider: Loaded ${_outlets.length} outlets for route: $routeId',
      );

      await _loadOfflineOutletCount();
      _applyFilters();

      print(
        'OutletProvider: After filtering, showing ${_filteredOutlets.length} outlets',
      );
    } catch (e) {
      _setError('Failed to load outlets for route: $e');
      print('OutletProvider: Error loading outlets for route: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, String>>> getAvailableRoutes(
    UserSession userSession,
  ) async {
    try {
      return await OutletService.getAvailableRoutes(userSession);
    } catch (e) {
      print('OutletProvider: Error getting available routes: $e');
      return [];
    }
  }

  // ADDED: Filter outlets by route
  void filterByRoute(String routeId) {
    _selectedRouteId = routeId;
    _applyFilters();
    notifyListeners();
  }

  // Sync pending outlets when coming online
  Future<void> _syncPendingOutlets() async {
    try {
      // This would need a current user session - you might want to store it in the provider
      // For now, we'll just reload outlets which will trigger sync in the service
      print('OutletProvider: Connection restored, syncing pending outlets...');
      // The service will handle syncing during getOutlets() call
    } catch (e) {
      print('OutletProvider: Error syncing pending outlets: $e');
    }
  }

  // Search outlets
  void searchOutlets(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  // Filter outlets by type
  void filterByType(String type) {
    _selectedOutletType = type;
    _applyFilters();
    notifyListeners();
  }

  // Apply search and filter
  void _applyFilters() {
    _filteredOutlets =
        _outlets.where((outlet) {
          // Apply search filter
          bool matchesSearch =
              _searchQuery.isEmpty ||
              outlet.outletName.toLowerCase().contains(_searchQuery) ||
              outlet.address.toLowerCase().contains(_searchQuery) ||
              outlet.ownerName.toLowerCase().contains(_searchQuery) ||
              outlet.phoneNumber.toLowerCase().contains(_searchQuery);

          // Apply type filter
          bool matchesType =
              _selectedOutletType == 'All' ||
              outlet.outletType == _selectedOutletType;

          // ADDED: Apply route filter
          bool matchesRoute =
              _selectedRouteId.isEmpty ||
              _selectedRouteId == 'All' ||
              outlet.routeId == _selectedRouteId;

          return matchesSearch && matchesType && matchesRoute;
        }).toList();

    // Sort outlets: synced first, then pending
    _filteredOutlets.sort((a, b) {
      return a.outletName.compareTo(b.outletName);
    });

    print(
      'OutletProvider: Applied filters - showing ${_filteredOutlets.length} of ${_outlets.length} outlets',
    );
  }

  // Clear search and filters
  void clearFilters() {
    _searchQuery = '';
    _selectedOutletType = 'All';
    _applyFilters();
    notifyListeners();
  }

  // Get outlet by ID
  Outlet? getOutletById(String outletId) {
    try {
      return _outlets.firstWhere((outlet) => outlet.id == outletId);
    } catch (e) {
      return null;
    }
  }

  // Update outlet
  Future<bool> updateOutlet({
    required String outletId,
    required Map<String, dynamic> updates,
    required UserSession userSession,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await OutletService.updateOutlet(
        session: userSession,
        outletId: outletId,
        updates: updates,
      );

      // Reload outlets to show the updated data
      await loadOutlets(userSession);
      return true;
    } catch (e) {
      _setError('Failed to update outlet: $e');
      print('OutletProvider: Error updating outlet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete outlet
  Future<bool> deleteOutlet({
    required String outletId,
    required UserSession userSession,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await OutletService.deleteOutlet(
        session: userSession,
        outletId: outletId,
      );

      // Reload outlets to refresh the list
      await loadOutlets(userSession);
      return true;
    } catch (e) {
      _setError('Failed to delete outlet: $e');
      print('OutletProvider: Error deleting outlet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get outlets for a specific area/route
  List<Outlet> getOutletsForRoute(String routeId) {
    return _outlets.where((outlet) {
      // Add route filtering logic here if outlets have route information
      return true; // For now, return all outlets
    }).toList();
  }

  // Get outlet statistics
  Map<String, dynamic> getOutletStatistics() {
    final stats = <String, int>{};

    for (final outlet in _outlets) {
      stats[outlet.outletType] = (stats[outlet.outletType] ?? 0) + 1;
    }

    return {
      'totalOutlets': _outlets.length,
      'filteredOutlets': _filteredOutlets.length,
      'offlineOutlets': _offlineOutletCount,
      'typeBreakdown': stats,
    };
  }

  // Private helper methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // Force refresh - useful for testing
  void forceRefresh() {
    notifyListeners();
  }

  // Debug method to print current state
  void printDebugInfo() {
    print('=== OutletProvider Debug Info ===');
    print('Total outlets: ${_outlets.length}');
    print('Filtered outlets: ${_filteredOutlets.length}');
    print('Is loading: $_isLoading');
    print('Is connected: $_isConnected');
    print('Offline count: $_offlineOutletCount');
    print('Search query: "$_searchQuery"');
    print('Selected type: $_selectedOutletType');
    print('Error: $_errorMessage');
    print('Outlet IDs: ${_outlets.map((o) => o.id).toList()}');
    print('================================');
  }
}
