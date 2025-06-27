import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// User session model
class UserSession {
  final String userId;
  final String businessId;
  final String employeeId;
  final String username;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? imageUrl;
  final DateTime loginTime;

  UserSession({
    required this.userId,
    required this.businessId,
    required this.employeeId,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.imageUrl,
    required this.loginTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'businessId': businessId,
      'employeeId': employeeId,
      'username': username,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'imageUrl': imageUrl,
      'loginTime': loginTime.millisecondsSinceEpoch,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['userId'],
      businessId: json['businessId'],
      employeeId: json['employeeId'],
      username: json['username'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      imageUrl: json['imageUrl'],
      loginTime: DateTime.fromMillisecondsSinceEpoch(json['loginTime']),
    );
  }
}

// Authentication service
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

  // Online authentication via Firestore
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

      // Verify password (assuming plain text for now - in production, use hashed passwords)
      if (userData['password'] != password) {
        throw Exception('Invalid password');
      }

      // Create user session
      final session = UserSession(
        userId: userDoc.id,
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
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOnline = true;
  String _errorMessage = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupAnimations();
    _checkExistingSession();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;
    });

    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline =
            result.isNotEmpty && result.first != ConnectivityResult.none;
      });
    });
  }

  Future<void> _checkExistingSession() async {
    final session = await AuthService.getCurrentUserSession();
    if (session != null && mounted) {
      // Navigate to home if valid session exists
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      UserSession? session;

      if (_isOnline) {
        // Try online authentication first
        try {
          session = await AuthService.authenticateOnline(username, password);
        } catch (e) {
          // If online fails, try offline as backup
          session = await AuthService.verifyOfflineCredentials(
            username,
            password,
          );
          if (session == null) {
            throw e; // Re-throw original online error
          } else {
            _showSnackBar('Logged in using offline credentials', Colors.orange);
          }
        }
      } else {
        // Use offline authentication
        session = await AuthService.verifyOfflineCredentials(
          username,
          password,
        );
        if (session == null) {
          throw Exception(
            'No offline credentials found. Please connect to internet and login first.',
          );
        }
      }

      if (session != null && mounted) {
        // Navigate to home page
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    _showSnackBar(message, Colors.red);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // App Logo/Title
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'BillMaster',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Smart billing made simple',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 48),

                // Connection Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color:
                        _isOnline
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _isOnline
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off,
                        color:
                            _isOnline
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isOnline
                              ? 'Online - Full features available'
                              : 'Offline - Limited features available',
                          style: TextStyle(
                            color:
                                _isOnline
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter your username',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Colors.grey.shade600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue.shade600,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Username is required';
                          }
                          if (value!.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.grey.shade600,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey.shade600,
                            ),
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.blue.shade600,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Password is required';
                          }
                          if (value!.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Help Text
                if (!_isOnline)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Offline Mode',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can login with previously used credentials. Connect to internet for full access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 48),

                // Footer
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
