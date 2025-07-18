// lib/screens/billing/outlet_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/loading_provider.dart'; // Added loading provider
import '../../models/outlet.dart';

class OutletSelectionScreen extends StatefulWidget {
  const OutletSelectionScreen({super.key});

  @override
  State<OutletSelectionScreen> createState() => _OutletSelectionScreenState();
}

class _OutletSelectionScreenState extends State<OutletSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String? _todaysRouteId; // Today's route ID from loading

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AuthProvider>();
    final billingProvider = context.read<BillingProvider>();
    final outletProvider = context.read<OutletProvider>();
    final loadingProvider =
        context.read<LoadingProvider>(); // Added loading provider

    if (authProvider.currentSession != null) {
      // Initialize billing
      await billingProvider.initializeBilling(authProvider.currentSession!);

      // Load today's loading to get route information
      await loadingProvider.loadTodaysLoading(authProvider.currentSession!);

      // Load outlets
      await outletProvider.loadOutlets(authProvider.currentSession!);

      // Get today's route ID from loading
      setState(() {
        _todaysRouteId = loadingProvider.currentRouteId;
      });

      print('Today\'s route ID: $_todaysRouteId');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        title: Text(
          'Select Customer',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            140,
          ), // Increased height for route info
          child: Column(
            children: [
              // Search Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.grey.shade400,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade400),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),

              // Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue.shade600,
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorColor: Colors.blue.shade600,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.route, size: 16),
                          const SizedBox(width: 8),
                          const Text('Today\'s Route'), // Updated text
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 16),
                          const SizedBox(width: 8),
                          const Text('All Customers'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Today's Route Customers Tab
          _buildCustomersList(routeFiltered: true),
          // All Customers Tab
          _buildCustomersList(routeFiltered: false),
        ],
      ),
    );
  }

  Widget _buildCustomersList({required bool routeFiltered}) {
    return Consumer2<OutletProvider, LoadingProvider>(
      builder: (context, outletProvider, loadingProvider, child) {
        if (outletProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        List<Outlet> outlets = outletProvider.allOutlets;

        // Apply route filter if needed - use today's route ID
        if (routeFiltered &&
            _todaysRouteId != null &&
            _todaysRouteId!.isNotEmpty) {
          outlets =
              outlets
                  .where((outlet) => outlet.routeId == _todaysRouteId)
                  .toList();

          print(
            'Filtered outlets for today\'s route ($_todaysRouteId): ${outlets.length}',
          );
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          outlets =
              outlets
                  .where(
                    (outlet) =>
                        outlet.outletName.toLowerCase().contains(
                          _searchQuery,
                        ) ||
                        outlet.address.toLowerCase().contains(_searchQuery) ||
                        outlet.ownerName.toLowerCase().contains(_searchQuery) ||
                        outlet.phoneNumber.toLowerCase().contains(_searchQuery),
                  )
                  .toList();
        }

        if (outlets.isEmpty) {
          return _buildEmptyState(routeFiltered, loadingProvider);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: outlets.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            return _buildOutletCard(outlet);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool routeFiltered, LoadingProvider loadingProvider) {
    String title;
    String subtitle;

    if (routeFiltered) {
      if (_searchQuery.isNotEmpty) {
        title = 'No customers found';
        subtitle = 'Try adjusting your search terms';
      } else if (_todaysRouteId == null || _todaysRouteId!.isEmpty) {
        title = 'No route assigned';
        subtitle = 'No route assigned for today. Check with your supervisor.';
      } else {
        title = 'No customers in today\'s route';
        subtitle =
            'No customers found for route: ${loadingProvider.routeDisplayName}';
      }
    } else {
      if (_searchQuery.isNotEmpty) {
        title = 'No customers found';
        subtitle = 'Try adjusting your search terms';
      } else {
        title = 'No customers available';
        subtitle = 'Add customers to start billing';
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              routeFiltered ? Icons.route_outlined : Icons.store_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          // Show retry button if no route is assigned
          if (routeFiltered &&
              (_todaysRouteId == null || _todaysRouteId!.isEmpty)) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _retryLoadingRoute(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Loading Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _retryLoadingRoute() async {
    final authProvider = context.read<AuthProvider>();
    final loadingProvider = context.read<LoadingProvider>();

    if (authProvider.currentSession != null) {
      await loadingProvider.loadTodaysLoading(authProvider.currentSession!);
      setState(() {
        _todaysRouteId = loadingProvider.currentRouteId;
      });
    }
  }

  Widget _buildOutletCard(Outlet outlet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectOutlet(outlet),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Customer Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getOutletTypeColor(
                      outlet.outletType,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getOutletTypeIcon(outlet.outletType),
                    color: _getOutletTypeColor(outlet.outletType),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Customer Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outlet.outletName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        outlet.ownerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        outlet.address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (outlet.phoneNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              outlet.phoneNumber,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (outlet.routeId.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                outlet.routeId == _todaysRouteId
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (outlet.routeId == _todaysRouteId) ...[
                                Icon(
                                  Icons.today,
                                  size: 10,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                outlet.routeName ?? 'Route ${outlet.routeId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      outlet.routeId == _todaysRouteId
                                          ? Colors.green.shade600
                                          : Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Selection Indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectOutlet(Outlet outlet) {
    final billingProvider = context.read<BillingProvider>();
    billingProvider.selectOutlet(outlet);

    Navigator.pushNamed(context, '/billing/items');
  }

  IconData _getOutletTypeIcon(String outletType) {
    switch (outletType.toLowerCase()) {
      case 'retail':
        return Icons.shopping_bag_outlined;
      case 'wholesale':
        return Icons.warehouse_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'supermarket':
        return Icons.local_grocery_store_outlined;
      case 'pharmacy':
        return Icons.local_pharmacy_outlined;
      case 'hardware':
        return Icons.hardware_outlined;
      case 'customer':
        return Icons.person_outline;
      default:
        return Icons.store_outlined;
    }
  }

  Color _getOutletTypeColor(String outletType) {
    switch (outletType.toLowerCase()) {
      case 'retail':
        return Colors.blue;
      case 'wholesale':
        return Colors.orange;
      case 'hotel':
        return Colors.purple;
      case 'restaurant':
        return Colors.red;
      case 'supermarket':
        return Colors.green;
      case 'pharmacy':
        return Colors.teal;
      case 'hardware':
        return Colors.brown;
      case 'customer':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}
