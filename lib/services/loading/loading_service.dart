// lib/services/loading/loading_service.dart
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
      final loading = Loading.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );

      // Load route information if routeId exists
      Loading updatedLoading = loading;
      if (loading.routeId.isNotEmpty) {
        final route = await getRouteInfo(session, loading.routeId);
        if (route != null) {
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
            items: loading.items,
            todayRoute: route,
            createdAt: loading.createdAt,
            createdBy: loading.createdBy,
          );
        }
      }

      // Sync to local database
      await _syncToLocal(updatedLoading);

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
        return TodayRoute.fromMap(routeDoc.data() as Map<String, dynamic>);
      }
      return null;
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

  // Update sold quantities after creating a bill
  static Future<bool> updateSoldQuantities({
    required UserSession session,
    required String loadingId,
    required Map<String, int> itemQuantities, // productId -> quantity sold
  }) async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Update in Firebase
        await _updateFirebaseQuantities(session, loadingId, itemQuantities);
      }

      // Always update local database
      await _dbService.updateLoadingSoldQuantities(loadingId, itemQuantities);

      return true;
    } catch (e) {
      print('Error updating sold quantities: $e');
      return false;
    }
  }

  static Future<void> _updateFirebaseQuantities(
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

      // Update sold quantities for each item
      for (int i = 0; i < itemsData.length; i++) {
        final item = itemsData[i] as Map<String, dynamic>;
        final productId = item['productId'] as String;

        if (itemQuantities.containsKey(productId)) {
          final currentSold = item['soldQuantity'] ?? 0;
          final additionalSold = itemQuantities[productId]!;
          item['soldQuantity'] = currentSold + additionalSold;
        }
      }

      // Update the document
      await loadingRef.update({'items': itemsData});
    } catch (e) {
      print('Error updating Firebase quantities: $e');
      throw e;
    }
  }

  // Get available items for billing
  static Future<List<LoadingItem>> getAvailableItems(
    UserSession session,
  ) async {
    final loading = await getTodaysLoading(session);
    return loading?.availableItems ?? [];
  }

  // Check if sufficient quantity is available
  static Future<bool> checkSufficientQuantity({
    required UserSession session,
    required String productId,
    required int requiredQuantity,
  }) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) return false;

      final item = loading.items.firstWhere(
        (item) => item.productId == productId,
        orElse:
            () => LoadingItem(
              productId: '',
              productName: '',
              productCode: '',
              unitPrice: 0,
              loadedQuantity: 0,
              soldQuantity: 0,
              totalWeight: 0,
              unit: '',
              category: '',
            ),
      );

      return item.productId.isNotEmpty &&
          item.availableQuantity >= requiredQuantity;
    } catch (e) {
      print('Error checking quantity: $e');
      return false;
    }
  }

  // Validate items before bill creation
  static Future<Map<String, dynamic>> validateItemsForBill({
    required UserSession session,
    required Map<String, int> itemQuantities, // productId -> required quantity
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
        final productId = entry.key;
        final requiredQuantity = entry.value;

        try {
          final item = loading.items.firstWhere(
            (item) => item.productId == productId,
          );

          if (item.availableQuantity < requiredQuantity) {
            insufficientItems.add(
              '${item.productName} (Available: ${item.availableQuantity}, Required: $requiredQuantity)',
            );
            isValid = false;
          }
        } catch (e) {
          unavailableItems.add(productId);
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

  // Get loading statistics
  static Future<Map<String, dynamic>> getLoadingStatistics(
    UserSession session,
  ) async {
    try {
      final loading = await getTodaysLoading(session);

      if (loading == null) {
        return {
          'hasLoading': false,
          'totalItems': 0,
          'totalValue': 0.0,
          'availableItems': 0,
          'soldItems': 0,
          'routeName': 'No Route',
        };
      }

      final availableItems =
          loading.items.where((item) => item.availableQuantity > 0).length;
      final soldItems =
          loading.items.where((item) => item.soldQuantity > 0).length;
      final totalAvailableValue = loading.items.fold(
        0.0,
        (sum, item) => sum + item.totalValue,
      );

      return {
        'hasLoading': true,
        'totalItems': loading.itemCount,
        'totalValue': totalAvailableValue,
        'totalLoadedValue': loading.totalValue,
        'availableItems': availableItems,
        'soldItems': soldItems,
        'routeName': loading.todayRoute?.name ?? 'Unknown Route',
        'routeAreas': loading.todayRoute?.areas ?? [],
        'status': loading.status,
      };
    } catch (e) {
      print('Error getting loading statistics: $e');
      return {
        'hasLoading': false,
        'totalItems': 0,
        'totalValue': 0.0,
        'availableItems': 0,
        'soldItems': 0,
        'routeName': 'Error',
      };
    }
  }

  // Search items in loading
  static Future<List<LoadingItem>> searchItems({
    required UserSession session,
    required String query,
  }) async {
    try {
      final loading = await getTodaysLoading(session);
      if (loading == null) return [];

      if (query.isEmpty) return loading.availableItems;

      return loading.availableItems.where((item) {
        return item.productName.toLowerCase().contains(query.toLowerCase()) ||
            item.productCode.toLowerCase().contains(query.toLowerCase()) ||
            item.category.toLowerCase().contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      print('Error searching items: $e');
      return [];
    }
  }
}
