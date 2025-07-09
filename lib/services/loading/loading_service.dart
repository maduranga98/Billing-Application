import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/loading.dart';
import '../../models/loading_item.dart';
import '../../models/today_route.dart';
import '../../models/user_session.dart';
import '../local/database_service.dart';

class LoadingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseService _dbService = DatabaseService();

  // Load today's loading for the sales rep
  static Future<Loading?> getTodaysLoading(UserSession session) async {
    try {
      print('Loading data for employee: ${session.employeeId}');

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Load from Firebase and sync to local
        return await _loadFromFirebaseAndSync(session);
      } else {
        // Load from local database
        return await _loadFromLocal(session);
      }
    } catch (e) {
      print('Error loading today\'s loading: $e');
      // Fallback to local data
      return await _loadFromLocal(session);
    }
  }

  static Future<Loading?> _loadFromFirebaseAndSync(UserSession session) async {
    try {
      print('Querying Firebase for loading data...');

      // Query loadings collection where salesRepId equals employeeId
      final QuerySnapshot snapshot =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('loadings')
              .where('salesRepId', isEqualTo: session.employeeId)
              .where('status', isEqualTo: 'prepared')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        print('No prepared loading found for sales rep: ${session.employeeId}');
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      print('Found loading document: ${doc.id}');
      print('Document data keys: ${data.keys.toList()}');

      // Create loading with proper document ID - this handles all fields automatically
      final loading = Loading.fromFirestore(data, doc.id);

      // If no todayRoute in the loading data, try to fetch it separately
      Loading updatedLoading = loading;
      if (loading.todayRoute == null && loading.routeId.isNotEmpty) {
        print('Loading route info for routeId: ${loading.routeId}');
        final route = await getRouteInfo(session, loading.routeId);
        if (route != null) {
          // Create new Loading with the fetched route
          updatedLoading = Loading(
            loadingId: loading.loadingId,
            businessId: loading.businessId,
            ownerId: loading.ownerId,
            routeId: loading.routeId,
            salesRepId: loading.salesRepId,
            salesRepName: loading.salesRepName,
            salesRepEmail: loading.salesRepEmail,
            salesRepPhone: loading.salesRepPhone,
            status: loading.status,
            itemCount: loading.itemCount,
            totalBags: loading.totalBags,
            totalValue: loading.totalValue,
            totalWeight: loading.totalWeight,
            items: loading.items,
            todayRoute: route, // Use the fetched route
            createdAt: loading.createdAt,
            createdBy: loading.createdBy,
            paddyPriceDate: loading.paddyPriceDate,
            todayPaddyPrices: loading.todayPaddyPrices,
          );
        }
      }

      // Sync to local database
      await _syncToLocal(updatedLoading);

      print(
        'Loading data loaded successfully with ${updatedLoading.items.length} items',
      );
      return updatedLoading;
    } catch (e) {
      print('Error loading from Firebase: $e');
      throw e;
    }
  }

  static Future<TodayRoute?> getRouteInfo(
    UserSession session,
    String routeId,
  ) async {
    try {
      print('Fetching route info for routeId: $routeId');

      final DocumentSnapshot routeDoc =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('routes')
              .doc(routeId)
              .get();

      if (routeDoc.exists) {
        final data = routeDoc.data() as Map<String, dynamic>;
        print('Route data found: ${data['name']}');
        return TodayRoute.fromMap(data);
      } else {
        print('Route document not found for ID: $routeId');
        return null;
      }
    } catch (e) {
      print('Error loading route info: $e');
      return null;
    }
  }

  static Future<Loading?> _loadFromLocal(UserSession session) async {
    try {
      return await _dbService.getTodaysLoading(
        session.ownerId,
        session.businessId,
        session.employeeId,
      );
    } catch (e) {
      print('Error loading from local database: $e');
      return null;
    }
  }

  static Future<void> _syncToLocal(Loading loading) async {
    try {
      await _dbService.syncLoading(loading);
    } catch (e) {
      print('Error syncing to local database: $e');
    }
  }

  // Search items in current loading (updated for new structure)
  static Future<List<LoadingItem>> searchItems({
    required UserSession session,
    required String query,
  }) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) return [];

      if (query.isEmpty) return loading.availableItems;

      final lowerQuery = query.toLowerCase();
      return loading.availableItems.where((item) {
        return item.displayName.toLowerCase().contains(lowerQuery) ||
            item.productCode.toLowerCase().contains(lowerQuery) ||
            item.productType.toLowerCase().contains(lowerQuery) ||
            (item.riceType?.toLowerCase().contains(lowerQuery) ?? false) ||
            (item.sourceBatchNumber?.toLowerCase().contains(lowerQuery) ??
                false);
      }).toList();
    } catch (e) {
      print('Error searching items: $e');
      return [];
    }
  }

  // Get available items for billing
  static Future<List<LoadingItem>> getAvailableItems(
    UserSession session,
  ) async {
    final loading = await getTodaysLoading(session);
    return loading?.availableItems ?? [];
  }

  // Check if sufficient quantity is available (updated for bag-based system)
  static Future<bool> checkSufficientQuantity({
    required UserSession session,
    required String productCode,
    required int requiredBags,
  }) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) return false;

      final item = loading.items.firstWhere(
        (item) => item.productCode == productCode,
        orElse: () => _createEmptyLoadingItem(),
      );

      return item.productCode.isNotEmpty &&
          item.availableQuantity >= requiredBags;
    } catch (e) {
      print('Error checking quantity: $e');
      return false;
    }
  }

  // Helper method to create empty LoadingItem for orElse cases
  static LoadingItem _createEmptyLoadingItem() {
    return LoadingItem(
      bagQuantity: 0,
      bagSize: 0,
      bagsCount: 0,
      bagsUsed: [],
      displayName: '',
      itemName: '',
      maxPrice: 0.0,
      minPrice: 0.0,
      pricePerKg: 0.0,
      productCode: '',
      productType: '',
      totalValue: 0.0,
      totalWeight: 0.0,
    );
  }

  // Validate items before bill creation (updated for bag-based system)
  static Future<Map<String, dynamic>> validateItemsForBill({
    required UserSession session,
    required Map<String, int> itemQuantities, // productCode -> required bags
  }) async {
    final List<String> insufficientItems = [];
    final List<String> unavailableItems = [];
    bool isValid = true;

    try {
      final loading = await getTodaysLoading(session);

      if (loading == null) {
        return {
          'isValid': false,
          'error': 'No loading found for today',
          'insufficientItems': [],
          'unavailableItems': [],
        };
      }

      for (final entry in itemQuantities.entries) {
        final productCode = entry.key;
        final requiredBags = entry.value;

        try {
          final item = loading.items.firstWhere(
            (item) => item.productCode == productCode,
          );

          if (item.availableQuantity < requiredBags) {
            insufficientItems.add(
              '${item.displayName} (Available: ${item.availableQuantity} bags, Required: $requiredBags bags)',
            );
            isValid = false;
          }
        } catch (e) {
          unavailableItems.add(productCode);
          isValid = false;
        }
      }

      return {
        'isValid': isValid,
        'insufficientItems': insufficientItems,
        'unavailableItems': unavailableItems,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
        'insufficientItems': [],
        'unavailableItems': [],
      };
    }
  }

  // Update sold quantities after creating a bill (placeholder for future implementation)
  static Future<bool> updateSoldQuantities({
    required UserSession session,
    required String loadingId,
    required Map<String, int> itemQuantities, // productCode -> bags sold
  }) async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Update in Firebase (future implementation)
        await _updateFirebaseBagQuantities(session, loadingId, itemQuantities);
      }

      // Always update local database
      await _dbService.updateLoadingSoldQuantities(loadingId, itemQuantities);

      return true;
    } catch (e) {
      print('Error updating sold quantities: $e');
      return false;
    }
  }

  static Future<void> _updateFirebaseBagQuantities(
    UserSession session,
    String loadingId,
    Map<String, int> itemQuantities,
  ) async {
    try {
      final DocumentReference loadingRef = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('loadings')
          .doc(loadingId);

      // Get current loading document
      final DocumentSnapshot loadingDoc = await loadingRef.get();

      if (!loadingDoc.exists) {
        throw Exception('Loading document not found');
      }

      final data = loadingDoc.data() as Map<String, dynamic>;
      final itemsData = data['items'] as List<dynamic>;

      // Update bag quantities for each item
      for (int i = 0; i < itemsData.length; i++) {
        final item = itemsData[i] as Map<String, dynamic>;
        final productCode = item['productCode'] as String;

        if (itemQuantities.containsKey(productCode)) {
          final currentQuantity = item['bagQuantity'] ?? 0;
          final bagsSold = itemQuantities[productCode]!;
          // Reduce available quantity
          item['bagQuantity'] = (currentQuantity - bagsSold).clamp(
            0,
            currentQuantity,
          );
        }
      }

      // Update the document
      await loadingRef.update({'items': itemsData});
    } catch (e) {
      print('Error updating Firebase bag quantities: $e');
      throw e;
    }
  }

  // Get loading by ID (useful for specific loading operations)
  static Future<Loading?> getLoadingById({
    required UserSession session,
    required String loadingId,
  }) async {
    try {
      final DocumentSnapshot doc =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('loadings')
              .doc(loadingId)
              .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Loading.fromFirestore(data, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting loading by ID: $e');
      return null;
    }
  }

  // Get loading summary for display
  static Future<Map<String, dynamic>> getLoadingSummary(
    UserSession session,
  ) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) {
        return {
          'hasLoading': false,
          'message': 'No loading prepared for today',
        };
      }

      return {
        'hasLoading': true,
        'loadingId': loading.loadingId,
        'routeName': loading.routeDisplayName,
        'itemCount': loading.itemCount,
        'totalBags': loading.totalBags,
        'totalValue': loading.totalValue,
        'totalWeight': loading.totalWeight,
        'status': loading.status,
        'paddyPricesText': loading.paddyPricesText,
        'routeAreasText': loading.routeAreasText,
        'isReadyForSales': loading.isReadyForSales,
      };
    } catch (e) {
      print('Error getting loading summary: $e');
      return {'hasLoading': false, 'message': 'Error loading data: $e'};
    }
  }

  // Search items by batch number
  static Future<List<LoadingItem>> searchItemsByBatch({
    required UserSession session,
    required String batchNumber,
  }) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) return [];

      return loading.items.where((item) {
        return item.sourceBatchNumber?.toLowerCase() ==
            batchNumber.toLowerCase();
      }).toList();
    } catch (e) {
      print('Error searching items by batch: $e');
      return [];
    }
  }

  // Get items by rice type
  static Future<List<LoadingItem>> getItemsByRiceType({
    required UserSession session,
    required String riceType,
  }) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) return [];

      return loading.items.where((item) {
        return item.riceType?.toLowerCase() == riceType.toLowerCase();
      }).toList();
    } catch (e) {
      print('Error getting items by rice type: $e');
      return [];
    }
  }
}
