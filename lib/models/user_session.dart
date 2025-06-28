// lib/models/user_session.dart
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
      userId: json['userId'] ?? '',
      ownerId: json['ownerId'] ?? '',
      businessId: json['businessId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      imageUrl: json['imageUrl'],
      loginTime: DateTime.fromMillisecondsSinceEpoch(json['loginTime'] ?? 0),
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

  // Get short route display (name only)
  String get routeDisplayShort {
    if (!hasRouteAssigned) return 'No Route';
    return assignedRouteName ?? 'Unknown Route';
  }

  // Get areas display text
  String get routeAreasText {
    if (assignedRouteAreas == null || assignedRouteAreas!.isEmpty) {
      return 'No areas';
    }
    return assignedRouteAreas!.join(', ');
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
      assignedRouteId: routeId,
      assignedRouteName: routeName,
      assignedRouteAreas: routeAreas,
    );
  }

  // Create copy with updated basic information
  UserSession copyWith({
    String? userId,
    String? ownerId,
    String? businessId,
    String? employeeId,
    String? username,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? imageUrl,
    DateTime? loginTime,
    String? assignedRouteId,
    String? assignedRouteName,
    List<String>? assignedRouteAreas,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      ownerId: ownerId ?? this.ownerId,
      businessId: businessId ?? this.businessId,
      employeeId: employeeId ?? this.employeeId,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      imageUrl: imageUrl ?? this.imageUrl,
      loginTime: loginTime ?? this.loginTime,
      assignedRouteId: assignedRouteId ?? this.assignedRouteId,
      assignedRouteName: assignedRouteName ?? this.assignedRouteName,
      assignedRouteAreas: assignedRouteAreas ?? this.assignedRouteAreas,
    );
  }

  // Get user's full name or username as fallback
  String get displayName {
    final trimmedName = name.trim();
    return trimmedName.isNotEmpty ? trimmedName : username;
  }

  // Get user's first name
  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : username;
  }

  // Get user initials for avatar
  String get initials {
    if (name.trim().isEmpty) {
      return username.isNotEmpty ? username[0].toUpperCase() : 'U';
    }

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return parts[0][0].toUpperCase();
    }
  }

  // Check if session is valid (not expired)
  bool get isValid {
    const sessionValidityHours = 24;
    final now = DateTime.now();
    final sessionAge = now.difference(loginTime);
    return sessionAge.inHours < sessionValidityHours;
  }

  // Get session age in hours
  int get sessionAgeInHours {
    final now = DateTime.now();
    return now.difference(loginTime).inHours;
  }

  @override
  String toString() {
    return 'UserSession(userId: $userId, name: $name, role: $role, routeId: $assignedRouteId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSession &&
        other.userId == userId &&
        other.loginTime == loginTime;
  }

  @override
  int get hashCode => userId.hashCode ^ loginTime.hashCode;
}
