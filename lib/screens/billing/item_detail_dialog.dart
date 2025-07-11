// lib/screens/billing/item_detail_dialog.dart (Fixed for Enhanced Provider)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumorabiz_billing/providers/billing_provider.dart';
import 'package:provider/provider.dart';
import '../../models/loading_item.dart';

class ItemDetailDialog extends StatefulWidget {
  final LoadingItem item;

  const ItemDetailDialog({super.key, required this.item});

  @override
  State<ItemDetailDialog> createState() => _ItemDetailDialogState();
}

class _ItemDetailDialogState extends State<ItemDetailDialog> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  int _selectedQuantity = 1;
  double _selectedPrice = 0.0;

  @override
  void initState() {
    super.initState();

    // Set initial price to default price (pricePerKg)
    _selectedPrice = widget.item.pricePerKg;
    _priceController.text = _selectedPrice.toStringAsFixed(2);

    // FIXED: Don't pre-fill with existing item data for multiple selection
    // Always start fresh to allow multiple entries
    _quantityController.text = '1';
    _selectedQuantity = 1;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _decreaseQuantity() {
    if (_selectedQuantity > 1) {
      setState(() {
        _selectedQuantity--;
        _quantityController.text = _selectedQuantity.toString();
      });
    }
  }

  void _increaseQuantity() {
    if (_selectedQuantity < widget.item.availableQuantity) {
      setState(() {
        _selectedQuantity++;
        _quantityController.text = _selectedQuantity.toString();
      });
    }
  }

  void _setMinPrice() {
    setState(() {
      _selectedPrice = widget.item.minPrice;
      _priceController.text = _selectedPrice.toStringAsFixed(2);
    });
  }

  void _setMaxPrice() {
    setState(() {
      _selectedPrice = widget.item.maxPrice;
      _priceController.text = _selectedPrice.toStringAsFixed(2);
    });
  }

  void _setDefaultPrice() {
    setState(() {
      _selectedPrice = widget.item.pricePerKg;
      _priceController.text = _selectedPrice.toStringAsFixed(2);
    });
  }

  bool _isPriceValid() {
    return _selectedPrice >= widget.item.minPrice &&
        _selectedPrice <= widget.item.maxPrice;
  }

  String? _getPriceError() {
    if (_selectedPrice < widget.item.minPrice) {
      return 'Price cannot be less than Rs.${widget.item.minPrice.toStringAsFixed(2)}';
    }
    if (_selectedPrice > widget.item.maxPrice) {
      return 'Price cannot be more than Rs.${widget.item.maxPrice.toStringAsFixed(2)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Code: ${widget.item.productCode}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Item Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Category', widget.item.category),
                    const SizedBox(height: 12),
                    _buildDetailRow('Batch', widget.item.batchInfo),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Available Quantity',
                      '${widget.item.availableQuantity} ${widget.item.unit}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Unit', widget.item.unit),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Price Selection Section
              Text(
                'Select Price per kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),

              // Price Range Info
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Price range: Rs.${widget.item.minPrice.toStringAsFixed(2)} - Rs.${widget.item.maxPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Price Input and Quick Buttons
              Row(
                children: [
                  // Price Input
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color:
                                _isPriceValid()
                                    ? Colors.grey.shade300
                                    : Colors.red.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color:
                                _isPriceValid()
                                    ? Colors.grey.shade300
                                    : Colors.red.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color:
                                _isPriceValid()
                                    ? Colors.blue.shade400
                                    : Colors.red.shade400,
                          ),
                        ),
                        labelText: 'Price per kg',
                        prefixText: 'Rs. ',
                        errorText: _getPriceError(),
                        errorMaxLines: 2,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final price = double.tryParse(value) ?? 0.0;
                          setState(() {
                            _selectedPrice = price;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Quick Price Buttons
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildPriceButton(
                                'Min\nRs.${widget.item.minPrice.toStringAsFixed(0)}',
                                () => _setMinPrice(),
                                _selectedPrice == widget.item.minPrice,
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildPriceButton(
                                'Default\nRs.${widget.item.pricePerKg.toStringAsFixed(0)}',
                                () => _setDefaultPrice(),
                                _selectedPrice == widget.item.pricePerKg,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildPriceButton(
                                'Max\nRs.${widget.item.maxPrice.toStringAsFixed(0)}',
                                () => _setMaxPrice(),
                                _selectedPrice == widget.item.maxPrice,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quantity Selection
              Text(
                'Select Quantity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Decrease Button
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed:
                          _selectedQuantity > 1 ? _decreaseQuantity : null,
                      icon: const Icon(Icons.remove),
                      color:
                          _selectedQuantity > 1
                              ? Colors.blue.shade600
                              : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Quantity Input
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelText: 'Quantity',
                        suffixText: widget.item.unit,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final quantity = int.tryParse(value) ?? 1;
                          setState(() {
                            _selectedQuantity = quantity.clamp(
                              1,
                              widget.item.availableQuantity,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Increase Button
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed:
                          _selectedQuantity < widget.item.availableQuantity
                              ? _increaseQuantity
                              : null,
                      icon: const Icon(Icons.add),
                      color:
                          _selectedQuantity < widget.item.availableQuantity
                              ? Colors.blue.shade600
                              : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Total Price Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Unit Price',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          'Rs.${_selectedPrice.toStringAsFixed(2)} per kg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          'Rs.${(_selectedQuantity * widget.item.bagSize * _selectedPrice).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  // Remove Button (if item is already selected)
                  Consumer<BillingProvider>(
                    builder: (context, billingProvider, child) {
                      final hasSelectedItems =
                          billingProvider
                              .getSelectedItemsForProduct(
                                widget.item.productCode,
                              )
                              .isNotEmpty;

                      if (hasSelectedItems) {
                        return Expanded(
                          child: OutlinedButton(
                            onPressed: _showRemoveOptions,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Remove Items',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  Consumer<BillingProvider>(
                    builder: (context, billingProvider, child) {
                      final hasSelectedItems =
                          billingProvider
                              .getSelectedItemsForProduct(
                                widget.item.productCode,
                              )
                              .isNotEmpty;
                      return hasSelectedItems
                          ? const SizedBox(width: 16)
                          : const SizedBox.shrink();
                    },
                  ),

                  // Add Button - CHANGED: Always shows "Add to Bill"
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isPriceValid() ? _addOrUpdateItem : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isPriceValid()
                                ? Colors.blue.shade600
                                : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Add to Bill',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPriceButton(
    String text,
    VoidCallback onPressed,
    bool isSelected,
    Color color,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? color : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  void _addOrUpdateItem() {
    final billingProvider = context.read<BillingProvider>();

    try {
      // FIXED: Always add as new item (multiple selection)
      billingProvider.addItemToBill(
        item: widget.item,
        quantity: _selectedQuantity,
        customPrice: _selectedPrice,
      );

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.item.productName} added to bill'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showRemoveOptions() {
    final billingProvider = context.read<BillingProvider>();
    final selectedItems = billingProvider.getSelectedItemsForProduct(
      widget.item.productCode,
    );

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Remove Items - ${widget.item.productName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...selectedItems
                    .map(
                      (selectedItem) => ListTile(
                        title: Text(
                          '${selectedItem.quantity} bags @ Rs.${selectedItem.unitPrice.toStringAsFixed(2)}/kg',
                        ),
                        subtitle: Text(
                          'Total: Rs.${selectedItem.totalPrice.toStringAsFixed(2)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            billingProvider.removeItemFromBill(
                              selectedItem.productId,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Item removed from bill'),
                                backgroundColor: Colors.orange.shade600,
                              ),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Remove all items for this product
                          for (final item in selectedItems) {
                            billingProvider.removeItemFromBill(item.productId);
                          }
                          Navigator.pop(context);
                          Navigator.pop(context); // Close dialog too
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'All ${widget.item.productName} items removed',
                              ),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Remove All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _removeItem() {
    final billingProvider = context.read<BillingProvider>();
    billingProvider.removeItemFromBillByProductId(
      widget.item.productCode,
    ); // Fixed method

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item.productName} removed from bill'),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
