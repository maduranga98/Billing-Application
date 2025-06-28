// lib/screens/billing/item_detail_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/billing_provider.dart';
import '../../models/loading_item.dart';

class ItemDetailDialog extends StatefulWidget {
  final LoadingItem item;

  const ItemDetailDialog({super.key, required this.item});

  @override
  State<ItemDetailDialog> createState() => _ItemDetailDialogState();
}

class _ItemDetailDialogState extends State<ItemDetailDialog> {
  final TextEditingController _quantityController = TextEditingController();
  int _selectedQuantity = 1;

  @override
  void initState() {
    super.initState();

    // Set initial quantity if item is already selected
    final billingProvider = context.read<BillingProvider>();
    final currentQuantity = billingProvider.getSelectedQuantity(
      widget.item.productId,
    );

    if (currentQuantity > 0) {
      _selectedQuantity = currentQuantity;
      _quantityController.text = currentQuantity.toString();
    } else {
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  _buildDetailRow(
                    'Unit Price',
                    'Rs. ${widget.item.unitPrice.toStringAsFixed(2)}',
                  ),
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
                    onPressed: _selectedQuantity > 1 ? _decreaseQuantity : null,
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

            // Total Price
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Price',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    'Rs. ${(_selectedQuantity * widget.item.unitPrice).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
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
                    final isSelected = billingProvider.isItemSelected(
                      widget.item.productId,
                    );

                    if (isSelected) {
                      return Expanded(
                        child: OutlinedButton(
                          onPressed: _removeItem,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Remove',
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
                    final isSelected = billingProvider.isItemSelected(
                      widget.item.productId,
                    );
                    return isSelected
                        ? const SizedBox(width: 12)
                        : const SizedBox.shrink();
                  },
                ),

                // Add/Update Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Consumer<BillingProvider>(
                      builder: (context, billingProvider, child) {
                        final isSelected = billingProvider.isItemSelected(
                          widget.item.productId,
                        );
                        return Text(
                          isSelected ? 'Update' : 'Add to Bill',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
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

  void _addItem() {
    if (_selectedQuantity > 0 &&
        _selectedQuantity <= widget.item.availableQuantity) {
      final billingProvider = context.read<BillingProvider>();

      if (billingProvider.isItemSelected(widget.item.productId)) {
        // Update existing item
        billingProvider.updateItemQuantity(
          widget.item.productId,
          _selectedQuantity,
        );
      } else {
        // Add new item
        billingProvider.addItemToBill(widget.item, _selectedQuantity);
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.item.productName} ${billingProvider.isItemSelected(widget.item.productId) ? 'updated' : 'added'} to bill',
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeItem() {
    final billingProvider = context.read<BillingProvider>();
    billingProvider.removeItemFromBill(widget.item.productId);

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
