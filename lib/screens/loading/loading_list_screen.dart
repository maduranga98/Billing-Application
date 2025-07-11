// lib/screens/loading/loading_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';
import '../../models/loading_item.dart';
import '../../widgets/common/loading_indicator.dart';

class LoadingListScreen extends StatefulWidget {
  const LoadingListScreen({super.key});

  @override
  State<LoadingListScreen> createState() => _LoadingListScreenState();
}

class _LoadingListScreenState extends State<LoadingListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Only 2 tabs now: All Items and Categories
    _tabController = TabController(length: 2, vsync: this);
    _loadLoadingData();
  }

  Future<void> _loadLoadingData() async {
    final authProvider = context.read<AuthProvider>();
    final loadingProvider = context.read<LoadingProvider>();

    if (authProvider.currentSession != null) {
      await loadingProvider.loadTodaysLoading(authProvider.currentSession!);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Consumer<LoadingProvider>(
        builder: (context, loadingProvider, child) {
          if (loadingProvider.isLoading) {
            return const LoadingIndicator(
              message: 'Loading today\'s inventory...',
            );
          }

          if (loadingProvider.hasError) {
            return CustomErrorWidget(
              message: loadingProvider.errorMessage,
              onRetry: _loadLoadingData,
            );
          }

          if (loadingProvider.hasNoLoading) {
            return const EmptyState(
              title: 'No Loading Assignment',
              message:
                  'No loading has been assigned for today. Contact your supervisor to get today\'s loading assignment.',
              icon: Icons.inbox_outlined,
            );
          }

          if (!loadingProvider.hasLoading) {
            return const EmptyState(
              title: 'No Items',
              message: 'No items found in today\'s loading.',
              icon: Icons.inventory_2_outlined,
            );
          }

          return Column(
            children: [
              _buildRouteHeader(loadingProvider),
              _buildLoadingStats(loadingProvider),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllItemsTab(loadingProvider),
                    _buildCategoriesTab(loadingProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildRefreshFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Today\'s Loading',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: Colors.deepPurple.shade800,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Consumer<LoadingProvider>(
          builder: (context, loadingProvider, child) {
            if (loadingProvider.lastUpdateTime != null) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Updated: ${DateFormat('HH:mm').format(loadingProvider.lastUpdateTime!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ],
    );
  }

  Widget _buildRouteHeader(LoadingProvider loadingProvider) {
    if (!loadingProvider.hasRouteContext) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route: ${loadingProvider.routeDisplayName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Areas: ${loadingProvider.routeAreasText}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStats(LoadingProvider loadingProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Total Items',
                loadingProvider.totalItems.toString(),
                Icons.inventory_2_outlined,
                Colors.blue,
              ),
            ),
            VerticalDivider(color: Colors.grey.shade300),
            Expanded(
              child: _buildStatItem(
                'Total Bags',
                loadingProvider.totalBags.toString(),
                Icons.shopping_bag_outlined,
                Colors.green,
              ),
            ),
            VerticalDivider(color: Colors.grey.shade300),
            Expanded(
              child: _buildStatItem(
                'Total Weight',
                '${loadingProvider.totalWeight.toStringAsFixed(0)}kg',
                Icons.scale,
                Colors.orange,
              ),
            ),
            VerticalDivider(color: Colors.grey.shade300),
            Expanded(
              child: _buildStatItem(
                'Total Value',
                'Rs ${NumberFormat('#,##0').format(loadingProvider.totalValue)}',
                Icons.attach_money,
                Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
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

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.blue.shade600,
        tabs: const [Tab(text: 'All Items'), Tab(text: 'Categories')],
      ),
    );
  }

  Widget _buildAllItemsTab(LoadingProvider loadingProvider) {
    List<LoadingItem> items = loadingProvider.availableItems;

    if (items.isEmpty) {
      return const EmptyState(
        title: 'No Items Found',
        message: 'No items available in today\'s loading.',
        icon: Icons.search_off,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildLoadingItemCard(items[index], loadingProvider);
      },
    );
  }

  Widget _buildCategoriesTab(LoadingProvider loadingProvider) {
    final categories = loadingProvider.itemsByCategory;

    if (categories.isEmpty) {
      return const EmptyState(
        title: 'No Categories',
        message: 'No item categories found.',
        icon: Icons.category_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories.keys.elementAt(index);
        final items = categories[category]!;

        return _buildCategoryCard(category, items);
      },
    );
  }

  Widget _buildLoadingItemCard(
    LoadingItem item,
    LoadingProvider loadingProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.rice_bowl, color: Colors.green.shade600),
        ),
        title: Text(
          item.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Code: ${item.productCode}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.riceType != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Type: ${item.riceType}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs ${NumberFormat('#,##0.00').format(item.pricePerKg)}/kg',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${item.bagQuantity}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade600,
                ),
              ),
              Text(
                'bags',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
        onTap: () {
          _showLoadingItemDetails(item);
        },
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<LoadingItem> items) {
    final totalValue = items.fold(0.0, (sum, item) => sum + item.totalValue);
    final totalBags = items.fold(0, (sum, item) => sum + item.bagQuantity);
    final totalWeight = items.fold(0.0, (sum, item) => sum + item.totalWeight);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.category, color: Colors.blue.shade600),
        ),
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${items.length} items • $totalBags bags'),
            Text('Weight: ${totalWeight.toStringAsFixed(0)}kg'),
            Text('Value: Rs ${NumberFormat('#,##0.00').format(totalValue)}'),
          ],
        ),
        children:
            items.map((item) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 4,
                ),
                title: Text(item.displayName),
                subtitle: Text('Code: ${item.productCode}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.bagQuantity} bags',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                    Text(
                      'Rs ${NumberFormat('#,##0.00').format(item.pricePerKg)}/kg',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                onTap: () => _showLoadingItemDetails(item),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildRefreshFAB() {
    return FloatingActionButton(
      onPressed: () async {
        final authProvider = context.read<AuthProvider>();
        final loadingProvider = context.read<LoadingProvider>();

        if (authProvider.currentSession != null) {
          await loadingProvider.refreshLoading(authProvider.currentSession!);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Loading data refreshed'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      backgroundColor: Colors.blue.shade600,
      child: const Icon(Icons.refresh, color: Colors.white),
    );
  }

  void _showLoadingItemDetails(LoadingItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildLoadingItemDetailsSheet(item),
    );
  }

  Widget _buildLoadingItemDetailsSheet(LoadingItem item) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.rice_bowl,
                  size: 30,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Code: ${item.productCode}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildDetailRow('Product Type', item.productType),
          if (item.riceType != null)
            _buildDetailRow('Rice Type', item.riceType!),
          _buildDetailRow('Bag Quantity', '${item.bagQuantity} bags'),
          _buildDetailRow('Bag Size', '${item.bagSize}kg per bag'),
          _buildDetailRow('Total Bags', '${item.bagsCount} bags'),
          _buildDetailRow(
            'Price per Kg',
            'Rs ${NumberFormat('#,##0.00').format(item.pricePerKg)}',
          ),
          _buildDetailRow('Total Weight', '${item.totalWeight}kg'),
          _buildDetailRow(
            'Total Value',
            'Rs ${NumberFormat('#,##0.00').format(item.totalValue)}',
          ),
          _buildDetailRow(
            'Individual Bags',
            '${item.bagsUsed.length} bag entries',
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
