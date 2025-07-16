// lib/main.dart (Updated with fixed route configuration)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lumorabiz_billing/providers/billing_provider.dart';
import 'package:lumorabiz_billing/providers/loading_provider.dart';
import 'package:lumorabiz_billing/providers/outlet_provider.dart';
import 'package:lumorabiz_billing/screens/billing/bill_success_screen.dart';
import 'package:lumorabiz_billing/screens/billing/item_selection_screen.dart';
import 'package:lumorabiz_billing/screens/billing/outlet_selection_screen.dart';
import 'package:lumorabiz_billing/screens/billing/view_bills_screen.dart';
import 'package:lumorabiz_billing/screens/home/home_screen.dart';
import 'package:lumorabiz_billing/screens/outlets/outlet_list_screen.dart';
import 'package:lumorabiz_billing/screens/printing/printer_selection_screen.dart';
import 'package:lumorabiz_billing/screens/reports/daily_summary_screen.dart';
import 'package:lumorabiz_billing/splashScreen.dart';
import 'package:provider/provider.dart';

// Providers
import 'providers/auth_provider.dart';

// Models
import 'models/user_session.dart';

// Services
import 'services/auth/auth_service.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/loading/loading_list_screen.dart';

// Legacy imports (update these to new structure when ready)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(const LumoraBizApp());
}

class LumoraBizApp extends StatelessWidget {
  const LumoraBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth Provider
        ChangeNotifierProvider(create: (context) => AuthProvider()),

        // Stock Provider
        ChangeNotifierProvider(create: (context) => LoadingProvider()),

        // Add more providers here as needed
        ChangeNotifierProvider(create: (context) => OutletProvider()),
        ChangeNotifierProvider(create: (context) => BillingProvider()),
        // ChangeNotifierProvider(create: (context) => SyncProvider()),
      ],
      child: MaterialApp(
        title: 'LumoraBiz Billing',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',

          // Enhanced theme for better UI
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey.shade800,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            shadowColor: Colors.grey.shade200,
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),

        home: const AuthWrapper(),

        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/stock': (context) => const LoadingListScreen(),
          '/splash': (context) => const SplashScreen(),

          // Legacy routes (update these later)
          '/create-bill': (context) => const PrinterSelectionScreen(),
          '/loading': (context) => const LoadingListScreen(),
          '/outlets': (context) => const OutletListScreen(),
          '/billing/outlet-selection':
              (context) => const OutletSelectionScreen(),
          '/billing/items': (context) => const ItemSelectionScreen(),
          '/billing/success': (context) => const BillSuccessScreen(),
          '/reports/daily-summary': (context) => const DailySummaryScreen(),
          '/billing/view-bills': (context) => const ViewBillsScreen(),
        },
      ),
    );
  }
}

// Auth wrapper to determine initial route based on session state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initializeAuth();
    });
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

// Alternative AuthWrapper using FutureBuilder (if you prefer)
class AuthWrapperAlternative extends StatelessWidget {
  const AuthWrapperAlternative({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserSession?>(
      future: AuthService.getCurrentUserSession(),
      builder: (context, snapshot) {
        // Show splash screen while checking session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Check if session exists and is valid
        if (snapshot.hasData && snapshot.data != null) {
          final session = snapshot.data!;

          if (AuthService.isSessionValid(session)) {
            // Update provider with current session
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
