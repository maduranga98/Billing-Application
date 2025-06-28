// lib/screens/loading/loading_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';
import '../../models/loading_item.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state.dart';

class LoadingListScreen extends StatefulWidget {
  const LoadingListScreen({super.key});

  @override
  State<LoadingListScreen> createState() => _LoadingListScreenState();
}

class _LoadingListScreenState extends State<LoadingListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;
  String _selectedCategory = 'All';
  bool _showAvailableOnly = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    _searchController.dispose();
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
              _buildSearchAndFilters(loadingProvider),
              _buildLoadingStats(loadingProvider),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllItemsTab(loadingProvider),
                    _buildCategoriesTab(loadingProvider),
                    _buildLowStockTab(loadingProvider),
                    _buildOutOfStockTab(loadingProvider),
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
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey.shade800,
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
            color: Colors.green.shade200.withOpacity(0.5),
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
              color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.9),
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

  Widget _buildSearchAndFilters(LoadingProvider loadingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items, codes, or categories...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          loadingProvider.clearSearch();
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (query) {
              final authProvider = context.read<AuthProvider>();
              if (authProvider.currentSession != null) {
                loadingProvider.searchItems(
                  authProvider.currentSession!,
                  query,
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // Filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items:
                      ['All', ...loadingProvider.categories].map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
              ),

              const SizedBox(width: 12),

              FilterChip(
                label: const Text('Available Only'),
                selected: _showAvailableOnly,
                onSelected: (selected) {
                  setState(() {
                    _showAvailableOnly = selected;
                  });
                },
                selectedColor: Colors.green.shade100,
                checkmarkColor: Colors.green.shade700,
              ),
            ],
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
      child: Column(
        children: [
          IntrinsicHeight(
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
                    'Available',
                    loadingProvider.availableItemCount.toString(),
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                VerticalDivider(color: Colors.grey.shade300),
                Expanded(
                  child: _buildStatItem(
                    'Total Value',
                    'Rs ${NumberFormat('#,##0').format(loadingProvider.totalValue)}',
                    Icons.attach_money,
                    Colors.orange,
                  ),
                ),
                VerticalDivider(color: Colors.grey.shade300),
                Expanded(
                  child: _buildStatItem(
                    'Low Stock',
                    loadingProvider.lowStockCount.toString(),
                    Icons.warning_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ),

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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
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
        tabs: const [
          Tab(text: 'All Items'),
          Tab(text: 'Categories'),
          Tab(text: 'Low Stock'),
          Tab(text: 'Out of Stock'),
        ],
      ),
    );
  }

  Widget _buildAllItemsTab(LoadingProvider loadingProvider) {
    List<LoadingItem> items =
        loadingProvider.lastSearchQuery.isNotEmpty
            ? loadingProvider.searchResults
            : loadingProvider.availableItems;

    if (_selectedCategory != 'All') {
      items =
          items.where((item) => item.category == _selectedCategory).toList();
    }

    if (_showAvailableOnly) {
      items = items.where((item) => !item.isOutOfStock).toList();
    }

    if (items.isEmpty) {
      return const EmptyState(
        title: 'No Items Found',
        message: 'Try adjusting your search or filters.',
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

  Widget _buildLowStockTab(LoadingProvider loadingProvider) {
    final lowStockItems = loadingProvider.lowStockItems;

    if (lowStockItems.isEmpty) {
      return const EmptyState(
        title: 'No Low Stock Items',
        message: 'All items have sufficient quantities!',
        icon: Icons.check_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lowStockItems.length,
      itemBuilder: (context, index) {
        return _buildLoadingItemCard(lowStockItems[index], loadingProvider);
      },
    );
  }

  Widget _buildOutOfStockTab(LoadingProvider loadingProvider) {
    final outOfStockItems = loadingProvider.outOfStockItems;

    if (outOfStockItems.isEmpty) {
      return const EmptyState(
        title: 'No Out of Stock Items',
        message: 'Great! All items are available.',
        icon: Icons.check_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: outOfStockItems.length,
      itemBuilder: (context, index) {
        return _buildLoadingItemCard(outOfStockItems[index], loadingProvider);
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
            color: loadingProvider.getItemStatusColor(item).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.inventory_2,
            color: loadingProvider.getItemStatusColor(item),
          ),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Code: ${item.productCode}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              'Category: ${item.category.isEmpty ? 'Uncategorized' : item.category}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: loadingProvider
                        .getItemStatusColor(item)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    loadingProvider.getItemStatusText(item),
                    style: TextStyle(
                      color: loadingProvider.getItemStatusColor(item),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs ${NumberFormat('#,##0.00').format(item.unitPrice)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.availableQuantity}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: loadingProvider.getItemStatusColor(item),
              ),
            ),
            Text(
              'available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'of ${item.loadedQuantity}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ],
        ),
        onTap: () {
          _showLoadingItemDetails(item);
        },
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<LoadingItem> items) {
    final totalValue = items.fold(0.0, (sum, item) => sum + item.totalValue);
    final lowStockCount = items.where((item) => item.isLowStock).length;
    final outOfStockCount = items.where((item) => item.isOutOfStock).length;

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
            Text('${items.length} items'),
            Text('Value: Rs ${NumberFormat('#,##0.00').format(totalValue)}'),
            if (lowStockCount > 0)
              Text(
                '$lowStockCount low stock, $outOfStockCount out of stock',
                style: TextStyle(color: Colors.orange.shade600),
              ),
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
                title: Text(item.productName),
                subtitle: Text('Code: ${item.productCode}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.availableQuantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            item.isOutOfStock
                                ? Colors.red
                                : item.isLowStock
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                    Text(
                      'Rs ${NumberFormat('#,##0.00').format(item.unitPrice)}',
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
                  color:
                      item.isOutOfStock
                          ? Colors.red.shade100
                          : item.isLowStock
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.inventory_2,
                  size: 30,
                  color:
                      item.isOutOfStock
                          ? Colors.red.shade600
                          : item.isLowStock
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
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

          _buildDetailRow(
            'Category',
            item.category.isEmpty ? 'Uncategorized' : item.category,
          ),
          _buildDetailRow(
            'Loaded Quantity',
            '${item.loadedQuantity} ${item.unit}',
          ),
          _buildDetailRow('Sold Quantity', '${item.soldQuantity} ${item.unit}'),
          _buildDetailRow(
            'Available Quantity',
            '${item.availableQuantity} ${item.unit}',
          ),
          _buildDetailRow(
            'Unit Price',
            'Rs ${NumberFormat('#,##0.00').format(item.unitPrice)}',
          ),
          _buildDetailRow('Total Weight', '${item.totalWeight} kg'),
          _buildDetailRow(
            'Available Value',
            'Rs ${NumberFormat('#,##0.00').format(item.totalValue)}',
          ),
          _buildDetailRow(
            'Status',
            item.isOutOfStock
                ? 'Out of Stock'
                : item.isLowStock
                ? 'Low Stock'
                : 'Available',
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
