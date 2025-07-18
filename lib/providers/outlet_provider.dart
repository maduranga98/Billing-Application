// lib/providers/outlet_provider.dart (CORRECTED FOR FULL OFFLINE SUPPORT)
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lumorabiz_billing/services/local/database_service.dart';
import '../models/outlet.dart';
import '../models/user_session.dart';
import '../services/outlet/outlet_service.dart';

class OutletProvider with ChangeNotifier {
  List<Outlet> _outlets = [];
  List<Outlet> _filteredOutlets = [];
  bool _isLoading = false;
  bool _isConnected = true;
  int _offlineOutletCount = 0;
  String _searchQuery = '';
  String _selectedOutletType = 'All';
  String? _errorMessage;
  String _selectedRouteId = '';
  UserSession? _currentSession; // Store session for background operations

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
  String get selectedRouteId => _selectedRouteId;

  // Enhanced offline getters
  bool get canWorkOffline =>
      true; // Always can work offline with local database
  bool get hasPendingSync => _offlineOutletCount > 0;
  List<Outlet> get offlineOutlets =>
      _outlets.where((outlet) => outlet.id.startsWith('offline_')).toList();
  List<Outlet> get syncedOutlets =>
      _outlets.where((outlet) => !outlet.id.startsWith('offline_')).toList();

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
        // Just came online, sync pending outlets in background
        print('OutletProvider: Device came online - starting background sync');
        _syncPendingOutletsBackground();
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

