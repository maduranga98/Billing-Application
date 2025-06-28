// lib/models/user_session.dart (Updated with Route Information)
class UserSession {
  final String userId;
  final String ownerId;
  final String businessId;
  final String employeeId;
  final String username;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? imageUrl;
  final DateTime loginTime;

  // Route information from today's loading
  final String? assignedRouteId;
  final String? assignedRouteName;
  final List<String>? assignedRouteAreas;

  UserSession({
    required this.userId,
    required this.ownerId,
    required this.businessId,
    required this.employeeId,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.imageUrl,
    required this.loginTime,
    this.assignedRouteId,
    this.assignedRouteName,
    this.assignedRouteAreas,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'ownerId': ownerId,
      'businessId': businessId,
      'employeeId': employeeId,
      'username': username,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'imageUrl': imageUrl,
      'loginTime': loginTime.millisecondsSinceEpoch,
      'assignedRouteId': assignedRouteId,
      'assignedRouteName': assignedRouteName,
      'assignedRouteAreas': assignedRouteAreas,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['userId'],
      ownerId: json['ownerId'],
      businessId: json['businessId'],
      employeeId: json['employeeId'],
      username: json['username'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      imageUrl: json['imageUrl'],
      loginTime: DateTime.fromMillisecondsSinceEpoch(json['loginTime']),
      assignedRouteId: json['assignedRouteId'],
      assignedRouteName: json['assignedRouteName'],
      assignedRouteAreas:
          json['assignedRouteAreas'] != null
              ? List<String>.from(json['assignedRouteAreas'])
              : null,
    );
  }

  // Helper method to get Firebase base path
  String get firebasePath => 'owners/$ownerId/businesses/$businessId';

  // Check if user has route assigned
  bool get hasRouteAssigned =>
      assignedRouteId != null && assignedRouteId!.isNotEmpty;

  // Get route display text
  String get routeDisplayText {
    if (!hasRouteAssigned) return 'No Route Assigned';

    final areas =
        assignedRouteAreas?.isNotEmpty == true
            ? ' (${assignedRouteAreas!.join(', ')})'
            : '';

    return '${assignedRouteName ?? 'Unknown Route'}$areas';
  }

  // Create updated session with route information
  UserSession copyWithRoute({
    String? routeId,
    String? routeName,
    List<String>? routeAreas,
  }) {
    return UserSession(
      userId: userId,
      ownerId: ownerId,
      businessId: businessId,
      employeeId: employeeId,
      username: username,
      name: name,
      email: email,
      phone: phone,
      role: role,
      imageUrl: imageUrl,
      loginTime: loginTime,
      assignedRouteId: routeId ?? assignedRouteId,
      assignedRouteName: routeName ?? assignedRouteName,
      assignedRouteAreas: routeAreas ?? assignedRouteAreas,
    );
  }
}
