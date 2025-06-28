// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../models/user_session.dart';
import '../services/auth/auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  UserSession? _currentSession;
  AuthState _authState = AuthState.initial;
  String _errorMessage = '';

  // Getters
  UserSession? get currentSession => _currentSession;
  AuthState get authState => _authState;
  String get errorMessage => _errorMessage;

  bool get isAuthenticated =>
      _authState == AuthState.authenticated && _currentSession != null;
  bool get isLoading => _authState == AuthState.loading;
  bool get hasError => _authState == AuthState.error;

  String get userName => _currentSession?.name ?? 'User';
  String get userEmail => _currentSession?.email ?? '';
  String get userRole => _currentSession?.role ?? '';
  String get businessId => _currentSession?.businessId ?? '';
  String get ownerId => _currentSession?.ownerId ?? '';

  // Initialize auth state
  Future<void> initializeAuth() async {
    _authState = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final session = await AuthService.getCurrentUserSession();

      if (session != null) {
        // Validate session
        if (AuthService.isSessionValid(session)) {
          _currentSession = session;
          _authState = AuthState.authenticated;
        } else {
          // Session expired
          await AuthService.clearSession();
          _currentSession = null;
          _authState = AuthState.unauthenticated;
        }
      } else {
        _currentSession = null;
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString();
      print('Error initializing auth: $e');
    }

    notifyListeners();
  }

  // Login with username and password (tries online first, then offline)
  Future<bool> login(String username, String password) async {
    _authState = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      // Try online authentication first
      UserSession? session = await AuthService.authenticateOnline(
        username,
        password,
      );

      // If online fails, try offline authentication
      if (session == null) {
        session = await AuthService.authenticateOffline(username, password);
      }

      if (session != null) {
        _currentSession = session;
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _authState = AuthState.unauthenticated;
        _errorMessage = 'Authentication failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Login with online credentials only
  Future<bool> loginOnline(String username, String password) async {
    _authState = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final session = await AuthService.authenticateOnline(username, password);

      if (session != null) {
        _currentSession = session;
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _authState = AuthState.unauthenticated;
        _errorMessage = 'Authentication failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Login with offline credentials only
  Future<bool> loginOffline(String username, String password) async {
    _authState = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final session = await AuthService.authenticateOffline(username, password);

      if (session != null) {
        _currentSession = session;
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _authState = AuthState.unauthenticated;
        _errorMessage = 'No offline credentials found';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      await AuthService.logout();
      _currentSession = null;
      _authState = AuthState.unauthenticated;
      _errorMessage = '';
    } catch (e) {
      _authState = AuthState.error;
      _errorMessage = 'Error during logout: ${e.toString()}';
      print('Logout error: $e');
    }

    notifyListeners();
  }

  // Clear error state
  void clearError() {
    _errorMessage = '';
    if (_authState == AuthState.error) {
      _authState =
          _currentSession != null
              ? AuthState.authenticated
              : AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // Check if session is still valid
  bool isSessionValid() {
    if (_currentSession == null) return false;
    return AuthService.isSessionValid(_currentSession!);
  }

  // Refresh current session
  Future<void> refreshSession() async {
    if (_currentSession == null) return;

    if (!isSessionValid()) {
      // Session expired, logout
      await logout();
      return;
    }

    // Try to refresh session with AuthService
    final refreshedSession = await AuthService.refreshSession();
    if (refreshedSession != null) {
      _currentSession = refreshedSession;
      _authState = AuthState.authenticated;
    } else {
      // Session could not be refreshed, logout
      await logout();
    }

    notifyListeners();
  }

  // Update session data (used when route info is loaded)
  void updateSession(UserSession session) {
    _currentSession = session;
    _authState = AuthState.authenticated;
    notifyListeners();
  }

  // Update session with route information
  Future<void> updateSessionWithRoute({
    required String routeId,
    required String? routeName,
    required List<String>? routeAreas,
  }) async {
    if (_currentSession != null) {
      final updatedSession = _currentSession!.copyWithRoute(
        routeId: routeId,
        routeName: routeName,
        routeAreas: routeAreas,
      );

      _currentSession = updatedSession;

      // Update stored session
      await AuthService.updateSessionWithRoute(
        routeId: routeId,
        routeName: routeName,
        routeAreas: routeAreas,
      );

      notifyListeners();
    }
  }

  // Get Firebase path for current user
  String get firebasePath {
    if (_currentSession == null) return '';
    return 'owners/${_currentSession!.ownerId}/businesses/${_currentSession!.businessId}';
  }

  // Check if user has specific role
  bool hasRole(String role) {
    return _currentSession?.role == role;
  }

  // Get user initials for avatar
  String get userInitials {
    if (_currentSession == null) return 'U';
    return _currentSession!.initials;
  }

  // Get greeting message
  String get greetingMessage {
    if (_currentSession == null) return 'Hello!';
    return AuthService.getGreetingMessage(_currentSession);
  }

  // Get user display name
  String get userDisplayName {
    if (_currentSession == null) return 'User';
    return _currentSession!.displayName;
  }

  // Get route information
  String get assignedRoute {
    if (_currentSession == null) return 'No Route';
    return _currentSession!.routeDisplayShort;
  }

  String get routeAreas {
    if (_currentSession == null) return '';
    return _currentSession!.routeAreasText;
  }

  bool get hasRouteAssigned {
    return _currentSession?.hasRouteAssigned ?? false;
  }

  // Reset provider state
  void reset() {
    _currentSession = null;
    _authState = AuthState.initial;
    _errorMessage = '';
    notifyListeners();
  }

  // Force state update (for debugging)
  void forceNotify() {
    notifyListeners();
  }
}

// Helper extension for AuthState
extension AuthStateExtension on AuthState {
  bool get isInitial => this == AuthState.initial;
  bool get isLoading => this == AuthState.loading;
  bool get isAuthenticated => this == AuthState.authenticated;
  bool get isUnauthenticated => this == AuthState.unauthenticated;
  bool get isError => this == AuthState.error;
}
