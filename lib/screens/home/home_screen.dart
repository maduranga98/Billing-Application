import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';
import '../../providers/billing_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  DateTime _currentDateTime = DateTime.now();
  Timer? _timer;
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startClock();
    _checkConnectivity();
    _loadInitialData();
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
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _slideController.forward();
    _scaleController.forward();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      setState(() {
        _isConnected =
            result.isNotEmpty && result.first != ConnectivityResult.none;
      });
    });
  }

  Future<void> _loadInitialData() async {
    final authProvider = context.read<AuthProvider>();
    final loadingProvider = context.read<LoadingProvider>();

    if (authProvider.currentSession != null) {
      // Load today's loading which will set the route context
      await loadingProvider.loadTodaysLoading(authProvider.currentSession!);
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
                  _buildLoadingOverview(),
                  const SizedBox(height: 24),
                  _buildQuickActions(), // Updated with billing
                  const SizedBox(height: 24),
                  _buildBillingStatus(), // NEW - Billing Status
                  const SizedBox(height: 24),
                  _buildTodaysSummary(),
                  const SizedBox(height: 24),
                  _buildItemsNeedingAttention(),
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
                          Icon(Icons.logout, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.red.shade700),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isConnected ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Online' : 'Offline',
            style: TextStyle(
              color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Today\'s Route',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loadingProvider.hasRouteContext ? 'Active' : 'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                loadingProvider.routeDisplayName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (loadingProvider.currentRouteAreas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Areas: ${loadingProvider.routeAreasText}',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_currentDateTime),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  DateFormat('hh:mm:ss a').format(_currentDateTime),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverview() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        if (!loadingProvider.hasLoading) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No Loading Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Contact your supervisor for today\'s loading',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
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
                    Icons.inventory_2,
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
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Items',
                      '${loadingProvider.totalItems}',
                      Icons.inventory_2_outlined,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Available',
                      '${loadingProvider.availableItemCount}',
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Low Stock',
                      '${loadingProvider.lowStockCount}',
                      Icons.warning_outlined,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Out of Stock',
                      '${loadingProvider.outOfStockCount}',
                      Icons.error_outline,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/loading');
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Review Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

          // Primary actions - Updated
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Create Bill',
                  'Start new billing',
                  Icons.receipt_long,
                  Colors.blue,
                  () => _startBillingProcess(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Add Outlet',
                  'Register new outlet',
                  Icons.store_outlined,
                  Colors.green,
                  () => Navigator.pushNamed(context, '/add-outlet'),
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
                  () => Navigator.pushNamed(context, '/loading'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Print Setup',
                  'Configure printer',
                  Icons.print_outlined,
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/printer-select'),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // NEW - Billing Status Widget
  Widget _buildBillingStatus() {
    return Consumer<BillingProvider>(
      builder: (context, billingProvider, child) {
        if (billingProvider.selectedItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Bill in Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (billingProvider.selectedOutlet != null) ...[
                Text(
                  'Outlet: ${billingProvider.selectedOutlet!.outletName}',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '${billingProvider.selectedItems.length} items • Rs. ${billingProvider.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        billingProvider.clearBill();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bill cleared')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _continueBillingProcess(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Continue'),
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

  Widget _buildTodaysSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.green.shade600, size: 24),
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
                child: _buildSummaryItem('Bills Created', '0', Icons.receipt),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Total Sales',
                  'Rs. 0',
                  Icons.monetization_on,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Outlets Visited', '0', Icons.store),
              ),
              Expanded(
                child: _buildSummaryItem('Items Sold', '0', Icons.shopping_bag),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsNeedingAttention() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        if (!loadingProvider.hasLoading || loadingProvider.lowStockCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
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
                    Icons.warning_amber,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Items Needing Attention',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${loadingProvider.lowStockCount} items are running low on stock',
                style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/loading');
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Review Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer2<LoadingProvider, BillingProvider>(
      builder: (context, loadingProvider, billingProvider, child) {
        // If there's a bill in progress, show continue button
        if (billingProvider.selectedItems.isNotEmpty) {
          return FloatingActionButton.extended(
            onPressed: _continueBillingProcess,
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.shopping_cart),
            label: const Text(
              'Continue Bill',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }

        // Normal create bill button
        return FloatingActionButton.extended(
          onPressed:
              loadingProvider.hasRouteContext ? _startBillingProcess : null,
          backgroundColor:
              loadingProvider.hasRouteContext
                  ? Colors.blue.shade600
                  : Colors.grey.shade400,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text(
            'New Bill',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  // Helper methods
  String _formatCurrency(double amount) {
    return NumberFormat('#,##0').format(amount);
  }

  Future<void> _refreshData() async {
    final authProvider = context.read<AuthProvider>();
    final loadingProvider = context.read<LoadingProvider>();

    if (authProvider.currentSession != null) {
      await loadingProvider.refreshLoading(authProvider.currentSession!);
    }
  }

  void _signOut() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _navigateToProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile screen coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings screen coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // NEW - Billing Process Methods
  void _startBillingProcess() async {
    final authProvider = context.read<AuthProvider>();
    final loadingProvider = context.read<LoadingProvider>();
    final billingProvider = context.read<BillingProvider>();

    // Check if user has a route context and loading
    if (!loadingProvider.hasRouteContext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No route assigned. Contact your supervisor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!loadingProvider.hasLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No loading available for today.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Initialize billing process
    if (authProvider.currentSession != null) {
      try {
        await billingProvider.initializeBilling(authProvider.currentSession!);

        // Navigate to outlet selection
        Navigator.pushNamed(context, '/billing/outlet-selection');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start billing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _continueBillingProcess() {
    final billingProvider = context.read<BillingProvider>();

    if (billingProvider.selectedOutlet == null) {
      // If no outlet selected, go to outlet selection
      Navigator.pushNamed(context, '/billing/outlet-selection');
    } else {
      // If outlet selected, go to item selection
      Navigator.pushNamed(context, '/billing/items');
    }
  }
}
