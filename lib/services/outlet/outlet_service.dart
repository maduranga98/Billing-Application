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

  /// Add new outlet (handles both online and offline)
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

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        print('Adding outlet online to Firebase customers collection...');
        return await _addOutletOnline(
          session,
          outletData,
          imageBase64,
          routeId,
          routeName,
        );
      } else {
        print('Adding outlet offline to local storage...');
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

      // Also save to local database for offline access
      try {
        await _saveOutletToLocal(
          session,
          outletId,
          outletData,
          imageUrl,
          imageBase64,
          routeId,
          routeName,
        );
        print('Outlet synced to local database');
      } catch (e) {
        print('Warning: Failed to sync outlet to local database: $e');
      }

      return outletId;
    } catch (e) {
      print('Error adding outlet to customers collection: $e');
      throw Exception('Failed to save outlet: ${e.toString()}');
    }
  }

  /// Add outlet offline to local storage
  static Future<String> _addOutletOffline(
    UserSession session,
    Map<String, dynamic> outletData,
    String? imageBase64,
    String? routeId,
    String? routeName,
  ) async {
    try {
      final outletId = 'outlet_${DateTime.now().millisecondsSinceEpoch}';
      print('Creating offline outlet with ID: $outletId for route: $routeName');

      await _saveOutletToLocal(
        session,
        outletId,
        outletData,
        null,
        imageBase64,
        routeId,
        routeName,
      );
      print('Outlet saved offline successfully');

      return outletId;
    } catch (e) {
      print('Error adding outlet offline: $e');
      throw Exception('Failed to save outlet offline: ${e.toString()}');
    }
  }

  /// Save outlet to local database
  static Future<void> _saveOutletToLocal(
    UserSession session,
    String outletId,
    Map<String, dynamic> outletData,
    String? firebaseImageUrl,
    String? imageBase64,
    String? routeId,
    String? routeName,
  ) async {
    try {
      final localOutletData = {
        'id': outletId,
        'outlet_name': outletData['outletName'],
        'address': outletData['address'],
        'phone': outletData['phoneNumber'],
        'latitude': outletData['latitude'],
        'longitude': outletData['longitude'],
        'owner_name': outletData['ownerName'],
        'outlet_type': outletData['outletType'],
        'image_base64': imageBase64,
        'firebase_image_url': firebaseImageUrl,
        'owner_id': session.ownerId,
        'business_id': session.businessId,
        'created_by': session.employeeId,
        // ADDED: Route information
        'route_id': routeId ?? '',
        'route_name': routeName,
        'is_active': 1,
        'sync_status': firebaseImageUrl != null ? 'synced' : 'pending',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _dbService.insertOutlet(localOutletData);
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

  /// Get all outlets for the business from customers collection
  static Future<List<Outlet>> getOutlets(
    UserSession session, {
    String? routeId,
    String? outletType,
    bool? isActive,
  }) async {
    try {
      print('Loading outlets for business: ${session.businessId}');
      if (routeId != null) print('Filtering by route: $routeId');
      if (outletType != null) print('Filtering by type: $outletType');

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        return await _getOutletsFromFirebase(
          session,
          routeId: routeId,
          outletType: outletType,
          isActive: isActive,
        );
      } else {
        return await _getOutletsFromLocal(
          session,
          routeId: routeId,
          outletType: outletType,
          isActive: isActive,
        );
      }
    } catch (e) {
      print('Error loading outlets: $e');
      // Fallback to local data
      return await _getOutletsFromLocal(
        session,
        routeId: routeId,
        outletType: outletType,
        isActive: isActive,
      );
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

      // Build query with filters
      Query<Map<String, dynamic>> query = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('customers')
          .where('customerType', isEqualTo: 'outlet');

      // Apply filters
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      } else {
        query = query.where(
          'isActive',
          isEqualTo: true,
        ); // Default to active only
      }

      if (routeId != null && routeId.isNotEmpty) {
        query = query.where('routeId', isEqualTo: routeId);
      }

      if (outletType != null && outletType.isNotEmpty) {
        query = query.where('outletType', isEqualTo: outletType);
      }

      // Order by outlet name
      query = query.orderBy('outletName');

      final QuerySnapshot snapshot = await query.get();

      final outlets =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Outlet.fromFirestore(data, doc.id);
          }).toList();

      print('Found ${outlets.length} outlets from customers collection');
      if (routeId != null) {
        final routeOutlets = outlets.where((o) => o.routeId == routeId).length;
        print('  - $routeOutlets outlets belong to route: $routeId');
      }

      // Sync to local database
      try {
        await _syncOutletsToLocal(outlets);
        print('Outlets synced to local database');
      } catch (e) {
        print('Warning: Failed to sync outlets to local: $e');
      }

      return outlets;
    } catch (e) {
      print('Error getting outlets from customers collection: $e');
      throw e;
    }
  }

  /// Get outlets from local database
  static Future<List<Outlet>> _getOutletsFromLocal(
    UserSession session, {
    String? routeId,
    String? outletType,
    bool? isActive,
  }) async {
    try {
      print('Loading outlets from local database...');

      // Build WHERE clause with filters
      String whereClause = 'owner_id = ? AND business_id = ?';
      List<dynamic> whereArgs = [session.ownerId, session.businessId];

      if (isActive != null) {
        whereClause += ' AND is_active = ?';
        whereArgs.add(isActive ? 1 : 0);
      } else {
        whereClause += ' AND is_active = 1'; // Default to active only
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
      return [];
    }
  }

  /// Sync outlets to local database
  static Future<void> _syncOutletsToLocal(List<Outlet> outlets) async {
    try {
      for (final outlet in outlets) {
        final outletData = outlet.toSQLite();
        await _dbService.insertOutlet(outletData);
      }
    } catch (e) {
      print('Error syncing outlets to local: $e');
    }
  }

  /// Get specific outlet by ID from customers collection
  static Future<Outlet?> getOutletById({
    required UserSession session,
    required String outletId,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Get from Firebase customers collection
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
          // Verify it's an outlet customer
          if (data['customerType'] == 'outlet') {
            return Outlet.fromFirestore(data, doc.id);
          }
        }
      } else {
        // Get from local database
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
      }

      return null;
    } catch (e) {
      print('Error getting outlet by ID from customers collection: $e');
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

  /// Get all available routes (distinct route IDs and names)
  static Future<List<Map<String, String>>> getAvailableRoutes(
    UserSession session,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Get from Firebase
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

        final routes = <String, String>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final routeId = data['routeId'] as String?;
          final routeName = data['routeName'] as String?;

          if (routeId != null && routeId.isNotEmpty) {
            routes[routeId] = routeName ?? 'Route $routeId';
          }
        }

        return routes.entries
            .map((e) => {'routeId': e.key, 'routeName': e.value})
            .toList();
      } else {
        // Get from local database
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

        return result
            .map(
              (row) => {
                'routeId': row['route_id'] as String,
                'routeName':
                    (row['route_name'] as String?) ??
                    'Route ${row['route_id']}',
              },
            )
            .toList();
      }
    } catch (e) {
      print('Error getting available routes: $e');
      return [];
    }
  }

  /// Sync pending outlets to customers collection (for when app comes back online)
  static Future<void> syncPendingOutlets(UserSession session) async {
    try {
      print('Syncing pending outlets to customers collection...');

      final db = await _dbService.database;
      final List<Map<String, dynamic>> pendingOutlets = await db.query(
        'outlets',
        where: 'owner_id = ? AND business_id = ? AND sync_status = ?',
        whereArgs: [session.ownerId, session.businessId, 'pending'],
      );

      print(
        'Found ${pendingOutlets.length} pending outlets to sync to customers collection',
      );

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

          print('Synced outlet to customers: ${outletData['outlet_name']}');
        } catch (e) {
          print('Failed to sync outlet ${outletData['id']} to customers: $e');
        }
      }
    } catch (e) {
      print('Error syncing pending outlets to customers collection: $e');
    }
  }

  /// Sync single outlet to Firebase customers collection
  static Future<void> _syncSingleOutletToCustomers(
    UserSession session,
    Map<String, dynamic> outletData,
  ) async {
    final docRef = _firestore
        .collection('owners')
        .doc(session.ownerId)
        .collection('businesses')
        .doc(session.businessId)
        .collection('customers')
        .doc(outletData['id']);

    // Upload image if exists
    String? imageUrl;
    if (outletData['image_base64'] != null) {
      imageUrl = await _uploadImageToStorage(
        outletId: outletData['id'],
        imageBase64: outletData['image_base64'],
        session: session,
      );
    }

    final firebaseData = {
      'id': outletData['id'],
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
      'createdAt': FieldValue.serverTimestamp(),
      'registeredDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Customer-specific fields
      'customerType': 'outlet',
      'status': 'active',
      'registeredBy': session.employeeId,
      'lastVisit': null,
      'totalOrders': 0,
      'totalValue': 0.0,
    };

    await docRef.set(firebaseData);
  }

  /// Update outlet in customers collection
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
        await _firestore
            .collection('owners')
            .doc(session.ownerId)
            .collection('businesses')
            .doc(session.businessId)
            .collection('customers')
            .doc(outletId)
            .update({...updates, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        // Update local database
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
      print('Error updating outlet in customers collection: $e');
      rethrow;
    }
  }

  /// Delete outlet from customers collection
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
        // Soft delete - mark as inactive
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
      } else {
        // Update local database
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
      print('Error deleting outlet from customers collection: $e');
      rethrow;
    }
  }
}
