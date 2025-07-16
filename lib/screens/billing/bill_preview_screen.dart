// lib/screens/billing/bill_preview_screen.dart (Fixed Version with Updated Method Call)
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/services/printing/bill_printer_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_provider.dart';
import '../../services/billing/billing_service.dart';
import '../../utils/bill_generator.dart';
import '../../dialogs/payment_method_dialog.dart';
import '../printing/printer_selection_screen.dart';

class BillPreviewScreen extends StatefulWidget {
  const BillPreviewScreen({super.key});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  bool _isCreatingBill = false;
  bool _isPrinting = false;
  String? _selectedPaymentType;
  String? _paymentTypeError;
  final TextEditingController _loadingCostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize loading cost with current value from provider
    final billingProvider = context.read<BillingProvider>();
    _loadingCostController.text = billingProvider.loadingCost.toStringAsFixed(
      0,
    );

    // Initialize payment type from provider if already set
    _selectedPaymentType =
        billingProvider.paymentType.isNotEmpty
            ? billingProvider.paymentType
            : null;
  }

  @override
  void dispose() {
    _loadingCostController.dispose();
    super.dispose();
  }

  // FIXED: Create bill method with updated parameters
  Future<void> _createBill() async {
    // Validate payment method is selected
    if (_selectedPaymentType == null) {
      setState(() {
        _paymentTypeError = 'Please select a payment method';
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final billingProvider = context.read<BillingProvider>();

    final session = authProvider.currentSession;
    final outlet = billingProvider.selectedOutlet;

    if (session == null || outlet == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing session or outlet information'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isCreatingBill = true;
    });

    try {
      // FIXED: Use the new method signature with individual parameters
      final billId = await BillingService.createBill(
        outletId: outlet.id,
        outletName: outlet.outletName,
        outletAddress: outlet.address ?? '',
        outletPhone: outlet.phoneNumber ?? '',
        items: billingProvider.selectedItems,
        paymentType: _selectedPaymentType!,
        loadingCost: billingProvider.loadingCost,
        discountAmount: 0.0, // Add discount if needed
        taxAmount: 0.0, // Add tax if needed
        session: session,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill created successfully! ID: $billId'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear the billing data
        billingProvider.clearBill();

        // Navigate back to home or bills list
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBill = false;
        });
      }
    }
  }

  // Updated Print bill method with complete functionality
  Future<void> _printBill() async {
    if (_selectedPaymentType == null) {
      setState(() {
        _paymentTypeError = 'Please select a payment method before printing';
      });
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final billingProvider = context.read<BillingProvider>();
      final authProvider = context.read<AuthProvider>();

      // Check if user session exists
      if (authProvider.currentSession == null) {
        throw Exception('User session not found');
      }

      // Check if printer is connected
      final isConnected = await BillPrinterService.isDeviceConnected();

      if (!isConnected) {
        // Show printer setup dialog if not connected
        final shouldSetup = await _showPrinterSetupDialog();
        if (!shouldSetup) {
          return;
        }

        // Check if printer was connected after setup
        final isConnectedAfterSetup =
            await BillPrinterService.isDeviceConnected();
        if (!isConnectedAfterSetup) {
          throw Exception('Printer not connected. Please setup printer first.');
        }
      }

      // Generate print bill with all the required data
      final printBill = BillGenerator.generatePrintBill(
        billNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        outlet: billingProvider.selectedOutlet!,
        salesRep: authProvider.currentSession!,
        selectedItems: billingProvider.selectedItems,
        paymentType: _selectedPaymentType!,
        loadingCost: billingProvider.loadingCost,
      );

      // Print the bill
      final printResult = await BillPrinterService.printBill(printBill);

      if (mounted) {
        if (printResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Bill printed successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception(
            'Failed to print bill. Please check printer connection.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Print error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  // Show printer setup dialog
  Future<bool> _showPrinterSetupDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    const Text('Printer Setup Required'),
                  ],
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No printer is currently connected. You need to setup a Bluetooth printer first.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Steps to setup printer:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text('1. Turn on your Bluetooth printer'),
                    Text('2. Pair it with your device'),
                    Text('3. Select it from the printer list'),
                    Text('4. Test the connection'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.settings_bluetooth),
                    label: const Text('Setup Printer'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  // Updated action buttons with better print functionality
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Print Bill Button with Options
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
                label: Text(_isPrinting ? 'Printing...' : 'Print Bill'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                  backgroundColor:
                      _selectedPaymentType != null
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show print options bottom sheet
  void _showPrintOptions() {
    if (_selectedPaymentType == null) {
      setState(() {
        _paymentTypeError = 'Please select a payment method before printing';
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.print,
                          size: 32,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Print Options',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your printing option',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Print Bill Option
                      _buildPrintOption(
                        icon: Icons.print,
                        title: 'Print Bill',
                        subtitle:
                            'Print the bill directly to connected printer',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          _printBill();
                        },
                      ),
                      const SizedBox(height: 12),

                      // Printer Setup Option
                      _buildPrintOption(
                        icon: Icons.settings_bluetooth,
                        title: 'Printer Setup',
                        subtitle: 'Configure and connect Bluetooth printer',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToPrinterSetup();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }

  // Build print option widget
  Widget _buildPrintOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // Navigate to printer setup
  Future<void> _navigateToPrinterSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterSelectionScreen()),
    );
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

          // Generate summary with null safety and debug logging
          Map<String, dynamic> summary;
          try {
            summary = BillGenerator.generateBillSummary(
              selectedItems: billingProvider.selectedItems,
              loadingCost: billingProvider.loadingCost,
            );

            // Debug: Print the actual summary to see what keys are available
            print('Generated summary: $summary');
            print('Selected items: ${billingProvider.selectedItems.length}');
            print(
              'Items total prices: ${billingProvider.selectedItems.map((item) => '${item.productName}: ${item.totalPrice}').join(', ')}',
            );
          } catch (e) {
            // Fallback to safe default values if BillGenerator fails
            print('Error generating bill summary: $e');
            summary = {
              'subtotalAmount': 0.0,
              'loadingCost': billingProvider.loadingCost,
              'totalAmount': billingProvider.loadingCost,
            };
          }

          // Use the correct key names from BillGenerator
          summary = {
            'subtotalAmount': summary['subtotalAmount'] ?? 0.0,
            'loadingCost': summary['loadingCost'] ?? 0.0,
            'totalAmount': summary['totalAmount'] ?? 0.0,
            ...summary, // Keep any other keys that might exist
          };

          return Column(
            children: [
              // Bill Preview Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Debug information (remove in production)
                      if (summary['subtotalAmount'] == 0.0 &&
                          billingProvider.selectedItems.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Debug Info:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              Text(
                                'Items: ${billingProvider.selectedItems.length}',
                              ),
                              Text(
                                'Provider subtotal: ${billingProvider.subtotalAmount}',
                              ),
                              Text('Summary keys: ${summary.keys.join(', ')}'),
                              ...billingProvider.selectedItems
                                  .map(
                                    (item) => Text(
                                      '${item.productName}: Rs.${item.totalPrice}',
                                    ),
                                  )
                                  .take(3),
                            ],
                          ),
                        ),
                      ],

                      // Outlet Information Card
                      _buildInfoCard(
                        title: 'Outlet Information',
                        icon: Icons.store,
                        children: [
                          _buildInfoRow(
                            'Name',
                            billingProvider.selectedOutlet?.outletName ?? 'N/A',
                          ),
                          _buildInfoRow(
                            'Address',
                            billingProvider.selectedOutlet?.address ?? 'N/A',
                          ),
                          _buildInfoRow(
                            'Phone',
                            billingProvider.selectedOutlet?.phoneNumber ??
                                'N/A',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment Method Selection Card
                      _buildPaymentMethodCard(billingProvider),
                      const SizedBox(height: 16),

                      // Loading Cost Card
                      _buildLoadingCostCard(billingProvider),
                      const SizedBox(height: 16),

                      // Items List Card
                      _buildItemsCard(billingProvider),
                      const SizedBox(height: 16),

                      // Bill Summary Card
                      _buildSummaryCard(summary),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons
              _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethodCard(BillingProvider billingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _paymentTypeError != null
                  ? Colors.red.shade300
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with action button
          Row(
            children: [
              Icon(Icons.payment, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final result = await PaymentMethodDialog.show(
                    context,
                    currentSelection: _selectedPaymentType,
                  );

                  if (result != null) {
                    setState(() {
                      _selectedPaymentType = result;
                      _paymentTypeError = null;
                    });
                    billingProvider.setPaymentType(result);
                  }
                },
                icon: Icon(
                  _selectedPaymentType != null ? Icons.edit : Icons.add,
                  size: 16,
                ),
                label: Text(
                  _selectedPaymentType != null ? 'Change' : 'Select',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment method display
          if (_selectedPaymentType != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getPaymentMethodColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getPaymentMethodColor().withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getPaymentMethodIcon(),
                    size: 20,
                    color: _getPaymentMethodColor(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedPaymentType!.toUpperCase()} PAYMENT',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _getPaymentMethodColor(),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _getPaymentMethodDescription(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getPaymentMethodColor().withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _getPaymentMethodColor(),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // No payment method selected
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _paymentTypeError != null
                          ? Colors.red.shade300
                          : Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, size: 24, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No payment method selected',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ],

          // Error message
          if (_paymentTypeError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text(
                  _paymentTypeError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingCostCard(BillingProvider billingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Text(
                'Loading Cost',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loadingCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Enter loading cost (optional)',
              prefixText: 'Rs. ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            onChanged: (value) {
              final cost = double.tryParse(value) ?? 0.0;
              billingProvider.setLoadingCost(cost);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(BillingProvider billingProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Items (${billingProvider.selectedItems.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...billingProvider.selectedItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${item.quantity} bags',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Rs.${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Build summary card with correct keys
  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    // Use the correct key names from BillGenerator
    final subtotal = (summary['subtotalAmount'] as double?) ?? 0.0;
    final loadingCost = (summary['loadingCost'] as double?) ?? 0.0;
    final totalAmount = (summary['totalAmount'] as double?) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Bill Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', 'Rs.${subtotal.toStringAsFixed(2)}'),
          if (loadingCost > 0)
            _buildSummaryRow(
              'Loading Cost',
              'Rs.${loadingCost.toStringAsFixed(2)}',
            ),
          const Divider(color: Colors.blue),
          _buildSummaryRow(
            'Total Amount',
            'Rs.${totalAmount.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
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
              color: isTotal ? Colors.blue.shade800 : Colors.blue.shade700,
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? Colors.blue.shade800 : Colors.blue.shade700,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for payment method display
  Color _getPaymentMethodColor() {
    switch (_selectedPaymentType?.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'credit':
        return Colors.orange;
      case 'cheque':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentMethodIcon() {
    switch (_selectedPaymentType?.toLowerCase()) {
      case 'cash':
        return Icons.payments;
      case 'credit':
        return Icons.credit_card;
      case 'cheque':
        return Icons.receipt_long;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodDescription() {
    switch (_selectedPaymentType?.toLowerCase()) {
      case 'cash':
        return 'Immediate payment in cash';
      case 'credit':
        return 'Payment on credit terms';
      case 'cheque':
        return 'Payment by bank cheque';
      default:
        return 'Payment method';
    }
  }
}
