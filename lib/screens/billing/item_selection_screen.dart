// lib/screens/billing/item_selection_screen.dart (Fixed for Multiple Selection)
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/providers/billing_provider.dart';
import 'package:provider/provider.dart';

import '../../models/loading_item.dart';
import 'item_detail_dialog.dart';

// Extension for lastOrNull
extension ListExtension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

class ItemSelectionScreen extends StatefulWidget {
  const ItemSelectionScreen({super.key});

  @override
  State<ItemSelectionScreen> createState() => _ItemSelectionScreenState();
}

class _ItemSelectionScreenState extends State<ItemSelectionScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _proceedToBill() {
    final billingProvider = context.read<BillingProvider>();
    final validation = billingProvider.validateBill();

    if (validation['isValid']) {
      Navigator.pushNamed(context, '/billing/preview');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation['error']),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _showItemDetailDialog(LoadingItem item) {
    showDialog(
      context: context,
      builder: (context) => ItemDetailDialog(item: item),
    );
  }

  // REMOVED: Quick add item method - not practical

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: Consumer<BillingProvider>(
          builder: (context, billingProvider, child) {
            return Column(
              children: [
                const Text(
                  'Select Items',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                if (billingProvider.selectedOutlet != null)
                  Text(
                    billingProvider.selectedOutlet!.outletName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            );
          },
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Total Amount Header
          Consumer<BillingProvider>(
            builder: (context, billingProvider, child) {
              return Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            'Rs.${billingProvider.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          // ADDED: Show item count
                          if (billingProvider.selectedItems.isNotEmpty)
                            Text(
                              '${billingProvider.selectedItems.length} items selected',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed:
                          billingProvider.selectedItems.isNotEmpty
                              ? _proceedToBill
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Bill',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search and Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
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
                const SizedBox(height: 12),

                // Category Filter
                Consumer<BillingProvider>(
                  builder: (context, billingProvider, child) {
                    final categories =
                        ['All'] +
                        billingProvider.availableItems
                            .map((item) => item.category)
                            .toSet()
                            .toList();

                    return SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategory == category;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: Colors.blue.shade100,
                              checkmarkColor: Colors.blue.shade700,
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade700,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color:
                                    isSelected
                                        ? Colors.blue.shade300
                                        : Colors.grey.shade300,
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
          ),

          // Items List
          Expanded(
            child: Consumer<BillingProvider>(
              builder: (context, billingProvider, child) {
                if (billingProvider.isLoadingItems) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredItems =
                    billingProvider.availableItems.where((item) {
                      final matchesSearch =
                          item.productName.toLowerCase().contains(
                            _searchQuery,
                          ) ||
                          item.productCode.toLowerCase().contains(_searchQuery);
                      final matchesCategory =
                          _selectedCategory == 'All' ||
                          item.category == _selectedCategory;
                      return matchesSearch &&
                          matchesCategory &&
                          item.availableQuantity > 0;
                    }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filter criteria',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildItemCard(item, billingProvider),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(LoadingItem item, BillingProvider billingProvider) {
    // FIXED: Show all selected items for this product, not just check if any exists
    final selectedItems = billingProvider.getSelectedItemsForProduct(
      item.productCode,
    );
    final hasSelectedItems = selectedItems.isNotEmpty;
    final availableQty = billingProvider.getAvailableQuantityForProduct(
      item.productCode,
    );
    final selectedQty = billingProvider.getSelectedQuantityForProduct(
      item.productCode,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasSelectedItems ? Colors.blue.shade300 : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemDetailDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Item Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          hasSelectedItems
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color:
                          hasSelectedItems
                              ? Colors.blue.shade600
                              : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Item Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${item.productCode}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Available: $availableQty ${item.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                availableQty <= 10
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selection Status - FIXED: Show multiple selections
                  if (hasSelectedItems)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${selectedItems.length} entries',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$selectedQty bags',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // FIXED: Show multiple selected items if any
              if (hasSelectedItems) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Items:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...selectedItems
                          .map(
                            (selectedItem) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${selectedItem.quantity} bags @ Rs.${selectedItem.unitPrice.toStringAsFixed(2)}/kg',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  Text(
                                    'Rs.${selectedItem.totalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Price Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Price Range
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Price Range',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Rs.${item.minPrice.toStringAsFixed(2)} - Rs.${item.maxPrice.toStringAsFixed(2)}/kg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Default Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Default Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Rs.${item.pricePerKg.toStringAsFixed(2)}/kg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),

                    // Total for all selected items of this product
                    if (hasSelectedItems) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Selected Value',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Rs.${selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action Buttons - FIXED: Only one button for adding
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      availableQty > 0
                          ? () => _showItemDetailDialog(item)
                          : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Add to Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasSelectedItems
                            ? Colors.blue.shade600
                            : Colors.green.shade600,
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
        ),
      ),
    );
  }
}
