// lib/screens/home/home_screen.dart (Corrected UI and Routes)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Timer _timer;
  DateTime _currentDateTime = DateTime.now();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _checkConnectivity();
    _startTimer();
    _loadTodaysData();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      }
    });
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (mounted) {
        setState(() {
          _isConnected =
              result.isNotEmpty && result.first != ConnectivityResult.none;
        });
      }
    });
  }

  void _loadTodaysData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final loadingProvider = context.read<LoadingProvider>();

      if (authProvider.currentSession != null) {
        loadingProvider.loadTodaysLoading(authProvider.currentSession!);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _showProfile() {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${authProvider.currentSession?.name ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Email: ${authProvider.currentSession?.email ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Phone: ${authProvider.currentSession?.phone ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Role: ${authProvider.currentSession?.role ?? 'N/A'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final authProvider = context.read<AuthProvider>();
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _getData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting data from database...'),
        backgroundColor: Colors.blue,
      ),
    );

    final loadingProvider = context.read<LoadingProvider>();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentSession != null) {
      loadingProvider.refreshLoading(authProvider.currentSession!);
    }
  }

  void _uploadData() {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Cannot upload data.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uploading data to server...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade800,
        foregroundColor: Colors.white,
        title: const Text(
          'LumoraBiz',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          // Profile Button
          IconButton(
            onPressed: _showProfile,
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
          // Logout Button
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final authProvider = context.read<AuthProvider>();
          final loadingProvider = context.read<LoadingProvider>();

          if (authProvider.currentSession != null) {
            await loadingProvider.refreshLoading(authProvider.currentSession!);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and Route Info (Simple Text)
                _buildInfoSection(),
                const SizedBox(height: 24),

                // Today's Prices Section
                _buildTodaysPricesSection(),
                const SizedBox(height: 24),

                // Data Management Buttons
                _buildDataManagementSection(),
                const SizedBox(height: 24),

                // Main Action Buttons
                _buildMainActionsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Info
        Text(
          'Date: ${DateFormat('EEEE, MMMM d, y').format(_currentDateTime)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),

        // Today's Route
        Consumer<LoadingProvider>(
          builder: (context, loadingProvider, child) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Today Route: ${loadingProvider.hasRouteContext ? loadingProvider.routeDisplayName : "No route assigned"}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                // Connection Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        _isConnected
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    border: Border.all(
                      color:
                          _isConnected
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color:
                            _isConnected
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected ? 'Online' : 'Offline',
                        style: TextStyle(
                          color:
                              _isConnected
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodaysPricesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Prices",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        Consumer<LoadingProvider>(
          builder: (context, loadingProvider, child) {
            final loading = loadingProvider.currentLoading;
            final paddyPrices = loading?.todayPaddyPrices;

            if (loadingProvider.isLoading) {
              return Container(
                height: 100,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            }

            if (paddyPrices == null || paddyPrices.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'No paddy prices set for today',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children:
                  paddyPrices.entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Rs.${entry.value}/kg',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Data Management",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _getData,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Get Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isConnected ? _uploadData : null,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Upload Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isConnected
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Main Actions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildActionButton(
              title: 'Create Bill',
              subtitle: 'New billing',
              icon: Icons.receipt_long,
              color: Colors.blue,
              onTap:
                  () =>
                      Navigator.pushNamed(context, '/billing/outlet-selection'),
            ),
            _buildActionButton(
              title: 'Add Customer',
              subtitle: 'New outlet',
              icon: Icons.store_outlined,
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, '/add-outlet'),
            ),
            _buildActionButton(
              title: 'Stock',
              subtitle: 'Current stock',
              icon: Icons.inventory,
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, '/loading'),
            ),
            _buildActionButton(
              title: 'Day Summary',
              subtitle: 'Bill summary',
              icon: Icons.assessment,
              color: Colors.purple,
              onTap:
                  () => Navigator.pushNamed(context, '/reports/daily-summary'),
            ),
            _buildActionButton(
              title: 'View Bills',
              subtitle: 'Created bills',
              icon: Icons.list_alt,
              color: Colors.indigo,
              onTap: () => Navigator.pushNamed(context, '/billing/view-bills'),
            ),
            _buildActionButton(
              title: 'Outlets',
              subtitle: 'Manage outlets',
              icon: Icons.business,
              color: Colors.teal,
              onTap: () => Navigator.pushNamed(context, '/outlets'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isEnabled ? color : Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isEnabled ? Colors.grey.shade800 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
