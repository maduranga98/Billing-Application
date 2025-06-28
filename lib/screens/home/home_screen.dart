// lib/screens/home/home_screen.dart (Complete Updated Version)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';
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
                  _buildTodaysRouteCard(), // Prominent route display
                  const SizedBox(height: 24),
                  _buildDateTimeCard(),
                  const SizedBox(height: 24),
                  _buildLoadingOverview(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildTodaysSummary(),
                  const SizedBox(height: 24),
                  _buildItemsNeedingAttention(),
                  const SizedBox(height: 100), // Bottom padding
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

  // MAIN FEATURE: Prominent Today's Route Card
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
                          : Icons.route_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Route',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loadingProvider.hasRouteContext
                              ? loadingProvider.routeDisplayName
                              : 'No Route Assigned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (loadingProvider.hasRouteContext) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coverage Areas:',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loadingProvider.routeAreasText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (loadingProvider.hasLoading) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildRouteStatItem(
                        'Items',
                        loadingProvider.availableItemCount.toString(),
                        Icons.inventory_2,
                      ),
                      const SizedBox(width: 24),
                      _buildRouteStatItem(
                        'Value',
                        'Rs ${_formatCurrency(loadingProvider.totalValue)}',
                        Icons.attach_money,
                      ),
                      const SizedBox(width: 24),
                      _buildRouteStatItem(
                        'Progress',
                        '${loadingProvider.salesProgress.toStringAsFixed(0)}%',
                        Icons.trending_up,
                      ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white.withOpacity(0.9),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Contact your supervisor to get today\'s loading assignment',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDateTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
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
              const Icon(Icons.access_time, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Time',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('EEEE, MMMM dd').format(_currentDateTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm:ss').format(_currentDateTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverview() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Loading',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (loadingProvider.hasLoading)
                      TextButton.icon(
                        onPressed:
                            () => Navigator.pushNamed(context, '/loading'),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View Details'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (loadingProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CompactLoadingIndicator(),
                    ),
                  )
                else if (loadingProvider.hasError)
                  CompactErrorWidget(
                    message: loadingProvider.errorMessage,
                    onRetry:
                        () => loadingProvider.clearErrorAndRetry(
                          context.read<AuthProvider>().currentSession!,
                        ),
                  )
                else if (loadingProvider.hasNoLoading)
                  _buildNoLoadingState()
                else if (loadingProvider.hasLoading)
                  _buildLoadingStats(loadingProvider)
                else
                  _buildNoLoadingState(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingStats(LoadingProvider loadingProvider) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildLoadingStatItem(
                  'Total Items',
                  loadingProvider.totalItems.toString(),
                  Icons.inventory_2_outlined,
                  Colors.blue,
                ),
              ),
              VerticalDivider(color: Colors.grey.shade300),
              Expanded(
                child: _buildLoadingStatItem(
                  'Available',
                  loadingProvider.availableItemCount.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              VerticalDivider(color: Colors.grey.shade300),
              Expanded(
                child: _buildLoadingStatItem(
                  'Value',
                  'Rs ${_formatCurrency(loadingProvider.totalValue)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ),

        // Sales Progress
        if (loadingProvider.salesProgress > 0) ...[
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sales Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${loadingProvider.salesProgress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: loadingProvider.salesProgress / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNoLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No Loading Assigned',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your supervisor to get today\'s loading assignment.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
                  'Reports',
                  'View analytics',
                  Icons.analytics_outlined,
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/reports'),
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

  Widget _buildTodaysSummary() {
    // Mock data - replace with real data from providers
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  DateFormat('MMM dd').format(DateTime.now()),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildLoadingStatItem(
                      'Bills Created',
                      '0', // TODO: Replace with real data
                      Icons.receipt,
                      Colors.blue,
                    ),
                  ),
                  VerticalDivider(color: Colors.grey.shade300),
                  Expanded(
                    child: _buildLoadingStatItem(
                      'Revenue',
                      'Rs 0', // TODO: Replace with real data
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  VerticalDivider(color: Colors.grey.shade300),
                  Expanded(
                    child: _buildLoadingStatItem(
                      'Outlets',
                      '0', // TODO: Replace with real data
                      Icons.store,
                      Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsNeedingAttention() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        if (!loadingProvider.hasItemsNeedingAttention ||
            loadingProvider.isLoading) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Items Needing Attention',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${loadingProvider.lowStockCount} items are running low and ${loadingProvider.outOfStockCount} items are out of stock.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 14),
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
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, child) {
        return FloatingActionButton.extended(
          onPressed:
              loadingProvider.hasRouteContext
                  ? () => Navigator.pushNamed(context, '/create-bill')
                  : null,
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
    // TODO: Navigate to profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile screen coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToSettings() {
    // TODO: Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings screen coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
