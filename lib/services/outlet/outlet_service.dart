// lib/services/outlet/outlet_service.dart (Corrected)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lumorabiz_billing/services/local/database_service.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../../models/outlet.dart';
import '../../models/user_session.dart';

class OutletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseService _dbService = DatabaseService();

  // Get all outlets for the business
  static Future<List<Outlet>> getOutlets(UserSession session) async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Load from Firebase and sync to local
        return await _getOutletsFromFirebase(session);
      } else {
        // Load from local database
        return await _getOutletsFromLocal(session);
      }
    } catch (e) {
      print('Error loading outlets: $e');
      // Fallback to local data
      return await _getOutletsFromLocal(session);
    }
  }

  // Get outlets from Firebase
  static Future<List<Outlet>> _getOutletsFromFirebase(
    UserSession session,
  ) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('outlets')
              .where('isActive', isEqualTo: true)
              .orderBy('outletName')
              .get();

      final outlets =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Outlet.fromFirestore(data, doc.id);
          }).toList();

      // Sync to local database
      await _syncOutletsToLocal(outlets);

      return outlets;
    } catch (e) {
      print('Error getting outlets from Firebase: $e');
      throw e;
    }
  }

  // Get outlets from local database
  static Future<List<Outlet>> _getOutletsFromLocal(UserSession session) async {
    try {
      final outletsData = await _dbService.getOutlets(
        session.ownerId,
        session.businessId,
      );

      return outletsData.map((data) => Outlet.fromSQLite(data)).toList();
    } catch (e) {
      print('Error getting outlets from local database: $e');
      throw e;
    }
  }

  // Sync outlets to local database
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

  // Get specific outlet by ID
  static Future<Outlet?> getOutletById({
    required UserSession session,
    required String outletId,
  }) async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Get from Firebase
        final DocumentSnapshot doc =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('outlets')
                .doc(outletId)
                .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return Outlet.fromFirestore(data, doc.id);
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
      print('Error getting outlet by ID: $e');
      return null;
    }
  }

  // Add new outlet
  static Future<String> addOutlet({
    required UserSession session,
    required Map<String, dynamic> outletData,
    String? imageUrl,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        return await _addOutletOnline(session, outletData, imageUrl);
      } else {
        return await _addOutletOffline(session, outletData, imageUrl);
      }
    } catch (e) {
      print('Error adding outlet: $e');
      rethrow;
    }
  }

  // Add outlet online
  static Future<String> _addOutletOnline(
    UserSession session,
    Map<String, dynamic> outletData,
    String? imageUrl,
  ) async {
    final docRef =
        _firestore
            .collection('owners')
            .doc(session.ownerId)
            .collection('businesses')
            .doc(session.businessId)
            .collection('outlets')
            .doc();

    final data = {
      ...outletData,
      'id': docRef.id,
      'imageUrl': imageUrl,
      'ownerId': session.ownerId,
      'businessId': session.businessId,
      'createdBy': session.employeeId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
    return docRef.id;
  }

  // Add outlet offline
  static Future<String> _addOutletOffline(
    UserSession session,
    Map<String, dynamic> outletData,
    String? imageUrl,
  ) async {
    final outletId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    final data = {
      ...outletData,
      'id': outletId,
      'firebase_image_url': imageUrl,
      'owner_id': session.ownerId,
      'business_id': session.businessId,
      'created_by': session.employeeId,
      'is_active': 1,
      'sync_status': 'pending',
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    };

    await _dbService.insertOutlet(data);
    return outletId;
  }

  // Update outlet
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
            .collection('outlets')
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
      print('Error updating outlet: $e');
      rethrow;
    }
  }

  // Delete outlet (set inactive)
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
        await _firestore
            .collection('owners')
            .doc(session.ownerId)
            .collection('businesses')
            .doc(session.businessId)
            .collection('outlets')
            .doc(outletId)
            .update({
              'isActive': false,
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
      print('Error deleting outlet: $e');
      rethrow;
    }
  }

  // Search outlets
  static Future<List<Outlet>> searchOutlets({
    required UserSession session,
    required String query,
  }) async {
    try {
      final outlets = await getOutlets(session);
      final lowerQuery = query.toLowerCase();

      return outlets.where((outlet) {
        return outlet.outletName.toLowerCase().contains(lowerQuery) ||
            outlet.address.toLowerCase().contains(lowerQuery) ||
            outlet.ownerName.toLowerCase().contains(lowerQuery) ||
            outlet.phoneNumber.contains(query);
      }).toList();
    } catch (e) {
      print('Error searching outlets: $e');
      return [];
    }
  }

  // Get outlets by route
  static Future<List<Outlet>> getOutletsByRoute({
    required UserSession session,
    required String routeId,
  }) async {
    try {
      final outlets = await getOutlets(session);
      return outlets.where((outlet) => outlet.routeId == routeId).toList();
    } catch (e) {
      print('Error getting outlets by route: $e');
      return [];
    }
  }

  // Calculate distance between two points (in kilometers)
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get nearby outlets
  static Future<List<Outlet>> getNearbyOutlets({
    required UserSession session,
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final outlets = await getOutlets(session);

      final nearbyOutlets = <Outlet>[];
      for (final outlet in outlets) {
        final distance = calculateDistance(
          lat1: latitude,
          lon1: longitude,
          lat2: outlet.latitude,
          lon2: outlet.longitude,
        );

        if (distance <= radiusKm) {
          nearbyOutlets.add(outlet);
        }
      }

      // Sort by distance
      nearbyOutlets.sort((a, b) {
        final distanceA = calculateDistance(
          lat1: latitude,
          lon1: longitude,
          lat2: a.latitude,
          lon2: a.longitude,
        );
        final distanceB = calculateDistance(
          lat1: latitude,
          lon1: longitude,
          lat2: b.latitude,
          lon2: b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      return nearbyOutlets;
    } catch (e) {
      print('Error getting nearby outlets: $e');
      return [];
    }
  }

  // Get outlet statistics
  static Future<Map<String, dynamic>> getOutletStatistics(
    UserSession session,
  ) async {
    try {
      final outlets = await getOutlets(session);

      final stats = <String, int>{};
      int totalOutlets = outlets.length;
      int activeOutlets = 0;

      for (final outlet in outlets) {
        if (outlet.isActive) activeOutlets++;

        final type = outlet.outletType;
        stats[type] = (stats[type] ?? 0) + 1;
      }

      return {
        'totalOutlets': totalOutlets,
        'activeOutlets': activeOutlets,
        'inactiveOutlets': totalOutlets - activeOutlets,
        'outletsByType': stats,
      };
    } catch (e) {
      print('Error getting outlet statistics: $e');
      return {
        'totalOutlets': 0,
        'activeOutlets': 0,
        'inactiveOutlets': 0,
        'outletsByType': <String, int>{},
      };
    }
  }
}
