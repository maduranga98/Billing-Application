// lib/screens/billing/item_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/billing_provider.dart';
import '../../models/loading_item.dart';
import 'item_detail_dialog.dart';

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      'Rs. ${billingProvider.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
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
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
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
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
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
                    final categories = [
                      'All',
                      ...billingProvider.availableItems
                          .map((item) => item.category)
                          .toSet()
                          .toList(),
                    ];

                    return SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategory == category;

                          return FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: Colors.blue.shade100,
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
                          'No items available',
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

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildItemCard(item, billingProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<BillingProvider>(
        builder: (context, billingProvider, child) {
          if (billingProvider.selectedItems.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${billingProvider.selectedItems.length} items selected',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Rs. ${billingProvider.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _proceedToBill(),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(LoadingItem item, BillingProvider billingProvider) {
    final isSelected = billingProvider.isItemSelected(item.productId);
    final selectedQuantity = billingProvider.getSelectedQuantity(
      item.productId,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade300 : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemDetailDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color:
                      isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
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
                      'Available: ${item.availableQuantity} ${item.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            item.availableQuantity <= 10
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${item.unitPrice.toStringAsFixed(2)} per ${item.unit}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Indicator
              if (isSelected) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$selectedQuantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetailDialog(LoadingItem item) {
    showDialog(
      context: context,
      builder: (context) => ItemDetailDialog(item: item),
    );
  }

  void _proceedToBill() {
    final billingProvider = context.read<BillingProvider>();
    final validation = billingProvider.validateBill();

    if (!validation['isValid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation['error']),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    Navigator.pushNamed(context, '/billing/bill-preview');
  }
}
