// lib/services/outlet_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lumorabiz_billing/models/outlet.dart';
import 'package:lumorabiz_billing/models/user_session.dart';
import 'package:lumorabiz_billing/services/local/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:typed_data';

class OutletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Add outlet to Firebase
  static Future<String> addOutletOnline({
    required Outlet outlet,
    required UserSession userSession,
    String? imageBase64,
  }) async {
    try {
      // Create document reference
      final docRef =
          _firestore
              .collection('owners')
              .doc(userSession.ownerId)
              .collection('businesses')
              .doc(userSession.businessId)
              .collection('customers')
              .doc();

      // Upload image if provided
      String? imageUrl;
      if (imageBase64 != null) {
        imageUrl = await _uploadImageToStorage(
          outletId: docRef.id,
          imageBase64: imageBase64,
          userSession: userSession,
        );
      }

      // Prepare outlet data
      final outletData = outlet.toFirestore();
      outletData['id'] = docRef.id;
      outletData['imageUrl'] = imageUrl;
      outletData['createdAt'] = FieldValue.serverTimestamp();
      outletData['updatedAt'] = FieldValue.serverTimestamp();

      // Save to Firestore
      await docRef.set(outletData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add outlet online: $e');
    }
  }

  // Save outlet offline
  static Future<String> addOutletOffline({
    required Map<String, dynamic> outletData,
  }) async {
    try {
      // Generate unique ID
      final String outletId = DateTime.now().millisecondsSinceEpoch.toString();
      outletData['id'] = outletId;
      outletData['syncStatus'] = 'pending';

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineOutlets =
          prefs.getStringList('offline_outlets') ?? [];
      offlineOutlets.add(jsonEncode(outletData));
      await prefs.setStringList('offline_outlets', offlineOutlets);

      // Also save to local database if available
      try {
        final dbService = DatabaseService();
        await dbService.insertOutlet(outletData);
      } catch (e) {
        print('Warning: Could not save to local database: $e');
      }

      return outletId;
    } catch (e) {
      throw Exception('Failed to add outlet offline: $e');
    }
  }

  // Get all outlets (online and offline combined)
  static Future<List<Outlet>> getAllOutlets(UserSession userSession) async {
    final List<Outlet> allOutlets = [];

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = !connectivityResult.contains(ConnectivityResult.none);

      if (isOnline) {
        // Fetch from Firebase
        final onlineOutlets = await getOnlineOutlets(userSession);
        allOutlets.addAll(onlineOutlets);
      }

      // Always fetch offline outlets
      final offlineOutlets = await getOfflineOutlets();
      allOutlets.addAll(offlineOutlets);

      return allOutlets;
    } catch (e) {
      print('Error getting all outlets: $e');
      // Fallback to offline only
      return await getOfflineOutlets();
    }
  }

  // Get online outlets from Firebase
  static Future<List<Outlet>> getOnlineOutlets(UserSession userSession) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('owners')
              .doc(userSession.ownerId)
              .collection('businesses')
              .doc(userSession.businessId)
              .collection('customers')
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => Outlet.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch online outlets: $e');
    }
  }

  // Get offline outlets
  static Future<List<Outlet>> getOfflineOutlets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOutlets = prefs.getStringList('offline_outlets') ?? [];

      return offlineOutlets.map((outletJson) {
        final data = jsonDecode(outletJson) as Map<String, dynamic>;
        return _convertOfflineDataToOutlet(data);
      }).toList();
    } catch (e) {
      print('Error getting offline outlets: $e');
      return [];
    }
  }

  // Sync offline outlets to Firebase
  static Future<SyncResult> syncOfflineOutlets(UserSession userSession) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOutlets = prefs.getStringList('offline_outlets') ?? [];

      if (offlineOutlets.isEmpty) {
        return SyncResult(success: true, syncedCount: 0, failedCount: 0);
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> remainingOutlets = [];

      for (String outletJson in offlineOutlets) {
        try {
          final data = jsonDecode(outletJson) as Map<String, dynamic>;

          // Create new document reference
          final docRef =
              _firestore
                  .collection('owners')
                  .doc(userSession.ownerId)
                  .collection('businesses')
                  .doc(userSession.businessId)
                  .collection('customers')
                  .doc();

          // Upload image if exists
          String? imageUrl;
          if (data['imageBase64'] != null) {
            imageUrl = await _uploadImageToStorage(
              outletId: docRef.id,
              imageBase64: data['imageBase64'],
              userSession: userSession,
            );
          }

          // Prepare Firestore data
          final firestoreData = {
            'id': docRef.id,
            'outletName': data['outletName'],
            'address': data['address'],
            'phoneNumber': data['phoneNumber'],
            'coordinates': {
              'latitude': data['latitude'],
              'longitude': data['longitude'],
            },
            'ownerName': data['ownerName'],
            'outletType': data['outletType'],
            'imageUrl': imageUrl,
            'ownerId': userSession.ownerId,
            'businessId': userSession.businessId,
            'createdBy': data['createdBy'],
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Save to Firestore
          await docRef.set(firestoreData);
          syncedCount++;
        } catch (e) {
          print('Failed to sync outlet: $e');
          remainingOutlets.add(outletJson);
          failedCount++;
        }
      }

      // Update offline storage with failed outlets only
      await prefs.setStringList('offline_outlets', remainingOutlets);

      return SyncResult(
        success: failedCount == 0,
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  // Upload image to Firebase Storage
  static Future<String> _uploadImageToStorage({
    required String outletId,
    required String imageBase64,
    required UserSession userSession,
  }) async {
    try {
      final Uint8List imageBytes = base64Decode(imageBase64);
      final String fileName =
          'outlet_${outletId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference storageRef = _storage
          .ref()
          .child('owners')
          .child(userSession.ownerId)
          .child('businesses')
          .child(userSession.businessId)
          .child('outlets')
          .child(outletId)
          .child('images')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putData(imageBytes);
      final TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Convert offline data to Outlet model
  static Outlet _convertOfflineDataToOutlet(Map<String, dynamic> data) {
    return Outlet(
      id: data['id'],
      outletName: data['outletName'],
      address: data['address'],
      phoneNumber: data['phoneNumber'],
      latitude: data['latitude'].toDouble(),
      longitude: data['longitude'].toDouble(),
      ownerName: data['ownerName'],
      outletType: data['outletType'],
      imageUrl: data['imageBase64'] != null ? 'offline_image' : null,
      ownerId: data['ownerId'],
      businessId: data['businessId'],
      createdBy: data['createdBy'],
      routeId: data['routeId'] ?? '',
      routeName: data['routeName'],
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
    );
  }

  // Get offline outlet count
  static Future<int> getOfflineOutletCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOutlets = prefs.getStringList('offline_outlets') ?? [];
      return offlineOutlets.length;
    } catch (e) {
      return 0;
    }
  }

  // Delete outlet
  static Future<void> deleteOutlet(
    String outletId,
    UserSession userSession,
  ) async {
    try {
      await _firestore
          .collection('owners')
          .doc(userSession.ownerId)
          .collection('businesses')
          .doc(userSession.businessId)
          .collection('customers')
          .doc(outletId)
          .update({
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to delete outlet: $e');
    }
  }

  // Update outlet
  static Future<void> updateOutlet(
    String outletId,
    Map<String, dynamic> updates,
    UserSession userSession,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('owners')
          .doc(userSession.ownerId)
          .collection('businesses')
          .doc(userSession.businessId)
          .collection('customers')
          .doc(outletId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update outlet: $e');
    }
  }
}

// Sync result model
class SyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.failedCount,
    this.errorMessage,
  });

  String get message {
    if (success) {
      return syncedCount > 0
          ? 'Successfully synced $syncedCount outlets'
          : 'No outlets to sync';
    } else {
      return 'Synced $syncedCount, failed $failedCount outlets';
    }
  }
}
