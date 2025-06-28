// lib/services/auth/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/user_session.dart';

class AuthService {
  static const String _sessionKey = 'user_session';
  static const String _offlineCredentialsKey = 'offline_credentials';

  // Hash password for security
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Save user session
  static Future<void> saveUserSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  // Get current user session
  static Future<UserSession?> getCurrentUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString(_sessionKey);
    if (sessionData == null) return null;

    try {
      return UserSession.fromJson(jsonDecode(sessionData));
    } catch (e) {
      return null;
    }
  }

  // Save credentials for offline access
  static Future<void> saveOfflineCredentials(
    String username,
    String hashedPassword,
    UserSession session,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final credentials = {
      'username': username,
      'hashedPassword': hashedPassword,
      'session': session.toJson(),
    };
    await prefs.setString(_offlineCredentialsKey, jsonEncode(credentials));
  }

  // Verify offline credentials
  static Future<UserSession?> verifyOfflineCredentials(
    String username,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final credentialsData = prefs.getString(_offlineCredentialsKey);
    if (credentialsData == null) return null;

    try {
      final credentials = jsonDecode(credentialsData);
      final storedUsername = credentials['username'];
      final storedHashedPassword = credentials['hashedPassword'];
      final hashedInputPassword = _hashPassword(password);

      if (storedUsername == username &&
          storedHashedPassword == hashedInputPassword) {
        return UserSession.fromJson(credentials['session']);
      }
    } catch (e) {
      print('Error verifying offline credentials: $e');
    }
    return null;
  }

  // Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // FIXED: Online authentication via Firestore - Now includes ownerId
  static Future<UserSession?> authenticateOnline(
    String username,
    String password,
  ) async {
    try {
      // Query sales_reps collection for the username
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

      // FIXED: Create user session with ownerId
      final session = UserSession(
        userId: userDoc.id,
        ownerId: userData['ownerId'], // CRITICAL: This was missing
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

      // Save session and offline credentials
      await saveUserSession(session);
      await saveOfflineCredentials(username, _hashPassword(password), session);

      return session;
    } catch (e) {
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

  // Check if session is still valid (8 hours)
  static bool isSessionValid(UserSession session) {
    final timeDifference = DateTime.now().difference(session.loginTime);
    return timeDifference < const Duration(hours: 8);
  }

  // Logout and clear all data
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_offlineCredentialsKey);
  }

  static Future<void> updateSessionWithRoute({
    required String routeId,
    required String routeName,
    required List<String> routeAreas,
  }) async {}
}
