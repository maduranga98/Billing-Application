// lib/services/outlet/outlet_service.dart (CORRECTED FOR FULL OFFLINE SUPPORT)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../models/outlet.dart';
import '../../models/user_session.dart';
import '../local/database_service.dart';

class OutletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final DatabaseService _dbService = DatabaseService();

  /// Add new outlet (ENHANCED FOR FULL OFFLINE SUPPORT)
  /// Works both online and offline with graceful fallback
  static Future<String> addOutlet({
    required UserSession session,
    required Map<String, dynamic> outletData,
    String? imageBase64,
    String? routeId,
    String? routeName,
  }) async {
    try {
      print(
        'Adding outlet: ${outletData['outletName']} to route: $routeName ($routeId)',
      );

      // Check connectivity (but don't depend on it failing)
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        print('Device online - attempting Firebase save...');
        try {
          return await _addOutletOnline(
            session,
            outletData,
            imageBase64,
            routeId,
            routeName,
          );
        } catch (e) {
          print('Online save failed, falling back to offline: $e');
          // ENHANCED: Graceful fallback to offline if online fails
          return await _addOutletOffline(
            session,
            outletData,
            imageBase64,
            routeId,
            routeName,
          );
        }
      } else {
        print('Device offline - saving locally...');
        return await _addOutletOffline(
          session,
          outletData,
          imageBase64,
          routeId,
          routeName,
        );
      }
    } catch (e) {
      print('Error adding outlet: $e');
      rethrow;
    }
  }

  /// Add outlet online to Firebase customers collection
  static Future<String> _addOutletOnline(
    UserSession session,
    Map<String, dynamic> outletData,
    String? imageBase64,
    String? routeId,
    String? routeName,
  ) async {
    try {
      final docRef =
          _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('customers')
              .doc();

      final outletId = docRef.id;
      print('Created customer document with ID: $outletId');

      // Upload image first if provided
      String? imageUrl;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        print('Uploading image to Firebase Storage...');
        imageUrl = await _uploadImageToStorage(
          outletId: outletId,
          imageBase64: imageBase64,
          session: session,
        );
        print('Image uploaded successfully: $imageUrl');
      }

      final completeOutletData = {
        'id': outletId,
        'outletName': outletData['outletName'],
        'address': outletData['address'],
        'phoneNumber': outletData['phoneNumber'],
        'coordinates': {
          'latitude': outletData['latitude'],
          'longitude': outletData['longitude'],
        },
        'ownerName': outletData['ownerName'],
        'outletType': outletData['outletType'],
        'imageUrl': imageUrl,
        'isActive': true,
        'businessId': session.businessId,
        'ownerId': session.ownerId,
        'createdBy': session.employeeId,
        'routeId': routeId ?? '',
        'routeName': routeName,
        'createdAt': FieldValue.serverTimestamp(),
        'registeredDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'customerType': 'outlet',
        'status': 'active',
        'registeredBy': session.employeeId,
        'lastVisit': null,
        'totalOrders': 0,
        'totalValue': 0.0,
      };

      // Save to Firestore customers collection
      await docRef.set(completeOutletData);
      print('Outlet saved to customers collection with route: $routeName');

      // IMPORTANT: Also save to local database for offline access
      try {
        await _saveOutletToLocal(
          session,
          outletId,
          outletData,
          imageUrl,
          imageBase64,
          routeId,
          routeName,
          syncStatus: 'synced', // Mark as already synced
        );
        print('Outlet synced to local database');
      } catch (e) {
        print('Warning: Failed to sync outlet to local database: $e');
        // Don't fail the whole operation if local save fails
      }

      return outletId;
    } catch (e) {
      print('Error adding outlet to customers collection: $e');
      throw Exception('Failed to save outlet online: ${e.toString()}');
    }
  }

  /// Add outlet offline to local storage (FULLY FUNCTIONAL)
  static Future<String> _addOutletOffline(
    UserSession session,
    Map<String, dynamic> outletData,
    String? imageBase64,
    String? routeId,
    String? routeName,
  ) async {
    try {
      // Generate unique offline ID with timestamp and user info
      final outletId =
          'offline_${DateTime.now().millisecondsSinceEpoch}_${session.employeeId}';
      print('Creating offline outlet with ID: $outletId for route: $routeName');

      await _saveOutletToLocal(
        session,
        outletId,
        outletData,
        null, // No Firebase URL when offline
        imageBase64,
        routeId,
        routeName,
        syncStatus: 'pending', // Mark as needing sync
      );

      print('Outlet saved offline successfully - will sync when online');
      return outletId;
    } catch (e) {
      print('Error adding outlet offline: $e');
      throw Exception('Failed to save outlet offline: ${e.toString()}');
    }
  }

  /// Save outlet to local database (ENHANCED)
  static Future<void> _saveOutletToLocal(
    UserSession session,
    String outletId,
    Map<String, dynamic> outletData,
    String? firebaseImageUrl,
    String? imageBase64,
    String? routeId,
    String? routeName, {
    String syncStatus = 'pending',
  }) async {
    try {
      final localOutletData = {
        'id': outletId,
        'outlet_name': outletData['outletName'],
        'address': outletData['address'] ?? '',
        'phone': outletData['phoneNumber'] ?? '',
        'latitude': outletData['latitude'] ?? 0.0,
        'longitude': outletData['longitude'] ?? 0.0,
        'owner_name': outletData['ownerName'] ?? '',
        'outlet_type': outletData['outletType'] ?? 'general',
        'image_base64': imageBase64,
        'firebase_image_url': firebaseImageUrl,
        'owner_id': session.ownerId,
        'business_id': session.businessId,
        'created_by': session.employeeId,
        'route_id': routeId ?? '',
        'route_name': routeName ?? '',
        'is_active': 1,
        'sync_status': syncStatus,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _dbService.insertOutlet(localOutletData);
      print('Outlet saved to local database with sync_status: $syncStatus');
    } catch (e) {
      print('Error saving outlet to local database: $e');
      rethrow;
    }
  }

  /// Upload image to Firebase Storage
  static Future<String> _uploadImageToStorage({
    required String outletId,
    required String imageBase64,
    required UserSession session,
  }) async {
    try {
      final Uint8List imageBytes = base64Decode(imageBase64);
      final String fileName =
          'customer_outlet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage
          .ref()
          .child('owners')
          .child(session.ownerId)
          .child('businesses')
          .child(session.businessId)
          .child('customers')
          .child(outletId)
          .child('images')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'customerId': outletId,
            'customerType': 'outlet',
            'uploadedBy': session.employeeId,
          },
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image to customer storage: $e');
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Get all outlets (OFFLINE-FIRST APPROACH)
  /// Always works, even when completely offline
  static Future<List<Outlet>> getOutlets(
    UserSession session, {
    String? routeId,
    String? outletType,
    bool? isActive,
  }) async {
    try {
      print(
        'Loading outlets for business: ${session.businessId} (offline-first)',
      );
      if (routeId != null) print('Filtering by route: $routeId');
      if (outletType != null) print('Filtering by type: $outletType');

      // OFFLINE-FIRST: Always try local first
      List<Outlet> outlets = [];
      try {
        outlets = await _getOutletsFromLocal(
          session,
          routeId: routeId,
          outletType: outletType,
          isActive: isActive,
        );
        print('Loaded ${outlets.length} outlets from local database');
      } catch (localError) {
        print('Error loading from local database: $localError');
        // Continue to try online if local fails
      }

      // Try to sync with online if connected (but don't block)
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        print('Device online - attempting background sync...');
        try {
          final onlineOutlets = await _getOutletsFromFirebase(
            session,
            routeId: routeId,
            outletType: outletType,
            isActive: isActive,
          );

          // Sync to local database
          await _syncOutletsToLocal(onlineOutlets);
          print('Background sync completed');

          // If online data is newer/different, use it
          if (onlineOutlets.isNotEmpty) {
            outlets = onlineOutlets;
          }
        } catch (onlineError) {
          print('Online sync failed (non-critical): $onlineError');
          // Continue with local data - don't fail the whole operation
        }
      } else {
        print('Device offline - using local data only');
      }

      return outlets;
    } catch (e) {
      print('Error in getOutlets: $e');
      // Last resort - try local only
      try {
        return await _getOutletsFromLocal(session);
      } catch (fallbackError) {
        print('Even fallback failed: $fallbackError');
        return []; // Return empty list rather than crash
      }
    }
  }

  /// Get outlets from Firebase customers collection
  static Future<List<Outlet>> _getOutletsFromFirebase(
    UserSession session, {
    String? routeId,
    String? outletType,
    bool? isActive,
  }) async {
    try {
      print('Fetching outlets from Firebase customers collection...');

      Query<Map<String, dynamic>> query = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('customers')
          .where('customerType', isEqualTo: 'outlet');

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      } else {
        query = query.where('isActive', isEqualTo: true);
      }

      if (routeId != null && routeId.isNotEmpty) {
        query = query.where('routeId', isEqualTo: routeId);
      }

      if (outletType != null && outletType.isNotEmpty) {
        query = query.where('outletType', isEqualTo: outletType);
      }

      query = query.orderBy('outletName');

      final QuerySnapshot snapshot = await query.get();
      final outlets =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Outlet.fromFirestore(data, doc.id);
          }).toList();

      print(
        'Found ${outlets.length} outlets from Firebase customers collection',
      );
      if (routeId != null) {
        final routeOutlets = outlets.where((o) => o.routeId == routeId).length;
        print('  - $routeOutlets outlets belong to route: $routeId');
      }

      return outlets;
    } catch (e) {
      print('Error getting outlets from Firebase customers collection: $e');
      throw e;
    }
  }

  /// Get outlets from local database (ALWAYS WORKS OFFLINE)
  static Future<List<Outlet>> _getOutletsFromLocal(
    UserSession session, {
    String? routeId,
    String? outletType,
    bool? isActive,
  }) async {
    try {
      print('Loading outlets from local database...');

      String whereClause = 'owner_id = ? AND business_id = ?';
      List<dynamic> whereArgs = [session.ownerId, session.businessId];

      if (isActive != null) {
        whereClause += ' AND is_active = ?';
        whereArgs.add(isActive ? 1 : 0);
      } else {
        whereClause += ' AND is_active = 1';
      }

      if (routeId != null && routeId.isNotEmpty) {
        whereClause += ' AND route_id = ?';
        whereArgs.add(routeId);
      }

      if (outletType != null && outletType.isNotEmpty) {
        whereClause += ' AND outlet_type = ?';
        whereArgs.add(outletType);
      }

      final db = await _dbService.database;
      final outletsData = await db.query(
        'outlets',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'outlet_name',
      );

      final outlets =
          outletsData.map((data) => Outlet.fromSQLite(data)).toList();
      print('Found ${outlets.length} outlets from local database');

      return outlets;
    } catch (e) {
      print('Error getting outlets from local database: $e');
      return []; // Return empty list instead of throwing
    }
  }

  /// Sync outlets to local database
  static Future<void> _syncOutletsToLocal(List<Outlet> outlets) async {
    try {
      for (final outlet in outlets) {
        final outletData = outlet.toSQLite();
        // Mark Firebase outlets as synced
        outletData['sync_status'] = 'synced';
        await _dbService.insertOutlet(outletData);
      }
      print('Synced ${outlets.length} outlets to local database');
    } catch (e) {
      print('Error syncing outlets to local: $e');
    }
  }

  /// Get specific outlet by ID (OFFLINE CAPABLE)
  static Future<Outlet?> getOutletById({
    required UserSession session,
    required String outletId,
  }) async {
    try {
      // Try local first
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'outlets',
        where: 'id = ?',
        whereArgs: [outletId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Outlet.fromSQLite(maps.first);
      }

      // If not found locally and online, try Firebase
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        try {
          final DocumentSnapshot doc =
              await _firestore
                  .collection('owners')
                  .doc(session.ownerId)
                  .collection('businesses')
                  .doc(session.businessId)
                  .collection('customers')
                  .doc(outletId)
                  .get();

          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['customerType'] == 'outlet') {
              return Outlet.fromFirestore(data, doc.id);
            }
          }
        } catch (e) {
          print('Error getting outlet from Firebase: $e');
        }
      }

      return null;
    } catch (e) {
      print('Error getting outlet by ID: $e');
      return null;
    }
  }

  /// Get outlets by route ID specifically
  static Future<List<Outlet>> getOutletsByRoute(
    UserSession session,
    String routeId,
  ) async {
    return await getOutlets(session, routeId: routeId);
  }

  /// Get all available routes (OFFLINE CAPABLE)
  static Future<List<Map<String, String>>> getAvailableRoutes(
    UserSession session,
  ) async {
    try {
      // Try local first
      final db = await _dbService.database;
      final result = await db.rawQuery(
        '''
        SELECT DISTINCT route_id, route_name 
        FROM outlets 
        WHERE owner_id = ? AND business_id = ? AND is_active = 1 AND route_id != ''
        ORDER BY route_name
      ''',
        [session.ownerId, session.businessId],
      );

      final localRoutes =
          result
              .map(
                (row) => {
                  'routeId': row['route_id'] as String,
                  'routeName':
                      (row['route_name'] as String?) ??
                      'Route ${row['route_id']}',
                },
              )
              .toList();

      // If online, also try to get from Firebase
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        try {
          final snapshot =
              await _firestore
                  .collection('owners')
                  .doc(session.ownerId)
                  .collection('businesses')
                  .doc(session.businessId)
                  .collection('customers')
                  .where('customerType', isEqualTo: 'outlet')
                  .where('isActive', isEqualTo: true)
                  .get();

          final firebaseRoutes = <String, String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final routeId = data['routeId'] as String?;
            final routeName = data['routeName'] as String?;

            if (routeId != null && routeId.isNotEmpty) {
              firebaseRoutes[routeId] = routeName ?? 'Route $routeId';
            }
          }

          final onlineRoutes =
              firebaseRoutes.entries
                  .map((e) => {'routeId': e.key, 'routeName': e.value})
                  .toList();

          // Merge and return unique routes (prefer online data)
          final allRoutes = <String, String>{};
          for (final route in localRoutes) {
            allRoutes[route['routeId']!] = route['routeName']!;
          }
          for (final route in onlineRoutes) {
            allRoutes[route['routeId']!] = route['routeName']!;
          }

          return allRoutes.entries
              .map((e) => {'routeId': e.key, 'routeName': e.value})
              .toList();
        } catch (e) {
          print('Error getting routes from Firebase (using local): $e');
        }
      }

      return localRoutes;
    } catch (e) {
      print('Error getting available routes: $e');
      return [];
    }
  }

  /// Sync pending outlets to customers collection (ENHANCED)
  static Future<Map<String, dynamic>> syncPendingOutlets(
    UserSession session,
  ) async {
    try {
      print('Syncing pending outlets to customers collection...');

      final db = await _dbService.database;
      final List<Map<String, dynamic>> pendingOutlets = await db.query(
        'outlets',
        where: 'owner_id = ? AND business_id = ? AND sync_status = ?',
        whereArgs: [session.ownerId, session.businessId, 'pending'],
      );

      print('Found ${pendingOutlets.length} pending outlets to sync');

      int successCount = 0;
      int failCount = 0;
      final List<String> errors = [];

      for (final outletData in pendingOutlets) {
        try {
          await _syncSingleOutletToCustomers(session, outletData);

          // Mark as synced
          await db.update(
            'outlets',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [outletData['id']],
          );

          successCount++;
          print('Synced outlet to customers: ${outletData['outlet_name']}');
        } catch (e) {
          failCount++;
          final error = 'Failed to sync ${outletData['outlet_name']}: $e';
          errors.add(error);
          print(error);
        }
      }

      return {
        'success': true,
        'syncedCount': successCount,
        'failedCount': failCount,
        'totalPending': pendingOutlets.length,
        'errors': errors,
      };
    } catch (e) {
      print('Error syncing pending outlets: $e');
      return {
        'success': false,
        'error': e.toString(),
        'syncedCount': 0,
        'failedCount': 0,
        'totalPending': 0,
      };
    }
  }

  /// Sync single outlet to Firebase customers collection
  static Future<void> _syncSingleOutletToCustomers(
    UserSession session,
    Map<String, dynamic> outletData,
  ) async {
    // Generate new Firebase ID for offline outlets
    final docRef =
        _firestore
            .collection('owners')
            .doc(session.ownerId)
            .collection('businesses')
            .doc(session.businessId)
            .collection('customers')
            .doc();

    // Upload image if exists
    String? imageUrl;
    if (outletData['image_base64'] != null) {
      imageUrl = await _uploadImageToStorage(
        outletId: docRef.id,
        imageBase64: outletData['image_base64'],
        session: session,
      );
    }

    final firebaseData = {
      'id': docRef.id,
      'outletName': outletData['outlet_name'],
      'address': outletData['address'],
      'phoneNumber': outletData['phone'],
      'coordinates': {
        'latitude': outletData['latitude'],
        'longitude': outletData['longitude'],
      },
      'ownerName': outletData['owner_name'],
      'outletType': outletData['outlet_type'],
      'imageUrl': imageUrl ?? outletData['firebase_image_url'],
      'isActive': outletData['is_active'] == 1,
      'businessId': session.businessId,
      'ownerId': session.ownerId,
      'createdBy': outletData['created_by'],
      'routeId': outletData['route_id'] ?? '',
      'routeName': outletData['route_name'],
      'createdAt': FieldValue.serverTimestamp(),
      'registeredDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'customerType': 'outlet',
      'status': 'active',
      'registeredBy': session.employeeId,
      'lastVisit': null,
      'totalOrders': 0,
      'totalValue': 0.0,
    };

    await docRef.set(firebaseData);

    // Update local database with new Firebase ID
    final db = await _dbService.database;
    await db.update(
      'outlets',
      {
        'firebase_id': docRef.id,
        'firebase_image_url': imageUrl,
        'sync_status': 'synced',
      },
      where: 'id = ?',
      whereArgs: [outletData['id']],
    );
  }

  /// Update outlet (OFFLINE CAPABLE)
  static Future<void> updateOutlet({
    required UserSession session,
    required String outletId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        try {
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('customers')
              .doc(outletId)
              .update({...updates, 'updatedAt': FieldValue.serverTimestamp()});

          // Also update local
          final db = await _dbService.database;
          await db.update(
            'outlets',
            {
              ...updates,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_status': 'synced',
            },
            where: 'id = ?',
            whereArgs: [outletId],
          );
        } catch (e) {
          print('Online update failed, saving offline: $e');
          // Fallback to offline update
          final db = await _dbService.database;
          await db.update(
            'outlets',
            {
              ...updates,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_status': 'pending',
            },
            where: 'id = ?',
            whereArgs: [outletId],
          );
        }
      } else {
        // Update local database only
        final db = await _dbService.database;
        await db.update(
          'outlets',
          {
            ...updates,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [outletId],
        );
      }
    } catch (e) {
      print('Error updating outlet: $e');
      rethrow;
    }
  }

  /// Delete outlet (OFFLINE CAPABLE)
  static Future<void> deleteOutlet({
    required UserSession session,
    required String outletId,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        try {
          // Soft delete in Firebase
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('customers')
              .doc(outletId)
              .update({
                'isActive': false,
                'deletedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

          // Also update local
          final db = await _dbService.database;
          await db.update(
            'outlets',
            {
              'is_active': 0,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_status': 'synced',
            },
            where: 'id = ?',
            whereArgs: [outletId],
          );
        } catch (e) {
          print('Online delete failed, saving offline: $e');
          // Fallback to offline delete
          final db = await _dbService.database;
          await db.update(
            'outlets',
            {
              'is_active': 0,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
              'sync_status': 'pending',
            },
            where: 'id = ?',
            whereArgs: [outletId],
          );
        }
      } else {
        // Update local database only
        final db = await _dbService.database;
        await db.update(
          'outlets',
          {
            'is_active': 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [outletId],
        );
      }
    } catch (e) {
      print('Error deleting outlet: $e');
      rethrow;
    }
  }

  /// Get offline outlet count
  static Future<int> getOfflineOutletCount(UserSession session) async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM outlets WHERE owner_id = ? AND business_id = ? AND sync_status = ?',
        [session.ownerId, session.businessId, 'pending'],
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      print('Error getting offline outlet count: $e');
      return 0;
    }
  }
}
