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
    _loadOutlets();
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Outlets',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
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

        return Column(
          children: [
            // Search and Filter Section
            _buildSearchAndFilter(),

            // Outlets List
            Expanded(
              child:
                  outletProvider.outlets.isEmpty
                      ? _buildEmptyState()
                      : _buildOutletsList(outletProvider.outlets),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
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
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                Provider.of<OutletProvider>(
                  context,
                  listen: false,
                ).searchOutlets(value);
              },
              decoration: InputDecoration(
                hintText: 'Search outlets...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            Provider.of<OutletProvider>(
                              context,
                              listen: false,
                            ).searchOutlets('');
                          },
                          icon: Icon(Icons.clear, color: Colors.grey[500]),
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter Chips
          Consumer<OutletProvider>(
            builder: (context, outletProvider, child) {
              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: outletProvider.outletTypes.length,
                  itemBuilder: (context, index) {
                    final type = outletProvider.outletTypes[index];
                    final isSelected =
                        outletProvider.selectedOutletType == type;

                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (selected) {
                          outletProvider.filterByType(type);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.blue[100],
                        checkmarkColor: Colors.blue[600],
                        labelStyle: TextStyle(
                          color:
                              isSelected ? Colors.blue[700] : Colors.grey[600],
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color:
                              isSelected
                                  ? Colors.blue[300]!
                                  : Colors.grey[300]!,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOutletsList(List<Outlet> outlets) {
    return RefreshIndicator(
      onRefresh: _loadOutlets,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: outlets.length,
        itemBuilder: (context, index) {
          final outlet = outlets[index];
          return _buildOutletCard(outlet);
        },
      ),
    );
  }

  Widget _buildOutletCard(Outlet outlet) {
    final isOffline =
        outlet.id.length <= 15; // Offline outlets have shorter IDs

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () => _showOutletDetails(outlet),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Outlet Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              outlet.outletName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isOffline)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outlet.outletType,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Outlet Image or Placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child:
                        outlet.imageUrl != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  outlet.imageUrl == 'offline_image'
                                      ? Icon(
                                        Icons.image,
                                        color: Colors.grey[400],
                                        size: 24,
                                      )
                                      : Image.network(
                                        outlet.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Icon(
                                            Icons.broken_image,
                                            color: Colors.grey[400],
                                            size: 24,
                                          );
                                        },
                                      ),
                            )
                            : Icon(
                              Icons.store,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Outlet Details
              _buildDetailRow(Icons.person_outline, outlet.ownerName),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.location_city, outlet.address),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.phone_outlined, outlet.phoneNumber),

              const SizedBox(height: 12),

              // Bottom Row
              Row(
                children: [
                  Text(
                    'Added ${_formatDate(outlet.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showOutletOptions(outlet),
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
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
              'Start by adding your first outlet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddOutlet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Outlet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _navigateToAddOutlet(),
      backgroundColor: const Color(0xFF2196F3),
      foregroundColor: Colors.white,
      elevation: 4,
      child: const Icon(Icons.add, size: 28),
    );
  }

  // Helper Methods
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _navigateToAddOutlet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddOutletScreen()),
    );

    if (result == true) {
      await _loadOutlets();
    }
  }

  void _showOutletDetails(Outlet outlet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildOutletDetailsSheet(outlet),
    );
  }

  Widget _buildOutletDetailsSheet(Outlet outlet) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    outlet.outletName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (outlet.imageUrl != null &&
                      outlet.imageUrl != 'offline_image')
                    Container(
                      width: double.infinity,
                      height: 200,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          outlet.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey[400],
                            );
                          },
                        ),
                      ),
                    ),

                  // Details
                  _buildDetailSection('Owner', outlet.ownerName, Icons.person),
                  _buildDetailSection(
                    'Type',
                    outlet.outletType,
                    Icons.category,
                  ),
                  _buildDetailSection(
                    'Address',
                    outlet.address,
                    Icons.location_on,
                  ),
                  _buildDetailSection('Phone', outlet.phoneNumber, Icons.phone),
                  _buildDetailSection(
                    'Location',
                    '${outlet.latitude.toStringAsFixed(6)}, ${outlet.longitude.toStringAsFixed(6)}',
                    Icons.my_location,
                  ),
                  _buildDetailSection(
                    'Created',
                    '${outlet.createdAt.day}/${outlet.createdAt.month}/${outlet.createdAt.year}',
                    Icons.calendar_today,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOutletOptions(Outlet outlet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Outlet'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to edit screen
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Outlet',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(outlet);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _confirmDelete(Outlet outlet) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Outlet'),
            content: Text(
              'Are you sure you want to delete "${outlet.outletName}"?',
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
