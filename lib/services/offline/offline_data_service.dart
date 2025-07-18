// lib/services/offline/offline_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/user_session.dart';
import '../../models/loading.dart';
import '../../models/outlet.dart';
import '../../models/stock_item.dart';
import '../local/database_service.dart';

class OfflineDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseService _dbService = DatabaseService();

  /// Complete data download for offline functionality
  static Future<Map<String, dynamic>> downloadAllData({
    required UserSession session,
    void Function(String)? onProgress,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'errors': <String>[],
      'downloadedData': <String, dynamic>{},
      'details': <String, dynamic>{},
    };

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (!isOnline) {
        result['errors'].add('No internet connection available');
        return result;
      }

      onProgress?.call('Starting data download...');

      // Step 1: Download Today's Loading Data
      onProgress?.call('Downloading loading data...');
      final loadingResult = await _downloadLoadingData(session);
      if (!loadingResult['success']) {
        result['errors'].addAll(loadingResult['errors']);
        return result;
      }
      result['downloadedData']['loading'] = loadingResult['data'];

      // Step 2: Download Route Information
      onProgress?.call('Downloading route information...');
      final routeResult = await _downloadRouteData(session);
      if (!routeResult['success']) {
        result['errors'].addAll(routeResult['errors']);
      } else {
        result['downloadedData']['route'] = routeResult['data'];
      }

      // Step 3: Download Stock/Products Data
      onProgress?.call('Downloading stock data...');
      final stockResult = await _downloadStockData(session);
      if (!stockResult['success']) {
        result['errors'].addAll(stockResult['errors']);
      } else {
        result['downloadedData']['stock'] = stockResult['data'];
      }

      // Step 4: Download Outlets/Customers Data
      onProgress?.call('Downloading outlets data...');
      final outletsResult = await _downloadOutletsData(session);
      if (!outletsResult['success']) {
        result['errors'].addAll(outletsResult['errors']);
      } else {
        result['downloadedData']['outlets'] = outletsResult['data'];
      }

      // Step 5: Download Today's Paddy Prices
      onProgress?.call('Downloading today\'s prices...');
      final pricesResult = await _downloadPaddyPrices(session);
      if (!pricesResult['success']) {
        result['errors'].addAll(pricesResult['errors']);
      } else {
        result['downloadedData']['prices'] = pricesResult['data'];
      }

      // Step 6: Store all data locally
      onProgress?.call('Storing data locally...');
      await _storeDataLocally(session, result['downloadedData']);

      onProgress?.call('Download completed!');

      result['success'] = true;
      result['details'] = {
        'loadingItems': loadingResult['data']?['items']?.length ?? 0,
        'stockItems': stockResult['data']?.length ?? 0,
        'outlets': outletsResult['data']?.length ?? 0,
        'routeAreas': routeResult['data']?['areas']?.length ?? 0,
        'paddyPrices': pricesResult['data']?.length ?? 0,
        'downloadTime': DateTime.now().toIso8601String(),
      };

      return result;
    } catch (e) {
      onProgress?.call('Download failed: $e');
      result['errors'].add('Download failed: $e');
      return result;
    }
  }

  /// Download today's loading data
  static Future<Map<String, dynamic>> _downloadLoadingData(
    UserSession session,
  ) async {
    try {
      print('Downloading loading data for sales rep: ${session.employeeId}');

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
        return {
          'success': false,
          'errors': ['No loading data found for today'],
        };
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      // Create loading object
      final loading = Loading.fromFirestore(data, doc.id);

      // Store in local database
      await _dbService.syncLoading(loading);

      return {
        'success': true,
        'data': {
          'loading': loading,
          'loadingId': doc.id,
          'items': loading.items,
          'routeId': loading.routeId,
        },
      };
    } catch (e) {
      print('Error downloading loading data: $e');
      return {
        'success': false,
        'errors': ['Failed to download loading data: $e'],
      };
    }
  }

  /// Download route information
  static Future<Map<String, dynamic>> _downloadRouteData(
    UserSession session,
  ) async {
    try {
      // First get the route ID from loading data
      final loadingData = await _dbService.getTodaysLoading(
        session.ownerId,
        session.businessId,
        session.employeeId,
      );

      if (loadingData == null || loadingData.routeId.isEmpty) {
        return {
          'success': false,
          'errors': ['No route ID found in loading data'],
        };
      }

      final DocumentSnapshot routeDoc =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('routes')
              .doc(loadingData.routeId)
              .get();

      if (!routeDoc.exists) {
        return {
          'success': false,
          'errors': ['Route not found: ${loadingData.routeId}'],
        };
      }

      final routeData = routeDoc.data() as Map<String, dynamic>;

      // Store route data locally
      await _storeRouteDataLocally(session, routeData);

      return {'success': true, 'data': routeData};
    } catch (e) {
      print('Error downloading route data: $e');
      return {
        'success': false,
        'errors': ['Failed to download route data: $e'],
      };
    }
  }

  /// Download stock/products data
  static Future<Map<String, dynamic>> _downloadStockData(
    UserSession session,
  ) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('stock')
              .where('isActive', isEqualTo: true)
              .get();

      final stockItems = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        stockItems.add(data);
      }

      // Store stock data locally
      await _storeStockDataLocally(session, stockItems);

      return {'success': true, 'data': stockItems};
    } catch (e) {
      print('Error downloading stock data: $e');
      return {
        'success': false,
        'errors': ['Failed to download stock data: $e'],
      };
    }
  }

  /// Download outlets/customers data
  static Future<Map<String, dynamic>> _downloadOutletsData(
    UserSession session,
  ) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('customers')
              .where('isActive', isEqualTo: true)
              .orderBy('outletName')
              .get();

      final outlets = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        outlets.add(data);
      }

      // Store outlets data locally
      await _storeOutletsDataLocally(session, outlets);

      return {'success': true, 'data': outlets};
    } catch (e) {
      print('Error downloading outlets data: $e');
      return {
        'success': false,
        'errors': ['Failed to download outlets data: $e'],
      };
    }
  }

  /// Download today's paddy prices
  static Future<Map<String, dynamic>> _downloadPaddyPrices(
    UserSession session,
  ) async {
    try {
      // Get paddy prices from the loading data
      final loadingData = await _dbService.getTodaysLoading(
        session.ownerId,
        session.businessId,
        session.employeeId,
      );

      if (loadingData?.todayPaddyPrices != null &&
          loadingData!.todayPaddyPrices!.isNotEmpty) {
        // Store prices locally
        await _storePaddyPricesLocally(session, loadingData.todayPaddyPrices!);

        return {'success': true, 'data': loadingData.todayPaddyPrices!};
      }

      // If no prices in loading, try to get from a separate collection if exists
      try {
        final today = DateTime.now();
        final dateStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        final DocumentSnapshot pricesDoc =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('daily_prices')
                .doc(dateStr)
                .get();

        if (pricesDoc.exists) {
          final data = pricesDoc.data() as Map<String, dynamic>;
          final prices = data['paddyPrices'] as Map<String, dynamic>? ?? {};

          await _storePaddyPricesLocally(session, prices);

          return {'success': true, 'data': prices};
        }
      } catch (e) {
        print('No separate daily prices found: $e');
      }

      return {
        'success': false,
        'errors': ['No paddy prices found'],
      };
    } catch (e) {
      print('Error downloading paddy prices: $e');
      return {
        'success': false,
        'errors': ['Failed to download paddy prices: $e'],
      };
    }
  }

  /// Store route data locally
  static Future<void> _storeRouteDataLocally(
    UserSession session,
    Map<String, dynamic> routeData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_route_data', jsonEncode(routeData));
      await prefs.setString(
        'offline_route_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error storing route data locally: $e');
    }
  }

  /// Store stock data locally
  static Future<void> _storeStockDataLocally(
    UserSession session,
    List<Map<String, dynamic>> stockItems,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_stock_data', jsonEncode(stockItems));
      await prefs.setString(
        'offline_stock_timestamp',
        DateTime.now().toIso8601String(),
      );

      // Also store in database if needed
      for (final item in stockItems) {
        await _dbService.insertOrUpdateStockItem(item);
      }
    } catch (e) {
      print('Error storing stock data locally: $e');
    }
  }

  /// Store outlets data locally
  static Future<void> _storeOutletsDataLocally(
    UserSession session,
    List<Map<String, dynamic>> outlets,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_outlets_data', jsonEncode(outlets));
      await prefs.setString(
        'offline_outlets_timestamp',
        DateTime.now().toIso8601String(),
      );

      // Also store in database
      for (final outlet in outlets) {
        await _dbService.insertOrUpdateOutlet(outlet);
      }
    } catch (e) {
      print('Error storing outlets data locally: $e');
    }
  }

  /// Store paddy prices locally
  static Future<void> _storePaddyPricesLocally(
    UserSession session,
    Map<String, dynamic> prices,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_paddy_prices', jsonEncode(prices));
      await prefs.setString(
        'offline_prices_timestamp',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error storing paddy prices locally: $e');
    }
  }

  /// Store all data locally with summary
  static Future<void> _storeDataLocally(
    UserSession session,
    Map<String, dynamic> allData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store download summary
      final downloadSummary = {
        'lastDownloadTime': DateTime.now().toIso8601String(),
        'userId': session.userId,
        'businessId': session.businessId,
        'ownerId': session.ownerId,
        'dataTypes': allData.keys.toList(),
        'isOfflineReady': true,
      };

      await prefs.setString(
        'offline_download_summary',
        jsonEncode(downloadSummary),
      );

      print('All data stored locally successfully');
    } catch (e) {
      print('Error storing data summary locally: $e');
    }
  }

  /// Get offline data status
  static Future<Map<String, dynamic>> getOfflineDataStatus(
    UserSession session,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final summaryJson = prefs.getString('offline_download_summary');
      if (summaryJson == null) {
        return {
          'isOfflineReady': false,
          'lastDownloadTime': null,
          'dataTypes': <String>[],
        };
      }

      final summary = jsonDecode(summaryJson) as Map<String, dynamic>;

      // Check if data is recent (less than 24 hours old)
      final lastDownloadTime = DateTime.parse(summary['lastDownloadTime']);
      final isRecent = DateTime.now().difference(lastDownloadTime).inHours < 24;

      return {
        'isOfflineReady': summary['isOfflineReady'] && isRecent,
        'lastDownloadTime': lastDownloadTime,
        'dataTypes': summary['dataTypes'],
        'isRecent': isRecent,
        'hoursOld': DateTime.now().difference(lastDownloadTime).inHours,
      };
    } catch (e) {
      print('Error getting offline data status: $e');
      return {
        'isOfflineReady': false,
        'lastDownloadTime': null,
        'dataTypes': <String>[],
      };
    }
  }

  /// Get offline loading data
  static Future<Loading?> getOfflineLoadingData(UserSession session) async {
    try {
      return await _dbService.getTodaysLoading(
        session.ownerId,
        session.businessId,
        session.employeeId,
      );
    } catch (e) {
      print('Error getting offline loading data: $e');
      return null;
    }
  }

  /// Get offline outlets data
  static Future<List<Outlet>> getOfflineOutlets(UserSession session) async {
    try {
      final outletsData = await _dbService.getOutlets(
        session.ownerId,
        session.businessId,
      );

      return outletsData.map((data) => Outlet.fromSQLite(data)).toList();
    } catch (e) {
      print('Error getting offline outlets: $e');
      return [];
    }
  }

  /// Get offline stock data
  static Future<List<Map<String, dynamic>>> getOfflineStockData(
    UserSession session,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stockJson = prefs.getString('offline_stock_data');

      if (stockJson != null) {
        final stockList = jsonDecode(stockJson) as List;
        return stockList.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('Error getting offline stock data: $e');
      return [];
    }
  }

  /// Get offline paddy prices
  static Future<Map<String, dynamic>> getOfflinePaddyPrices(
    UserSession session,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pricesJson = prefs.getString('offline_paddy_prices');

      if (pricesJson != null) {
        return jsonDecode(pricesJson) as Map<String, dynamic>;
      }

      return {};
    } catch (e) {
      print('Error getting offline paddy prices: $e');
      return {};
    }
  }

  /// Clear all offline data
  static Future<void> clearOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keysToRemove = [
        'offline_route_data',
        'offline_route_timestamp',
        'offline_stock_data',
        'offline_stock_timestamp',
        'offline_outlets_data',
        'offline_outlets_timestamp',
        'offline_paddy_prices',
        'offline_prices_timestamp',
        'offline_download_summary',
      ];

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      print('Offline data cleared successfully');
    } catch (e) {
      print('Error clearing offline data: $e');
    }
  }

  /// Validate offline data integrity
  static Future<Map<String, bool>> validateOfflineData(
    UserSession session,
  ) async {
    try {
      final validation = <String, bool>{};

      // Check loading data
      final loading = await getOfflineLoadingData(session);
      validation['loading'] = loading != null;

      // Check outlets data
      final outlets = await getOfflineOutlets(session);
      validation['outlets'] = outlets.isNotEmpty;

      // Check stock data
      final stock = await getOfflineStockData(session);
      validation['stock'] = stock.isNotEmpty;

      // Check paddy prices
      final prices = await getOfflinePaddyPrices(session);
      validation['prices'] = prices.isNotEmpty;

      return validation;
    } catch (e) {
      print('Error validating offline data: $e');
      return {};
    }
  }
}
