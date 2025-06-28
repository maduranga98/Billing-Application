// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

// Providers
import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';
import '../../providers/outlet_provider.dart';

// Screens
import '../outlets/outlet_list_screen.dart';
import '../outlets/add_outlet_screen.dart';
import '../loading/loading_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTimer();
    _checkConnectivity();
    _loadData();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });
  }

  void _setupTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {}); // Refresh time display
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = !connectivityResult.contains(ConnectivityResult.none);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      setState(() {
        _isConnected = !results.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final loadingProvider = Provider.of<LoadingProvider>(
      context,
      listen: false,
    );
    final outletProvider = Provider.of<OutletProvider>(context, listen: false);

    if (authProvider.currentSession != null) {
      await Future.wait([
        loadingProvider.loadTodaysLoading(authProvider.currentSession!),
        outletProvider.loadOutlets(authProvider.currentSession!),
      ]);
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  void _navigateToProfile() {
    // TODO: Implement profile navigation
  }

  void _navigateToSettings() {
    // TODO: Implement settings navigation
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
  }

  Future<void> _syncOfflineData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final outletProvider = Provider.of<OutletProvider>(context, listen: false);

    if (authProvider.currentSession != null) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Dialog(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text('Syncing data...'),
                  ],
                ),
              ),
            ),
      );

      try {
        final result = await outletProvider.syncOfflineOutlets(
          authProvider.currentSession!,
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      result.success ? Icons.check_circle : Icons.warning,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(result.message)),
                  ],
                ),
                backgroundColor: result.success ? Colors.green : Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Sync failed: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildConnectionStatus(),
                  const SizedBox(height: 24),
                  _buildTodaysRouteCard(),
                  const SizedBox(height: 24),
                  _buildDateTimeCard(),
                  const SizedBox(height: 24),
                  _buildQuickStats(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildLoadingOverview(),
                  const SizedBox(height: 24),
                  _buildOutletOverview(),
                  const SizedBox(height: 24),
                  _buildTodaysSummary(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProvider.greetingMessage,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to serve your route today?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.blue.shade600,
                radius: 22,
                child: Text(
                  authProvider.userInitials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    _navigateToProfile();
                    break;
                  case 'settings':
                    _navigateToSettings();
                    break;
                  case 'logout':
                    _signOut();
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Text('Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionStatus() {
    if (_isConnected) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You\'re offline. Some features may be limited.',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysRouteCard() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  loadingProvider.hasRouteContext
                      ? [Colors.green.shade600, Colors.green.shade700]
                      : [Colors.grey.shade600, Colors.grey.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    loadingProvider.hasRouteContext
                        ? Colors.green.shade200.withOpacity(0.5)
                        : Colors.grey.shade300.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      loadingProvider.hasRouteContext
                          ? Icons.route
                          : Icons.location_off,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Today\'s Route',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                loadingProvider.hasRouteContext
                    ? loadingProvider.routeDisplayName
                    : 'No Route Assigned',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (loadingProvider.hasRouteContext) ...[
                const SizedBox(height: 8),
                Text(
                  loadingProvider.routeAreasText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateTimeCard() {
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.today, color: Colors.blue.shade600, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${now.day}/${now.month}/${now.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getFormattedTime(now),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Consumer2<LoadingProvider, OutletProvider>(
      builder: (context, loadingProvider, outletProvider, child) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Loading Items',
                '${loadingProvider.availableItemCount}',
                Icons.inventory_2,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Outlets',
                '${outletProvider.outlets.length}',
                Icons.store,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Offline Data',
                '${outletProvider.offlineOutletCount}',
                Icons.cloud_off,
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          // Primary actions
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Create Bill',
                  'Start new billing',
                  Icons.receipt_long,
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/create-bill'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Add Outlet',
                  'Register new outlet',
                  Icons.store_outlined,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddOutletScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'View Loading',
                  'Check inventory',
                  Icons.inventory_2_outlined,
                  Colors.orange,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoadingListScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Manage Outlets',
                  'View all outlets',
                  Icons.store,
                  Colors.purple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OutletListScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverview() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        if (loadingProvider.loadingState == LoadingState.loading) {
          return _buildLoadingCard(isLoading: true);
        }

        if (loadingProvider.loadingState == LoadingState.noLoading) {
          return _buildLoadingCard(isEmpty: true);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Today\'s Loading',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoadingListScreen(),
                          ),
                        ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildLoadingStat(
                      'Total Items',
                      '${loadingProvider.availableItemCount}',
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildLoadingStat(
                      'Low Stock',
                      '${loadingProvider.lowStockCount}',
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildLoadingStat(
                      'Out of Stock',
                      '${loadingProvider.outOfStockCount}',
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard({bool isLoading = false, bool isEmpty = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isLoading ? Icons.hourglass_empty : Icons.inventory_2_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isLoading ? 'Loading data...' : 'No loading data available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOutletOverview() {
    return Consumer<OutletProvider>(
      builder: (context, outletProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.store_outlined,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Outlet Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OutletListScreen(),
                          ),
                        ),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildOutletStat(
                      'Total Outlets',
                      '${outletProvider.outlets.length}',
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildOutletStat(
                      'Offline Data',
                      '${outletProvider.offlineOutletCount}',
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildOutletStat(
                      'Connection',
                      _isConnected ? 'Online' : 'Offline',
                      _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              if (outletProvider.offlineOutletCount > 0 && _isConnected) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _syncOfflineData(),
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(
                      'Sync ${outletProvider.offlineOutletCount} outlets',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutletStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTodaysSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.purple.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Bills Created', '0', Colors.blue),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Total Revenue',
                  'Rs. 0',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Cash Sales', 'Rs. 0', Colors.orange),
              ),
              Expanded(
                child: _buildSummaryItem('Credit Sales', 'Rs. 0', Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddOutletScreen()),
          ),
      backgroundColor: Colors.green.shade600,
      foregroundColor: Colors.white,
      elevation: 8,
      child: const Icon(Icons.add, size: 28),
    );
  }

  // Helper Methods
  String _getFormattedTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