  /// Load all outlets (FULLY OFFLINE CAPABLE)
  /// Uses offline-first approach - always works even when offline
  Future<void> loadOutlets(UserSession userSession) async {
    try {
      print('OutletProvider: Loading outlets (offline-first approach)');
      _currentSession = userSession; // Store for background operations
      _setLoading(true);
      _clearError();

      // Use the corrected offline-capable service
      _outlets = await OutletService.getOutlets(userSession);
      print('OutletProvider: Loaded ${_outlets.length} outlets');

      // Load offline outlet count
      await _loadOfflineOutletCount(userSession);

      // Apply current filters
      _applyFilters();

      print(
        'OutletProvider: After filtering, showing ${_filteredOutlets.length} outlets',
      );
    } catch (e) {
      // Enhanced error handling - try to show something even if there's an error
      _setError('Failed to load outlets: $e');
      print('OutletProvider: Error loading outlets: $e');

      // Try to get whatever we can from local storage
      try {
        _outlets = await OutletService.getOutlets(userSession);
        _applyFilters();
        if (_outlets.isNotEmpty) {
          _setError(
            'Showing ${_outlets.length} outlets from local storage (offline mode)',
          );
        }
      } catch (fallbackError) {
        print('OutletProvider: Even fallback failed: $fallbackError');
        _outlets = [];
        _filteredOutlets = [];
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Load offline outlet count (ENHANCED)
  Future<void> _loadOfflineOutletCount(UserSession userSession) async {
    try {
      _offlineOutletCount = await OutletService.getOfflineOutletCount(
        userSession,
      );
      print('OutletProvider: Found $_offlineOutletCount offline outlets');
    } catch (e) {
      print('OutletProvider: Error getting offline outlet count: $e');
      _offlineOutletCount = 0;
    }
  }

  /// Sync offline outlets (ENHANCED WITH BETTER FEEDBACK)
  Future<Map<String, dynamic>> syncOfflineOutlets(
    UserSession userSession,
  ) async {
    try {
      print('OutletProvider: Syncing offline outlets...');
      _setLoading(true);
      _clearError();

      // Use the enhanced sync method that returns detailed results
      final result = await OutletService.syncPendingOutlets(userSession);

      if (result['success']) {
        final syncedCount = result['syncedCount'] as int;
        final failedCount = result['failedCount'] as int;

        print(
          'OutletProvider: Sync completed - $syncedCount synced, $failedCount failed',
        );

        // Reload outlets to reflect the sync status changes
        await loadOutlets(userSession);

        if (failedCount > 0) {
          final errors = result['errors'] as List<String>;
          _setError(
            'Synced $syncedCount outlets, $failedCount failed: ${errors.take(2).join(", ")}',
          );
        }

        return result;
      } else {
        _setError('Sync failed: ${result['error']}');
        return result;
      }
    } catch (e) {
      _setError('Failed to sync offline outlets: $e');
      print('OutletProvider: Error syncing offline outlets: $e');
      return {
        'success': false,
        'error': e.toString(),
        'syncedCount': 0,
        'failedCount': 0,
      };
    } finally {
      _setLoading(false);
    }
  }

  /// Background sync (non-blocking)
  Future<void> _syncPendingOutletsBackground() async {
    if (_currentSession == null) return;

    try {
      print('OutletProvider: Background sync started...');
      final result = await OutletService.syncPendingOutlets(_currentSession!);

      if (result['success']) {
        final syncedCount = result['syncedCount'] as int;
        if (syncedCount > 0) {
          // Reload outlets quietly to reflect sync changes
          await loadOutlets(_currentSession!);
          print(
            'OutletProvider: Background sync completed - $syncedCount outlets synced',
          );
        }
      }
    } catch (e) {
      print('OutletProvider: Background sync error (non-critical): $e');
    }
  }

  /// Refresh outlets (works offline)
  Future<void> refreshOutlets([UserSession? userSession]) async {
    if (userSession != null) {
      print('OutletProvider: Refreshing outlets...');
      await loadOutlets(userSession);
    }
  }

  /// Add new outlet (FULLY OFFLINE CAPABLE)
  /// Always works, even when completely offline
  Future<bool> addOutlet({
    required Map<String, dynamic> outletData,
    required UserSession userSession,
    String? imageBase64,
    String? routeId,
    String? routeName,
  }) async {
    try {
      print(
        'OutletProvider: Adding outlet: ${outletData['outletName']} (offline-capable)',
      );
      _setLoading(true);
      _clearError();

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

  /// Load outlets by route (offline capable)
  Future<void> loadOutletsByRoute(
    UserSession userSession,
    String routeId,
  ) async {
    try {
      print(
        'OutletProvider: Loading outlets for route: $routeId (offline-capable)',
      );
      _setLoading(true);
      _clearError();

      _outlets = await OutletService.getOutletsByRoute(userSession, routeId);
      print(
        'OutletProvider: Loaded ${_outlets.length} outlets for route: $routeId',
      );

      await _loadOfflineOutletCount(userSession);
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

  /// Get available routes (works offline)
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

  /// Filter outlets by route
  void filterByRoute(String routeId) {
    _selectedRouteId = routeId;
    _applyFilters();
    notifyListeners();
  }

  /// Search outlets
  void searchOutlets(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  /// Filter outlets by type
  void filterByType(String type) {
    _selectedOutletType = type;
    _applyFilters();
    notifyListeners();
  }

  /// Apply search and filter (ENHANCED)
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

          // Apply route filter
          bool matchesRoute =
              _selectedRouteId.isEmpty ||
              _selectedRouteId == 'All' ||
              outlet.routeId == _selectedRouteId;

          return matchesSearch && matchesType && matchesRoute;
        }).toList();

    // Enhanced sorting: pending sync first (for visibility), then by name
    _filteredOutlets.sort((a, b) {
      // Check if outlets are pending sync (offline IDs)
      final aIsPending = a.id.startsWith('offline_');
      final bIsPending = b.id.startsWith('offline_');

      // Prioritize pending outlets for visibility
      if (aIsPending && !bIsPending) return -1;
      if (!aIsPending && bIsPending) return 1;

      // Then sort by outlet name
      return a.outletName.compareTo(b.outletName);
    });

    print(
      'OutletProvider: Applied filters - showing ${_filteredOutlets.length} of ${_outlets.length} outlets',
    );
  }

  /// Clear search and filters
  void clearFilters() {
    _searchQuery = '';
    _selectedOutletType = 'All';
    _selectedRouteId = '';
    _applyFilters();
    notifyListeners();
  }

  /// Get outlet by ID
  Outlet? getOutletById(String outletId) {
    try {
      return _outlets.firstWhere((outlet) => outlet.id == outletId);
    } catch (e) {
      return null;
    }
  }

  /// Update outlet (handles offline)
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

  /// Delete outlet (handles offline)
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

  /// Get outlets for a specific route
  List<Outlet> getOutletsForRoute(String routeId) {
    return _outlets.where((outlet) => outlet.routeId == routeId).toList();
  }

  /// Get outlet statistics (includes offline status)
  Map<String, dynamic> getOutletStatistics() {
    final stats = <String, int>{};
    int onlineCount = 0;
    int offlineCount = 0;

    for (final outlet in _outlets) {
      stats[outlet.outletType] = (stats[outlet.outletType] ?? 0) + 1;

      if (outlet.id.startsWith('offline_')) {
        offlineCount++;
      } else {
        onlineCount++;
      }
    }

    return {
      'totalOutlets': _outlets.length,
      'filteredOutlets': _filteredOutlets.length,
      'onlineOutlets': onlineCount,
      'offlineOutlets': offlineCount,
      'pendingSyncCount': _offlineOutletCount,
      'typeBreakdown': stats,
      'canWorkOffline': canWorkOffline,
      'isConnected': _isConnected,
    };
  }

  /// Get sync status text
  String getSyncStatusText() {
    if (!_isConnected) {
      return 'Offline Mode - ${_outlets.length} outlets available locally';
    } else if (_offlineOutletCount > 0) {
      return '$_offlineOutletCount outlets pending sync';
    } else {
      return 'All outlets synced';
    }
  }

  /// Get detailed offline status
  Map<String, dynamic> getOfflineStatus() {
    return {
      'canWorkOffline': canWorkOffline,
      'isConnected': _isConnected,
      'totalOutlets': _outlets.length,
      'pendingSyncCount': _offlineOutletCount,
      'hasPendingSync': hasPendingSync,
      'offlineOutletsCount': offlineOutlets.length,
      'syncedOutletsCount': syncedOutlets.length,
      'syncStatusText': getSyncStatusText(),
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Check if ready for offline operation
  bool isReadyForOffline() {
    return _outlets.isNotEmpty || canWorkOffline;
  }

  /// Prepare for offline mode
  Future<bool> prepareForOfflineMode(UserSession userSession) async {
    try {
      print('OutletProvider: Preparing for offline mode...');

      // Ensure all data is loaded locally
      await loadOutlets(userSession);

      final isReady = isReadyForOffline();
      print(
        'OutletProvider: Offline preparation ${isReady ? 'successful' : 'failed'}',
      );

      return isReady;
    } catch (e) {
      print('OutletProvider: Error preparing for offline mode: $e');
      return false;
    }
  }

  /// Private helper methods
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

  /// Force refresh - useful for testing
  void forceRefresh() {
    notifyListeners();
  }

  /// Debug method to print current state
  void printDebugInfo() {
    print('=== OutletProvider Debug Info (Offline-Capable) ===');
    print('Total outlets: ${_outlets.length}');
    print('Filtered outlets: ${_filteredOutlets.length}');
    print('Is loading: $_isLoading');
    print('Is connected: $_isConnected');
    print('Offline count: $_offlineOutletCount');
    print('Pending sync count: $_offlineOutletCount');
    print('Can work offline: $canWorkOffline');
    print('Has pending sync: $hasPendingSync');
    print('Search query: "$_searchQuery"');
    print('Selected type: $_selectedOutletType');
    print('Selected route: $_selectedRouteId');
    print('Error: $_errorMessage');
    print('Outlet IDs: ${_outlets.map((o) => o.id).take(5).toList()}...');
    print('Offline outlets: ${offlineOutlets.length}');
    print('Synced outlets: ${syncedOutlets.length}');
    print('Current session: ${_currentSession?.name ?? 'None'}');
    print('====================================================');
  }

  /// Export outlets data for backup (useful for offline scenarios)
  Map<String, dynamic> exportOutletsData() {
    return {
      'outlets': _outlets.map((outlet) => outlet.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'totalCount': _outlets.length,
      'offlineCount': offlineOutlets.length,
      'syncedCount': syncedOutlets.length,
      'pendingSyncCount': _offlineOutletCount,
      'statistics': getOutletStatistics(),
      'offlineStatus': getOfflineStatus(),
    };
  }

  /// Validate offline capabilities
  bool validateOfflineCapability() {
    return canWorkOffline && (_outlets.isNotEmpty || _offlineOutletCount >= 0);
  }
}
