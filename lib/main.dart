// lib/main.dart (Fixed AuthWrapper section)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lumorabiz_billing/services/local/database_service.dart';
import 'package:provider/provider.dart';

// Theme
import 'theme/app_theme.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/loading_provider.dart';
import 'providers/outlet_provider.dart';

// Models
import 'models/user_session.dart';

// Services
import 'services/auth/auth_service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/loading/loading_list_screen.dart';
import 'screens/billing/bill_success_screen.dart';
import 'screens/billing/item_selection_screen.dart';
import 'screens/billing/outlet_selection_screen.dart';
import 'screens/billing/view_bills_screen.dart';
import 'screens/outlets/outlet_list_screen.dart';
import 'screens/printing/printer_selection_screen.dart';
import 'screens/reports/daily_summary_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
    await _initializeDatabase();
    // Set system UI overlay style to match theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppTheme.surfaceColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    print('Initialization error: $e');
  }

  runApp(const LumoraBizApp());
}

class LumoraBizApp extends StatelessWidget {
  const LumoraBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth Provider - Should be first
        ChangeNotifierProvider(create: (context) => AuthProvider()),

        // Other providers
        ChangeNotifierProvider(create: (context) => LoadingProvider()),
        ChangeNotifierProvider(create: (context) => OutletProvider()),
        ChangeNotifierProvider(create: (context) => BillingProvider()),
      ],
      child: MaterialApp(
        title: 'LumoraBiz Billing',
        debugShowCheckedModeBanner: false,

        // Apply the custom theme
        theme: AppTheme.lightTheme,

        // Home widget - uses AuthWrapper for route determination
        home: const AuthWrapper(),

        // Route configuration
        routes: _buildRoutes(),

        // Global theme consistency
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          );
        },

        // Error handling
        onGenerateRoute: (settings) {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        },
      ),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/login': (context) => const LoginScreen(),
      '/splash': (context) => const SplashScreen(),
      '/home': (context) => const HomeScreen(),
      '/stock': (context) => const LoadingListScreen(),
      '/outlets': (context) => const OutletListScreen(),
      '/billing/outlet-selection': (context) => const OutletSelectionScreen(),
      '/billing/items': (context) => const ItemSelectionScreen(),
      '/billing/success': (context) => const BillSuccessScreen(),
      '/billing/view-bills': (context) => const ViewBillsScreen(),
      '/reports/daily-summary': (context) => const DailySummaryScreen(),
      '/printing/printer-selection':
          (context) => const PrinterSelectionScreen(),
      '/create-bill': (context) => const PrinterSelectionScreen(),
      '/loading': (context) => const LoadingListScreen(),
    };
  }
}

Future<void> _initializeDatabase() async {
  try {
    print('🔧 Initializing database...');

    // Create database service instance and ensure bills table exists
    final dbService = DatabaseService();
    await dbService.ensureBillsTableExists();

    print('✅ Database initialization completed');
  } catch (e) {
    print('❌ Database initialization failed: $e');
    // Don't prevent app startup, just log the error
  }
}

// FIXED: AuthWrapper that doesn't cause build errors
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure initialization happens after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    try {
      // Only initialize if not already initialized
      final authProvider = context.read<AuthProvider>();
      if (authProvider.authState.isInitial) {
        await authProvider.initializeAuth();
      }
    } catch (e) {
      print('Auth initialization error: $e');
      // Handle initialization error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show splash screen while initializing or loading
        if (authProvider.authState.isInitial ||
            authProvider.authState.isLoading) {
          return const SplashScreen();
        }

        // Show home screen if authenticated
        if (authProvider.authState.isAuthenticated) {
          return const HomeScreen();
        }

        // Show login screen if unauthenticated or error
        return const LoginScreen();
      },
    );
  }
}

// ALTERNATIVE: FutureBuilder approach (safer for initialization)
class AuthWrapperFuture extends StatelessWidget {
  const AuthWrapperFuture({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserSession?>(
      future: AuthService.getCurrentUserSession(),
      builder: (context, snapshot) {
        // Show splash screen while checking session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Handle errors
        if (snapshot.hasError) {
          print('Auth error: ${snapshot.error}');
          return const LoginScreen();
        }

        // Check if session exists and is valid
        if (snapshot.hasData && snapshot.data != null) {
          final session = snapshot.data!;

          if (AuthService.isSessionValid(session)) {
            // Update provider with current session (safely)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AuthProvider>().updateSession(session);
            });
            return const HomeScreen();
          } else {
            // Session expired, clear it
            AuthService.clearSession();
          }
        }

        // No valid session, show login
        return const LoginScreen();
      },
    );
  }
}

// BEST SOLUTION: Use a proper initialization widget
class AuthInitializer extends StatefulWidget {
  const AuthInitializer({super.key});

  @override
  State<AuthInitializer> createState() => _AuthInitializerState();
}

class _AuthInitializerState extends State<AuthInitializer> {
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize auth provider
      await context.read<AuthProvider>().initializeAuth();

      // Initialize other providers if needed
      // await context.read<LoadingProvider>().initialize();
      // await context.read<OutletProvider>().initialize();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('App initialization error: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Initialization Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Please restart the app',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                  });
                  _initializeApp();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const SplashScreen();
    }

    return const AuthWrapper();
  }
}
