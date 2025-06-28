// lib/models/outlet.dart
class Outlet {
  final String id;
  final String outletName;
  final String address;
  final String phoneNumber;
  final double latitude;
  final double longitude;
  final String ownerName;
  final String outletType;
  final String? imageUrl;
  final String ownerId;
  final String businessId;
  final String createdBy;
  final String routeId; // CRITICAL: Route assignment
  final String? routeName; // For display purposes
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Outlet({
    required this.id,
    required this.outletName,
    required this.address,
    required this.phoneNumber,
    required this.latitude,
    required this.longitude,
    required this.ownerName,
    required this.outletType,
    this.imageUrl,
    required this.ownerId,
    required this.businessId,
    required this.createdBy,
    required this.routeId, // Required field
    this.routeName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Outlet.fromFirestore(Map<String, dynamic> data, String id) {
    return Outlet(
      id: id,
      outletName: data['outletName'] ?? '',
      address: data['address'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      latitude: (data['coordinates']?['latitude'] ?? 0).toDouble(),
      longitude: (data['coordinates']?['longitude'] ?? 0).toDouble(),
      ownerName: data['ownerName'] ?? '',
      outletType: data['outletType'] ?? '',
      imageUrl: data['imageUrl'],
      ownerId: data['ownerId'] ?? '',
      businessId: data['businessId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      routeId: data['routeId'] ?? '', // Load route assignment
      routeName: data['routeName'], // Optional route name
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  factory Outlet.fromSQLite(Map<String, dynamic> data) {
    return Outlet(
      id: data['id'],
      outletName: data['outlet_name'],
      address: data['address'] ?? '',
      phoneNumber: data['phone'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      ownerName: data['owner_name'] ?? '',
      outletType: data['outlet_type'] ?? '',
      imageUrl: data['firebase_image_url'],
      ownerId: data['owner_id'],
      businessId: data['business_id'],
      createdBy: data['created_by'],
      routeId: data['route_id'] ?? '',
      routeName: data['route_name'],
      isActive: (data['is_active'] ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'outletName': outletName,
      'address': address,
      'phoneNumber': phoneNumber,
      'coordinates': {'latitude': latitude, 'longitude': longitude},
      'ownerName': ownerName,
      'outletType': outletType,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'businessId': businessId,
      'createdBy': createdBy,
      'routeId': routeId, // Include route assignment
      'routeName': routeName, // Include route name for easy access
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'outlet_name': outletName,
      'address': address,
      'phone': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'owner_name': ownerName,
      'outlet_type': outletType,
      'firebase_image_url': imageUrl,
      'owner_id': ownerId,
      'business_id': businessId,
      'created_by': createdBy,
      'route_id': routeId,
      'route_name': routeName,
      'is_active': isActive ? 1 : 0,
      'sync_status': 'pending',
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Check if outlet belongs to the given route
  bool belongsToRoute(String checkRouteId) {
    return routeId == checkRouteId;
  }

  // Get display text for route
  String get routeDisplayText {
    return routeName ?? 'Route: $routeId';
  }

  // Create copy with updated route information
  Outlet copyWithRoute({String? newRouteId, String? newRouteName}) {
    return Outlet(
      id: id,
      outletName: outletName,
      address: address,
      phoneNumber: phoneNumber,
      latitude: latitude,
      longitude: longitude,
      ownerName: ownerName,
      outletType: outletType,
      imageUrl: imageUrl,
      ownerId: ownerId,
      businessId: businessId,
      createdBy: createdBy,
      routeId: newRouteId ?? routeId,
      routeName: newRouteName ?? routeName,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
