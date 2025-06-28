// lib/models/today_route.dart
class TodayRoute {
  final String routeId;
  final String name;
  final String businessId;
  final String ownerId;
  final String description;
  final List<String> areas;
  final String status;
  final double? estimatedDistance;
  final double? estimatedTime;
  final DateTime createdAt;
  final String createdBy;

  TodayRoute({
    required this.routeId,
    required this.name,
    required this.businessId,
    required this.ownerId,
    required this.description,
    required this.areas,
    required this.status,
    this.estimatedDistance,
    this.estimatedTime,
    required this.createdAt,
    required this.createdBy,
  });

  factory TodayRoute.fromMap(Map<String, dynamic> data) {
    final areasData = data['areas'] as List<dynamic>? ?? [];
    final areas = areasData.map((area) => area.toString()).toList();

    return TodayRoute(
      routeId: data['routeId'] ?? data['id'] ?? '',
      name: data['name'] ?? '',
      businessId: data['businessId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      description: data['description'] ?? '',
      areas: areas,
      status: data['status'] ?? '',
      estimatedDistance: data['estimatedDistance']?.toDouble(),
      estimatedTime: data['estimatedTime']?.toDouble(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'name': name,
      'businessId': businessId,
      'ownerId': ownerId,
      'description': description,
      'areas': areas,
      'status': status,
      'estimatedDistance': estimatedDistance,
      'estimatedTime': estimatedTime,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }

  // Get display text for areas
  String get areasDisplayText {
    if (areas.isEmpty) return 'No areas defined';
    return areas.join(', ');
  }

  // Get full route display text
  String get fullDisplayText {
    return '$name (${areasDisplayText})';
  }

  @override
  String toString() {
    return 'TodayRoute(routeId: $routeId, name: $name, areas: $areas)';
  }
}
