// lib/models/outlet.dart (Complete updated version)
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
  final String routeId;
  final String? routeName;
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
    this.routeId = '',
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
      routeId: data['routeId'] ?? '',
      routeName: data['routeName'],
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

  // ADD THIS METHOD - This is what was missing
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outletName': outletName,
      'address': address,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'ownerName': ownerName,
      'outletType': outletType,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'businessId': businessId,
      'createdBy': createdBy,
      'routeId': routeId,
      'routeName': routeName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
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
      'routeId': routeId,
      'routeName': routeName,
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

  // Convert to JSON
  Map<String, dynamic> toJson() => toMap();

  // Create from JSON
  factory Outlet.fromJson(Map<String, dynamic> json) {
    return Outlet(
      id: json['id'] ?? '',
      outletName: json['outletName'] ?? '',
      address: json['address'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      ownerName: json['ownerName'] ?? '',
      outletType: json['outletType'] ?? '',
      imageUrl: json['imageUrl'],
      ownerId: json['ownerId'] ?? '',
      businessId: json['businessId'] ?? '',
      createdBy: json['createdBy'] ?? '',
      routeId: json['routeId'] ?? '',
      routeName: json['routeName'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  bool belongsToRoute(String checkRouteId) {
    return routeId == checkRouteId;
  }

  String get routeDisplayText {
    return routeName ?? 'Route: $routeId';
  }

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

  Outlet copyWith({
    String? id,
    String? outletName,
    String? address,
    String? phoneNumber,
    double? latitude,
    double? longitude,
    String? ownerName,
    String? outletType,
    String? imageUrl,
    String? ownerId,
    String? businessId,
    String? createdBy,
    String? routeId,
    String? routeName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Outlet(
      id: id ?? this.id,
      outletName: outletName ?? this.outletName,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ownerName: ownerName ?? this.ownerName,
      outletType: outletType ?? this.outletType,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      businessId: businessId ?? this.businessId,
      createdBy: createdBy ?? this.createdBy,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Outlet(id: $id, outletName: $outletName, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Outlet && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
