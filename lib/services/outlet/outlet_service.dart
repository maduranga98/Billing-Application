// lib/services/outlet/outlet_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../../models/outlet.dart';
import '../../models/user_session.dart';
import '../local/database_service.dart';

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
        final outletsData = await _dbService.getOutlets(
          session.ownerId,
          session.businessId,
        );

        final outletData =
            outletsData.where((data) => data['id'] == outletId).toList();
        if (outletData.isNotEmpty) {
          return Outlet.fromSQLite(outletData.first);
        }
      }

      return null;
    } catch (e) {
      print('Error getting outlet by ID: $e');
      return null;
    }
  }

  // Search outlets
  static Future<List<Outlet>> searchOutlets({
    required UserSession session,
    required String query,
  }) async {
    try {
      final outlets = await getOutlets(session);

      if (query.isEmpty) return outlets;

      return outlets.where((outlet) {
        return outlet.outletName.toLowerCase().contains(query.toLowerCase()) ||
            outlet.address.toLowerCase().contains(query.toLowerCase()) ||
            outlet.ownerName.toLowerCase().contains(query.toLowerCase()) ||
            outlet.phoneNumber.contains(query);
      }).toList();
    } catch (e) {
      print('Error searching outlets: $e');
      return [];
    }
  }

  // Get outlets by type
  static Future<List<Outlet>> getOutletsByType({
    required UserSession session,
    required String outletType,
  }) async {
    try {
      final outlets = await getOutlets(session);
      return outlets
          .where((outlet) => outlet.outletType == outletType)
          .toList();
    } catch (e) {
      print('Error getting outlets by type: $e');
      return [];
    }
  }

  // Get outlets in route
  static Future<List<Outlet>> getOutletsInRoute({
    required UserSession session,
    required String routeId,
  }) async {
    try {
      final outlets = await getOutlets(session);
      return outlets.where((outlet) => outlet.routeId == routeId).toList();
    } catch (e) {
      print('Error getting outlets in route: $e');
      return [];
    }
  }

  // Get nearby outlets (if location is available)
  static Future<List<Outlet>> getNearbyOutlets({
    required UserSession session,
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final outlets = await getOutlets(session);

      return outlets.where((outlet) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          outlet.latitude,
          outlet.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      print('Error getting nearby outlets: $e');
      return [];
    }
  }

  // Calculate distance between two coordinates using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
