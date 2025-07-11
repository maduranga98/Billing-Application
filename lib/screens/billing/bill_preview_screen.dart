// lib/screens/billing/bill_preview_screen.dart (Fixed validation issue)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../services/billing/billing_service.dart';
import '../../services/printing/bill_printer_service.dart';
import '../../utils/bill_generator.dart';
import '../printing/printer_selection_screen.dart';

class BillPreviewScreen extends StatefulWidget {
  final String paymentType;

  const BillPreviewScreen({super.key, required this.paymentType});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  bool _isCreatingBill = false;
  bool _isPrinting = false;
  final TextEditingController _loadingCostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize loading cost with current value from provider
    final billingProvider = context.read<BillingProvider>();
    _loadingCostController.text = billingProvider.loadingCost.toStringAsFixed(
      0,
    );
  }

  @override
  void dispose() {
    _loadingCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Bill Preview',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Consumer<BillingProvider>(
        builder: (context, billingProvider, child) {
          if (billingProvider.selectedItems.isEmpty) {
            return const Center(child: Text('No items selected'));
          }

          return Column(
            children: [
              // Bill Preview Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Outlet Information
                      _buildOutletInfo(billingProvider),
                      const SizedBox(height: 20),

                      // Items List
                      _buildItemsList(billingProvider),
                      const SizedBox(height: 20),

                      // Loading Cost Section
                      _buildLoadingCostSection(billingProvider),
                      const SizedBox(height: 20),

                      // Bill Summary
                      _buildBillSummary(billingProvider),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              _buildActionButtons(billingProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOutletInfo(BillingProvider billingProvider) {
    final outlet = billingProvider.selectedOutlet!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Customer Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              outlet.outletName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (outlet.address.isNotEmpty)
              Text(
                outlet.address,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            if (outlet.phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    outlet.phoneNumber,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Payment: ${widget.paymentType.toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(BillingProvider billingProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${billingProvider.selectedItems.length} items',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: billingProvider.selectedItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = billingProvider.selectedItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Code: ${item.productCode}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.quantity} × Rs.${item.unitPrice.toStringAsFixed(2)}/kg',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${item.totalWeight.toStringAsFixed(1)}kg',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Rs.${item.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCostSection(BillingProvider billingProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Loading Cost',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _loadingCostController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Loading Cost (Rs.)',
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final cost = double.tryParse(value) ?? 0.0;
                      billingProvider.setLoadingCost(cost);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    billingProvider.setLoadingCost(0.0);
                    _loadingCostController.text = '0';
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade700,
                    elevation: 0,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (billingProvider.loadingCost > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Loading cost will be added to the total bill amount',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary(BillingProvider billingProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bill Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Subtotal',
              'Rs.${billingProvider.subtotalAmount.toStringAsFixed(2)}',
            ),
            if (billingProvider.loadingCost > 0)
              _buildSummaryRow(
                'Loading Cost',
                'Rs.${billingProvider.loadingCost.toStringAsFixed(2)}',
              ),
            const Divider(),
            _buildSummaryRow(
              'Total Amount',
              'Rs.${billingProvider.totalAmount.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? Colors.blue.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BillingProvider billingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Print Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isPrinting ? null : _showPrintOptions,
              icon:
                  _isPrinting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.print),
              label: Text(_isPrinting ? 'Printing...' : 'Print'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Create Bill Button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isCreatingBill ? null : _createBill,
              icon:
                  _isCreatingBill
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.receipt_long),
              label: Text(_isCreatingBill ? 'Creating...' : 'Create Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
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
    );
  }

  void _showPrintOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Print Options',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue),
                  title: const Text('Print Preview'),
                  subtitle: const Text('Preview bill before printing'),
                  onTap: () {
                    Navigator.pop(context);
                    _printBill();
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.bluetooth, color: Colors.green),
                  title: const Text('Printer Settings'),
                  subtitle: const Text('Configure Bluetooth printer'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToPrinterSetup();
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _printBill() async {
    if (_isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      final billingProvider = context.read<BillingProvider>();
      final authProvider = context.read<AuthProvider>();

      if (authProvider.currentSession == null) {
        throw Exception('User session not found');
      }

      // Generate print bill
      final printBill = BillGenerator.generatePrintBill(
        billNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        outlet: billingProvider.selectedOutlet!,
        salesRep: authProvider.currentSession!,
        selectedItems: billingProvider.selectedItems,
        paymentType: widget.paymentType,
        loadingCost: billingProvider.loadingCost, // Include loading cost
      );

      // Print the bill
      final result = await BillPrinterService.printBill(printBill);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result ? 'Bill printed successfully!' : 'Failed to print bill',
            ),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _navigateToPrinterSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterSelectionScreen()),
    ).then((_) {
      // Refresh printer status when returning
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _createBill() {
    final billingProvider = context.read<BillingProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to create bills'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate bill first - FIXED: Properly handle the validation result
    final validation = billingProvider.validateBill();
    if (!(validation['isValid'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation['error'] ?? 'Validation failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Confirm Bill Creation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outlet: ${billingProvider.selectedOutlet!.outletName}'),
                Text('Items: ${billingProvider.selectedItems.length}'),
                Text(
                  'Subtotal: Rs.${billingProvider.subtotalAmount.toStringAsFixed(2)}',
                ),
                if (billingProvider.loadingCost > 0)
                  Text(
                    'Loading Cost: Rs.${billingProvider.loadingCost.toStringAsFixed(2)}',
                  ),
                Text(
                  'Total: Rs.${billingProvider.totalAmount.toStringAsFixed(2)}',
                ),
                Text('Payment: ${widget.paymentType.toUpperCase()}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processBillCreation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Bill'),
              ),
            ],
          ),
    );
  }

  Future<void> _processBillCreation() async {
    if (_isCreatingBill) return;

    setState(() => _isCreatingBill = true);

    try {
      final billingProvider = context.read<BillingProvider>();
      final authProvider = context.read<AuthProvider>();

      // Create the bill with loading cost
      final billId = await BillingService.createBill(
        session: authProvider.currentSession!,
        outlet: billingProvider.selectedOutlet!,
        items: billingProvider.selectedItems,
        paymentType: widget.paymentType,
        loadingCost: billingProvider.loadingCost, // Include loading cost
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill created successfully! Bill ID: $billId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear the bill and navigate back
        billingProvider.resetBilling();

        // Navigate back to main screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating bill: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingBill = false);
      }
    }
  }
}
