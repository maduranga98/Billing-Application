import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lumorabiz_billing/addOutlet.dart';
import 'package:lumorabiz_billing/auth/login.dart';
import 'package:lumorabiz_billing/home/home.dart';
import 'package:lumorabiz_billing/pages/PrintBillPage.dart';
import 'package:lumorabiz_billing/pages/printer_select_screener.dart';
import 'package:lumorabiz_billing/splashScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BillMasterApp());
}

class BillMasterApp extends StatelessWidget {
  const BillMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillMaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily:
            'Inter', // Add Inter font to pubspec.yaml for better typography
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/splash': (context) => const SplashScreen(),
        '/add-outlet': (context) => const AddOutlet(),
        '/create-bill': (context) => PrinterSelectScreener(),
      },
    );
  }
}

// Auth wrapper to determine initial route based on authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash screen while checking authentication
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // If user is logged in, show home page
        if (snapshot.hasData) {
          return const HomePage();
        }

        // If no user, show login page
        return const LoginPage();
      },
    );
  }
}
