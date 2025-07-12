// lib/screens/outlets/outlet_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/outlet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';
import 'add_outlet_screen.dart';

class OutletListScreen extends StatefulWidget {
  const OutletListScreen({super.key});

  @override
  State<OutletListScreen> createState() => _OutletListScreenState();
}

class _OutletListScreenState extends State<OutletListScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    // Use post frame callback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOutlets();
    });
  }

  void _setupAnimation() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  Future<void> _loadOutlets() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final outletProvider = Provider.of<OutletProvider>(context, listen: false);

    if (authProvider.currentSession != null) {
      await outletProvider.loadOutlets(authProvider.currentSession!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(opacity: _fadeAnimation, child: _buildBody()),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.deepPurple.shade800,
      foregroundColor: Colors.white,
      title: const Text(
        'Outlets',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        Consumer<OutletProvider>(
          builder: (context, outletProvider, child) {
            if (outletProvider.offlineOutletCount > 0) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: () => _showSyncDialog(),
                  icon: Stack(
                    children: [
                      Icon(Icons.sync, color: Colors.orange[600], size: 24),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${outletProvider.offlineOutletCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<OutletProvider>(
      builder: (context, outletProvider, child) {
        if (outletProvider.isLoading) {
          return _buildLoadingState();
        }

        if (outletProvider.hasError) {
          return _buildErrorState(outletProvider.errorMessage!);
        }

        return RefreshIndicator(
          onRefresh: _loadOutlets,
          child: Column(
            children: [
              _buildSearchAndFilter(outletProvider),
              Expanded(
                child:
                    outletProvider.outlets.isEmpty
                        ? _buildEmptyState()
                        : _buildOutletsList(outletProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilter(OutletProvider outletProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search outlets...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                            outletProvider.searchOutlets('');
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: outletProvider.searchOutlets,
            ),
          ),
          const SizedBox(height: 12),

          // Filter Buttons
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: outletProvider.outletTypes.length,
              itemBuilder: (context, index) {
                final type = outletProvider.outletTypes[index];
                final isSelected = type == outletProvider.selectedOutletType;

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      outletProvider.filterByType(type);
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.deepPurple.shade100,
                    checkmarkColor: Colors.deepPurple.shade800,
                    labelStyle: TextStyle(
                      color:
                          isSelected
                              ? Colors.deepPurple.shade800
                              : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color:
                          isSelected
                              ? Colors.deepPurple.shade800
                              : Colors.grey.shade300,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletsList(OutletProvider outletProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: outletProvider.outlets.length,
      itemBuilder: (context, index) {
        final outlet = outletProvider.outlets[index];
        return _buildOutletCard(outlet);
      },
    );
  }

  Widget _buildOutletCard(Outlet outlet) {
    // Check if outlet is from offline storage (shorter ID or starts with 'offline_')
    final isOffline =
        outlet.id.length <= 15 || outlet.id.startsWith('offline_');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOutletDetails(outlet),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Outlet Image or Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurple.shade100,
                          width: 1,
                        ),
                      ),
                      child:
                          outlet.imageUrl != null &&
                                  outlet.imageUrl!.isNotEmpty &&
                                  outlet.imageUrl != 'offline_image'
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  outlet.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Icon(
                                        Icons.store,
                                        color: Colors.deepPurple.shade400,
                                        size: 28,
                                      ),
                                ),
                              )
                              : Icon(
                                Icons.store,
                                color: Colors.deepPurple.shade400,
                                size: 28,
                              ),
                    ),
                    const SizedBox(width: 16),

                    // Outlet Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  outlet.outletName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOffline)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.wifi_off,
                                        size: 12,
                                        color: Colors.orange[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Offline',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            outlet.outletType,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.deepPurple.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.person, outlet.ownerName),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.phone, outlet.phoneNumber),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.location_on, outlet.address),
                        ],
                      ),
                    ),

                    // Action Button
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editOutlet(outlet);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(outlet);
                            break;
                        }
                      },
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading outlets...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOutlets,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No outlets found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first outlet to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddOutlet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Outlet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddOutlet,
      backgroundColor: Colors.deepPurple.shade800,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Add Outlet'),
    );
  }

  void _navigateToAddOutlet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddOutletScreen()),
    ).then((_) {
      // Refresh outlets when returning from add screen
      _loadOutlets();
    });
  }

  void _showOutletDetails(Outlet outlet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outlet.outletName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          outlet.outletType,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.deepPurple.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailCard(
                          'Owner',
                          outlet.ownerName,
                          Icons.person,
                        ),
                        _buildDetailCard(
                          'Phone',
                          outlet.phoneNumber,
                          Icons.phone,
                        ),
                        _buildDetailCard(
                          'Address',
                          outlet.address,
                          Icons.location_on,
                        ),
                        if (outlet.imageUrl != null &&
                            outlet.imageUrl!.isNotEmpty &&
                            outlet.imageUrl != 'offline_image') ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Outlet Image',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              outlet.imageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple.shade600, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editOutlet(Outlet outlet) {
    // Navigate to edit outlet screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOutletScreen(), // Pass outlet for editing
      ),
    ).then((_) {
      _loadOutlets();
    });
  }

  void _showDeleteConfirmation(Outlet outlet) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Outlet'),
            content: Text(
              'Are you sure you want to delete "${outlet.outletName}"? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final outletProvider = Provider.of<OutletProvider>(
                    context,
                    listen: false,
                  );

                  if (authProvider.currentSession != null) {
                    final success = await outletProvider.deleteOutlet(
                      outlet.id,
                      authProvider.currentSession!,
                    );

                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Outlet deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sync Offline Data'),
            content: Consumer<OutletProvider>(
              builder: (context, outletProvider, child) {
                return Text(
                  'You have ${outletProvider.offlineOutletCount} outlets waiting to be synced. '
                  'Would you like to sync them now?',
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performSync();
                },
                child: const Text('Sync Now'),
              ),
            ],
          ),
    );
  }

  Future<void> _performSync() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final outletProvider = Provider.of<OutletProvider>(context, listen: false);

    if (authProvider.currentSession != null) {
      final result = await outletProvider.syncOfflineOutlets(
        authProvider.currentSession!,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }
}
