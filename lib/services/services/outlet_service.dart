// Add these methods to your lib/services/services/outlet_service.dart file

import 'dart:convert';
import 'dart:typed_data';
import 'package:lumorabiz_billing/models/outlet.dart';
import 'package:lumorabiz_billing/models/user_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class OutletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Add outlet online
  static Future<String> addOutletOnline({
    required Outlet outlet,
    required UserSession userSession,
    String? imageBase64,
  }) async {
    try {
      // Create document reference in customers collection
      final docRef =
          _firestore
              .collection('owners')
              .doc(userSession.ownerId)
              .collection('businesses')
              .doc(userSession.businessId)
              .collection('customers')
              .doc();

      // Prepare outlet data
      final outletData = outlet.toFirestore();
      outletData.addAll({
        'id': docRef.id,
        'ownerId': userSession.ownerId,
        'businessId': userSession.businessId,
        'createdBy': userSession.employeeId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Upload image if provided
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        final imageUrl = await _uploadImageToStorage(
          outletId: docRef.id,
          imageBase64: imageBase64,
          userSession: userSession,
        );
        outletData['imageUrl'] = imageUrl;
      }

      // Save to Firestore customers collection
      await docRef.set(outletData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add outlet online: $e');
    }
  }

  // Add outlet offline
  static Future<String> addOutletOffline({
    required Map<String, dynamic> outletData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineOutlets =
          prefs.getStringList('offline_outlets') ?? [];

      // Generate offline ID
      final outletId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      outletData['id'] = outletId;
      outletData['isActive'] = true;

      // Add to offline storage
      offlineOutlets.add(jsonEncode(outletData));
      await prefs.setStringList('offline_outlets', offlineOutlets);

      return outletId;
    } catch (e) {
      throw Exception('Failed to add outlet offline: $e');
    }
  }

  // Get all outlets (online + offline)
  static Future<List<Outlet>> getAllOutlets(UserSession userSession) async {
    try {
      final List<Outlet> allOutlets = [];

      // Get online outlets from customers collection
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

        for (final doc in querySnapshot.docs) {
          try {
            final outlet = Outlet.fromFirestore(doc.data(), doc.id);
            allOutlets.add(outlet);
          } catch (e) {
            print('Error parsing outlet ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('Error loading online outlets: $e');
      }

      // Get offline outlets
      try {
        final prefs = await SharedPreferences.getInstance();
        final offlineOutlets = prefs.getStringList('offline_outlets') ?? [];

        for (final outletJson in offlineOutlets) {
          try {
            final data = jsonDecode(outletJson) as Map<String, dynamic>;
            final outlet = _convertOfflineDataToOutlet(data);
            allOutlets.add(outlet);
          } catch (e) {
            print('Error parsing offline outlet: $e');
          }
        }
      } catch (e) {
        print('Error loading offline outlets: $e');
      }

      return allOutlets;
    } catch (e) {
      throw Exception('Failed to load outlets: $e');
    }
  }

  // Sync offline outlets
  static Future<SyncResult> syncOfflineOutlets(UserSession userSession) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOutlets = prefs.getStringList('offline_outlets') ?? [];

      if (offlineOutlets.isEmpty) {
        return SyncResult(success: true, syncedCount: 0, failedCount: 0);
      }

      int syncedCount = 0;
      int failedCount = 0;
      final List<String> remainingOutlets = [];

      for (final outletJson in offlineOutlets) {
        try {
          final data = jsonDecode(outletJson) as Map<String, dynamic>;

          // Create new document reference in customers collection
          final docRef =
              _firestore
                  .collection('owners')
                  .doc(userSession.ownerId)
                  .collection('businesses')
                  .doc(userSession.businessId)
                  .collection('customers')
                  .doc();

          // Prepare data for Firestore
          final firestoreData = Map<String, dynamic>.from(data);
          firestoreData['id'] = docRef.id;
          firestoreData.remove('imageBase64'); // Remove base64 before saving

          // Upload image if exists
          if (data['imageBase64'] != null && data['imageBase64'].isNotEmpty) {
            final imageUrl = await _uploadImageToStorage(
              outletId: docRef.id,
              imageBase64: data['imageBase64'],
              userSession: userSession,
            );
            firestoreData['imageUrl'] = imageUrl;
          }

          // Set timestamps
          firestoreData['createdAt'] = FieldValue.serverTimestamp();
          firestoreData['updatedAt'] = FieldValue.serverTimestamp();
          firestoreData['isActive'] = true;

          // Save to Firestore customers collection
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
          'customer_${outletId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference storageRef = _storage
          .ref()
          .child('owners')
          .child(userSession.ownerId)
          .child('businesses')
          .child(userSession.businessId)
          .child('customers')
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
      routeName: data['routeName'] ?? '',
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
      // If it's an offline outlet (shorter ID), remove from local storage
      if (outletId.length <= 15 || outletId.startsWith('offline_')) {
        final prefs = await SharedPreferences.getInstance();
        List<String> offlineOutlets =
            prefs.getStringList('offline_outlets') ?? [];

        offlineOutlets.removeWhere((outletJson) {
          final data = jsonDecode(outletJson) as Map<String, dynamic>;
          return data['id'] == outletId;
        });

        await prefs.setStringList('offline_outlets', offlineOutlets);
      } else {
        // Online outlet - mark as inactive in Firestore customers collection
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
      }
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
