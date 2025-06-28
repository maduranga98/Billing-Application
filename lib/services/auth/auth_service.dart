// lib/services/auth/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../models/user_session.dart';
import '../loading/loading_service.dart';

class AuthService {
  static const String _sessionKey = 'user_session';
  static const int _sessionValidityHours = 24;

  // Online authentication - queries global sales_reps collection and loads loading data
  static Future<UserSession?> authenticateOnline(
    String username,
    String password,
  ) async {
    try {
      print('Authenticating user: $username');

      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('sales_reps')
              .where('username', isEqualTo: username)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('User not found or inactive');
      }

      final DocumentSnapshot userDoc = querySnapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;

      // Verify password
      if (userData['password'] != password) {
        throw Exception('Invalid password');
      }

      print('User authenticated successfully');

      // Create basic session
      UserSession session = UserSession(
        userId: userDoc.id,
        ownerId: userData['ownerId'],
        businessId: userData['businessId'],
        employeeId: userData['employeeId'],
        username: userData['username'],
        name: userData['name'],
        email: userData['email'],
        phone: userData['phone'],
        role: userData['role'],
        imageUrl: userData['imageUrl'],
        loginTime: DateTime.now(),
      );

      print('Basic session created, now loading route data...');

      // Load route information from today's loading
      try {
        final loading = await LoadingService.getTodaysLoading(session);

        if (loading != null && loading.routeId.isNotEmpty) {
          print('Loading found with route: ${loading.routeId}');

          // Update session with route information
          session = session.copyWithRoute(
            routeId: loading.routeId,
            routeName: loading.todayRoute?.name ?? loading.routeDisplayName,
            routeAreas: loading.routeAreas,
          );

          print('Session updated with route: ${session.assignedRouteName}');
        } else {
          print('No loading found or no route assigned');
        }
      } catch (e) {
        print('Error loading route data during authentication: $e');
        // Continue with basic session even if route loading fails
      }

      // Save session
      await _saveSession(session);

      // Save offline credentials for future use
      await _saveOfflineCredentials(username, password, session);

      return session;
    } catch (e) {
      print('Authentication error: $e');
      throw e;
    }
  }

  // Offline authentication
  static Future<UserSession?> authenticateOffline(
    String username,
    String password,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsData = prefs.getString('offline_credentials');

      if (credentialsData == null) return null;

      final credentials = jsonDecode(credentialsData);
      final storedUsername = credentials['username'];
      final storedHashedPassword = credentials['hashedPassword'];
      final hashedInputPassword = _hashPassword(password);

      if (storedUsername == username &&
          storedHashedPassword == hashedInputPassword) {
        final sessionData = credentials['session'];
        final session = UserSession.fromJson(sessionData);

        // Check if session is still valid
        if (isSessionValid(session)) {
          return session;
        }
      }

      return null;
    } catch (e) {
      print('Offline authentication error: $e');
      return null;
    }
  }

  // Save credentials for offline access (public method)
  static Future<void> saveOfflineCredentials(
    String username,
    String password,
    UserSession session,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedPassword = _hashPassword(password);

      final credentials = {
        'username': username,
        'hashedPassword': hashedPassword,
        'session': session.toJson(),
      };

      await prefs.setString('offline_credentials', jsonEncode(credentials));
      print('Offline credentials saved successfully');
    } catch (e) {
      print('Error saving offline credentials: $e');
    }
  }

  // Private helper method for internal use
  static Future<void> _saveOfflineCredentials(
    String username,
    String password,
    UserSession session,
  ) async {
    await saveOfflineCredentials(username, password, session);
  }

  // Hash password for security
  static String _hashPassword(String password) {
    // Simple hash - in production, use a more secure method
    return password.hashCode.toString();
  }

  // Get current user session
  static Future<UserSession?> getCurrentUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);

      if (sessionJson != null) {
        final sessionData = jsonDecode(sessionJson);
        return UserSession.fromJson(sessionData);
      }

      return null;
    } catch (e) {
      print('Error getting current session: $e');
      return null;
    }
  }

  // Save session to local storage
  static Future<void> _saveSession(UserSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(session.toJson());
      await prefs.setString(_sessionKey, sessionJson);
    } catch (e) {
      print('Error saving session: $e');
      throw e;
    }
  }

  // Update session with route information
  static Future<void> updateSessionWithRoute({
    required String routeId,
    required String? routeName,
    required List<String>? routeAreas,
  }) async {
    try {
      final currentSession = await getCurrentUserSession();
      if (currentSession != null) {
        final updatedSession = currentSession.copyWithRoute(
          routeId: routeId,
          routeName: routeName,
          routeAreas: routeAreas,
        );
        await _saveSession(updatedSession);
      }
    } catch (e) {
      print('Error updating session with route: $e');
    }
  }

  // Check if session is valid
  static bool isSessionValid(UserSession session) {
    final now = DateTime.now();
    final sessionAge = now.difference(session.loginTime);
    return sessionAge.inHours < _sessionValidityHours;
  }

  // Refresh session (extend validity)
  static Future<UserSession?> refreshSession() async {
    try {
      final currentSession = await getCurrentUserSession();
      if (currentSession != null && isSessionValid(currentSession)) {
        // Update login time to extend session
        final refreshedSession = UserSession(
          userId: currentSession.userId,
          ownerId: currentSession.ownerId,
          businessId: currentSession.businessId,
          employeeId: currentSession.employeeId,
          username: currentSession.username,
          name: currentSession.name,
          email: currentSession.email,
          phone: currentSession.phone,
          role: currentSession.role,
          imageUrl: currentSession.imageUrl,
          loginTime: DateTime.now(), // Update login time
          assignedRouteId: currentSession.assignedRouteId,
          assignedRouteName: currentSession.assignedRouteName,
          assignedRouteAreas: currentSession.assignedRouteAreas,
        );

        await _saveSession(refreshedSession);
        return refreshedSession;
      }

      return null;
    } catch (e) {
      print('Error refreshing session: $e');
      return null;
    }
  }

  // Clear session (logout)
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      print('Error clearing session: $e');
      throw e;
    }
  }

  // Logout
  static Future<void> logout() async {
    await clearSession();
  }

  // Validate and refresh session if needed
  static Future<UserSession?> validateAndRefreshSession() async {
    try {
      final session = await getCurrentUserSession();

      if (session == null) return null;

      if (isSessionValid(session)) {
        return session;
      } else {
        // Session expired
        await clearSession();
        return null;
      }
    } catch (e) {
      print('Error validating session: $e');
      return null;
    }
  }

  // Get user display name
  static String getUserDisplayName(UserSession? session) {
    if (session == null) return 'User';

    final name = session.name.trim();
    if (name.isEmpty) return session.username;

    return name;
  }

  // Get user initials for avatar
  static String getUserInitials(UserSession? session) {
    if (session == null) return 'U';

    final name = session.name.trim();
    if (name.isEmpty)
      return session.username.isNotEmpty
          ? session.username[0].toUpperCase()
          : 'U';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  // Get greeting message based on time
  static String getGreetingMessage(UserSession? session) {
    if (session == null) return 'Hello!';

    final hour = DateTime.now().hour;
    final firstName = session.name.split(' ').first.trim();
    final displayName = firstName.isNotEmpty ? firstName : session.username;

    if (hour < 12) {
      return 'Good morning, $displayName!';
    } else if (hour < 17) {
      return 'Good afternoon, $displayName!';
    } else {
      return 'Good evening, $displayName!';
    }
  }
}
