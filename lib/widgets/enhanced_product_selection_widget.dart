// lib/widgets/enhanced_product_selection_widget.dart
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/providers/billing_provider.dart';
import 'package:provider/provider.dart';

import '../models/loading_item.dart';
import '../models/selected_bill_item.dart';

class EnhancedProductSelectionWidget extends StatefulWidget {
  const EnhancedProductSelectionWidget({Key? key}) : super(key: key);

  @override
  State<EnhancedProductSelectionWidget> createState() =>
      _EnhancedProductSelectionWidgetState();
}

class _EnhancedProductSelectionWidgetState
    extends State<EnhancedProductSelectionWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchAndFilter(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableProductsTab(),
                _buildSelectedItemsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Select Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Consumer<BillingProvider>(
            builder: (context, provider, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${provider.selectedItems.length} items',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Bar
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              // Category Filter
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('all', 'All'),
                    ...provider.getAvailableCategories().map(
                      (category) => _buildCategoryChip(category, category),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = value;
          });
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue,
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _buildTabBar() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(
                text:
                    'Available Products (${_getFilteredItems(provider).length})',
              ),
              Tab(text: 'Selected Items (${provider.selectedItems.length})'),
            ],
          ),
        );
      },
    );
  }

  List<LoadingItem> _getFilteredItems(BillingProvider provider) {
    var items = provider.searchAvailableItems(_searchQuery);
    if (_selectedCategory != 'all') {
      items = provider.filterItemsByCategory(_selectedCategory);
      if (_searchQuery.isNotEmpty) {
        items =
            items
                .where(
                  (item) =>
                      item.productName.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      item.productCode.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                )
                .toList();
      }
    }
    return items;
  }

  Widget _buildAvailableProductsTab() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        final filteredItems = _getFilteredItems(provider);

        if (filteredItems.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No products found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Try adjusting your search or filter',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _buildAvailableProductCard(item, provider);
          },
        );
      },
    );
  }

  Widget _buildAvailableProductCard(
    LoadingItem item,
    BillingProvider provider,
  ) {
    final availableQty = provider.getAvailableQuantityForProduct(
      item.productCode,
    );
    final selectedQty = provider.getSelectedQuantityForProduct(
      item.productCode,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.productCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        item.category == 'Rice'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          item.category == 'Rice'
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.scale, '${item.bagSize}kg', Colors.blue),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.inventory,
                  '$availableQty bags',
                  availableQty > 0 ? Colors.green : Colors.red,
                ),
                if (selectedQty > 0) ...[
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.shopping_cart,
                    '$selectedQty selected',
                    Colors.orange,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Rs.${item.minPrice.toStringAsFixed(2)} - Rs.${item.maxPrice.toStringAsFixed(2)}/kg',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed:
                      availableQty > 0
                          ? () => _showAddToCartDialog(item, provider)
                          : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedItemsTab() {
    return Consumer<BillingProvider>(
      builder: (context, provider, child) {
        if (provider.selectedItems.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No items selected',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Add items from the Available Products tab',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Summary Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: Rs.${provider.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${provider.totalItemCount} bags • ${provider.totalWeight.toStringAsFixed(1)}kg',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => provider.clearBill(),
                    icon: const Icon(Icons.clear_all, color: Colors.red),
                    label: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            // Selected Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.selectedItems.length,
                itemBuilder: (context, index) {
                  final item = provider.selectedItems[index];
                  return _buildSelectedItemCard(item, provider, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedItemCard(
    SelectedBillItem item,
    BillingProvider provider,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity} × ${item.bagSize}kg bags',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs.${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Rs.${item.unitPrice.toStringAsFixed(2)}/kg',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Quantity Controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          try {
                            provider.updateItemQuantity(
                              item.productId,
                              item.quantity - 1,
                            );
                          } catch (e) {
                            _showErrorSnackbar(e.toString());
                          }
                        },
                        icon: const Icon(Icons.remove, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          item.quantity.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          try {
                            provider.updateItemQuantity(
                              item.productId,
                              item.quantity + 1,
                            );
                          } catch (e) {
                            _showErrorSnackbar(e.toString());
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Price Edit Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditPriceDialog(item, provider),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Price'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Duplicate Button
                IconButton(
                  onPressed: () {
                    try {
                      provider.duplicateSelectedItem(item.productId);
                      _showSuccessSnackbar('Item duplicated successfully');
                    } catch (e) {
                      _showErrorSnackbar(e.toString());
                    }
                  },
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  tooltip: 'Duplicate Item',
                ),
                // Remove Button
                IconButton(
                  onPressed: () => provider.removeItemFromBill(item.productId),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove Item',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToCartDialog(LoadingItem item, BillingProvider provider) {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: item.pricePerKg.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add ${item.productName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Available: ${provider.getAvailableQuantityForProduct(item.productCode)} bags',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity (bags)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price per kg',
                    border: const OutlineInputBorder(),
                    helperText:
                        'Range: Rs.${item.minPrice.toStringAsFixed(2)} - Rs.${item.maxPrice.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    final quantity = int.parse(quantityController.text);
                    final price = double.parse(priceController.text);

                    provider.addItemToBill(
                      item: item,
                      quantity: quantity,
                      customPrice: price,
                    );

                    Navigator.pop(context);
                    _tabController.animateTo(1); // Switch to selected items tab
                    _showSuccessSnackbar('Item added to bill');
                  } catch (e) {
                    _showErrorSnackbar(e.toString());
                  }
                },
                child: const Text('Add to Bill'),
              ),
            ],
          ),
    );
  }

  void _showEditPriceDialog(SelectedBillItem item, BillingProvider provider) {
    final priceController = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );

    // Find the original loading item for price range
    final loadingItem = provider.availableItems.firstWhere(
      (li) => li.productCode == item.originalProductId,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Price - ${item.productName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Allowed Range: Rs.${loadingItem.minPrice.toStringAsFixed(2)} - Rs.${loadingItem.maxPrice.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price per kg',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    final newPrice = double.parse(priceController.text);
                    provider.updateItemPrice(item.productId, newPrice);
                    Navigator.pop(context);
                    _showSuccessSnackbar('Price updated successfully');
                  } catch (e) {
                    _showErrorSnackbar(e.toString());
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
