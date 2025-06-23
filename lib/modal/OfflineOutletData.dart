// Add these classes at the top of your home page file (after imports):

// Model class for offline outlet data
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineOutletData {
  final String id;
  final String outletName;
  final String address;
  final String phoneNumber;
  final double latitude;
  final double longitude;
  final String ownerName;
  final String outletType;
  final String? imageBase64;
  final String? imagePath;
  final DateTime createdAt;
  final String businessId;
  final String ownerId;

  OfflineOutletData({
    required this.id,
    required this.outletName,
    required this.address,
    required this.phoneNumber,
    required this.latitude,
    required this.longitude,
    required this.ownerName,
    required this.outletType,
    this.imageBase64,
    this.imagePath,
    required this.createdAt,
    required this.businessId,
    required this.ownerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outletName': outletName,
      'address': address,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'ownerName': ownerName,
      'outletType': outletType,
      'imageBase64': imageBase64,
      'imagePath': imagePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'businessId': businessId,
      'ownerId': ownerId,
    };
  }

  factory OfflineOutletData.fromJson(Map<String, dynamic> json) {
    return OfflineOutletData(
      id: json['id'],
      outletName: json['outletName'],
      address: json['address'],
      phoneNumber: json['phoneNumber'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      ownerName: json['ownerName'],
      outletType: json['outletType'],
      imageBase64: json['imageBase64'],
      imagePath: json['imagePath'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      businessId: json['businessId'],
      ownerId: json['ownerId'],
    );
  }
}

// Offline storage service
class OfflineStorageService {
  static const String _offlineOutletsKey = 'offline_outlets';

  static Future<void> saveOfflineOutlet(OfflineOutletData outlet) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineOutlets = prefs.getStringList(_offlineOutletsKey) ?? [];

    offlineOutlets.add(jsonEncode(outlet.toJson()));
    await prefs.setStringList(_offlineOutletsKey, offlineOutlets);
  }

  static Future<List<OfflineOutletData>> getOfflineOutlets() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineOutlets = prefs.getStringList(_offlineOutletsKey) ?? [];

    return offlineOutlets.map((outletJson) {
      return OfflineOutletData.fromJson(jsonDecode(outletJson));
    }).toList();
  }

  static Future<void> removeOfflineOutlet(String outletId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineOutlets = prefs.getStringList(_offlineOutletsKey) ?? [];

    offlineOutlets.removeWhere((outletJson) {
      final outlet = OfflineOutletData.fromJson(jsonDecode(outletJson));
      return outlet.id == outletId;
    });

    await prefs.setStringList(_offlineOutletsKey, offlineOutlets);
  }

  static Future<void> clearAllOfflineOutlets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineOutletsKey);
  }

  static Future<int> getOfflineOutletCount() async {
    final outlets = await getOfflineOutlets();
    return outlets.length;
  }
}
