// lib/providers/outlet_provider.dart
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lumorabiz_billing/services/services/outlet_service.dart';

import '../models/outlet.dart';
import '../models/user_session.dart';

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

  // Outlet types for filtering
  List<String> get outletTypes => [
    'All',
    'Retail',
    'Wholesale',
    'Hotel',
    'Restaurant',
    'Supermarket',
    'Pharmacy',
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
        // Just came online, refresh data
        refreshOutlets();
      }

      // Only notify if not currently loading to avoid conflicts
      if (!_isLoading) {
        notifyListeners();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isConnected = !connectivityResult.contains(ConnectivityResult.none);
  }

  // Load all outlets
  Future<void> loadOutlets(UserSession userSession) async {
    try {
      _setLoading(true);
      _clearError();

      _outlets = await OutletService.getAllOutlets(userSession);
      _offlineOutletCount = await OutletService.getOfflineOutletCount();
      _applyFilters();
    } catch (e) {
      _setError('Failed to load outlets: $e');
      print('Error loading outlets: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Refresh outlets
  Future<void> refreshOutlets([UserSession? userSession]) async {
    if (userSession != null) {
      await loadOutlets(userSession);
    }
  }

  // Add new outlet
  Future<bool> addOutlet({
    required Outlet outlet,
    required UserSession userSession,
    String? imageBase64,
  }) async {
    _clearError();

    try {
      String outletId;

      if (_isConnected) {
        // Save online
        outletId = await OutletService.addOutletOnline(
          outlet: outlet,
          userSession: userSession,
          imageBase64: imageBase64,
        );
      } else {
        // Save offline
        final outletData = outlet.toFirestore();
        outletData.addAll({
          'ownerId': userSession.ownerId,
          'businessId': userSession.businessId,
          'createdBy': userSession.employeeId,
          'imageBase64': imageBase64,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        outletId = await OutletService.addOutletOffline(outletData: outletData);
        _offlineOutletCount++;
      }

      // Refresh the list
      await loadOutlets(userSession);
      return true;
    } catch (e) {
      _setError('Failed to add outlet: $e');
      return false;
    }
  }

  // Sync offline outlets - Fixed to use the SyncResult from OutletService
  Future<SyncResult?> syncOfflineOutlets(UserSession userSession) async {
    if (!_isConnected) {
      _setError('Cannot sync while offline');
      return null;
    }

    _clearError();

    try {
      final result = await OutletService.syncOfflineOutlets(userSession);

      if (result.success || result.syncedCount > 0) {
        // Refresh data after successful sync
        await loadOutlets(userSession);
      }

      return result;
    } catch (e) {
      _setError('Sync failed: $e');
      return null;
    }
  }

  // Search outlets
  void searchOutlets(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  // Filter by outlet type
  void filterByType(String outletType) {
    _selectedOutletType = outletType;
    _applyFilters();
  }

  // Apply search and filter
  void _applyFilters() {
    _filteredOutlets =
        _outlets.where((outlet) {
          // Search filter
          final matchesSearch =
              _searchQuery.isEmpty ||
              outlet.outletName.toLowerCase().contains(_searchQuery) ||
              outlet.address.toLowerCase().contains(_searchQuery) ||
              outlet.ownerName.toLowerCase().contains(_searchQuery) ||
              outlet.phoneNumber.contains(_searchQuery);

          // Type filter
          final matchesType =
              _selectedOutletType == 'All' ||
              outlet.outletType == _selectedOutletType;

          return matchesSearch && matchesType;
        }).toList();

    // Sort: offline outlets first (for sync priority), then by creation date
    _filteredOutlets.sort((a, b) {
      // Check if outlets are offline (shorter ID or starts with 'offline_')
      final aIsOffline = a.id.length <= 15 || a.id.startsWith('offline_');
      final bIsOffline = b.id.length <= 15 || b.id.startsWith('offline_');

      // Prioritize offline outlets for visibility
      if (aIsOffline && !bIsOffline) return -1;
      if (!aIsOffline && bIsOffline) return 1;

      // Then sort by creation date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    notifyListeners();
  }

  // Clear search and filters
  void clearFilters() {
    _searchQuery = '';
    _selectedOutletType = 'All';
    _applyFilters();
  }

  // Delete outlet
  Future<bool> deleteOutlet(String outletId, UserSession userSession) async {
    _clearError();

    try {
      await OutletService.deleteOutlet(outletId, userSession);
      await loadOutlets(userSession);
      return true;
    } catch (e) {
      _setError('Failed to delete outlet: $e');
      return false;
    }
  }

  // Update outlet
  Future<bool> updateOutlet({
    required String outletId,
    required Map<String, dynamic> updates,
    required UserSession userSession,
  }) async {
    _clearError();

    try {
      await OutletService.updateOutlet(outletId, updates, userSession);
      await loadOutlets(userSession);
      return true;
    } catch (e) {
      _setError('Failed to update outlet: $e');
      return false;
    }
  }

  // Get outlet by ID
  Outlet? getOutletById(String id) {
    try {
      return _outlets.firstWhere((outlet) => outlet.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get outlets by type
  List<Outlet> getOutletsByType(String type) {
    return _outlets.where((outlet) => outlet.outletType == type).toList();
  }

  // Get outlets statistics
  Map<String, dynamic> getOutletStats() {
    final onlineOutlets =
        _outlets
            .where((o) => o.id.length > 15 && !o.id.startsWith('offline_'))
            .length;
    final offlineOutlets =
        _outlets
            .where((o) => o.id.length <= 15 || o.id.startsWith('offline_'))
            .length;

    final stats = <String, dynamic>{
      'total': _outlets.length,
      'online': onlineOutlets,
      'offline': offlineOutlets,
      'byType': <String, int>{},
    };

    // Count by type
    for (final outlet in _outlets) {
      final type = outlet.outletType;
      stats['byType'][type] = (stats['byType'][type] ?? 0) + 1;
    }

    return stats;
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

  // Dispose method
  @override
  void dispose() {
    super.dispose();
  }
}

// Note: SyncResult is now imported from OutletService, no need to define it here
