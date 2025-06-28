// lib/screens/billing/bill_preview_screen.dart - Updated with Receipt Widget
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/models/print_bill.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/billing_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/printing/bill_printer_service.dart';
import '../../utils/bill_generator.dart';
import '../../widgets/printing/bill_receipt_widget.dart';

// Temporary placeholder until you create the actual PrinterSelectionScreen
class PrinterSelectionScreen extends StatelessWidget {
  const PrinterSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Setup'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Printer setup screen will be implemented'),
      ),
    );
  }
}

class BillPreviewScreen extends StatefulWidget {
  const BillPreviewScreen({super.key});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  String _selectedPaymentType = 'cash';
  final List<String> _paymentTypes = ['cash', 'credit', 'cheque'];
  bool _isPrinting = false;
  bool _isControllerReady = false;
  late PrintBill _billData;

  @override
  void initState() {
    super.initState();
    _generateBillData();
  }

  void _generateBillData() {
    final billingProvider = context.read<BillingProvider>();
    final authProvider = context.read<AuthProvider>();

    _billData = BillGenerator.generatePrintBill(
      billNumber: _generateBillNumber(),
      outlet: billingProvider.selectedOutlet!,
      salesRep: authProvider.currentSession!,
      selectedItems: billingProvider.selectedItems,
      paymentType: _selectedPaymentType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'Bill Preview',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          // Printer Status Icon
          IconButton(
            onPressed: () => _showPrinterOptions(),
            icon: Icon(
              BillPrinterService.isConnected
                  ? Icons.print
                  : Icons.print_disabled,
              color:
                  BillPrinterService.isConnected
                      ? Colors.white
                      : Colors.white70,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Payment Type Selection
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children:
                      _paymentTypes.map((type) {
                        final isSelected = _selectedPaymentType == type;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(type.toUpperCase()),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedPaymentType = type;
                                    // _generatePrintBill(); // Regenerate bill with new payment type
                                  });
                                }
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
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),

          // Receipt Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: BillReceiptWidget(
                bill: _billData,
                onControllerReady: () {
                  setState(() {
                    _isControllerReady = true;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Printer Status Row
              if (!BillPrinterService.isConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Printer not connected. Connect to print bills.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _navigateToPrinterSetup(),
                        child: Text(
                          'Setup',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Back to Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Print Button
                  if (BillPrinterService.isConnected)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isPrinting || !_isControllerReady)
                                ? null
                                : _printBillAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon:
                            _isPrinting
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.print, size: 18),
                        label: Text(
                          _isPrinting ? 'Printing...' : 'Print',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  if (BillPrinterService.isConnected) const SizedBox(width: 12),

                  // Create Bill Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _createBill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateBillNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmm').format(now);
    return 'LB$dateStr$timeStr';
  }

  void _showPrinterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      BillPrinterService.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          BillPrinterService.isConnected
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        BillPrinterService.isConnected
                            ? 'Printer Connected'
                            : 'Printer Not Connected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              BillPrinterService.isConnected
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (BillPrinterService.selectedAddress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Device: ${BillPrinterService.selectedAddress}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 24),

                if (BillPrinterService.isConnected && _isControllerReady) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testPrint,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Test Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _navigateToPrinterSetup,
                    icon: const Icon(Icons.settings),
                    label: Text(
                      BillPrinterService.isConnected
                          ? 'Printer Settings'
                          : 'Setup Printer',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _testPrint() async {
    try {
      final result = await BillPrinterService.testPrint();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result ? 'Test print successful!' : 'Test print failed',
            ),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context); // Close bottom sheet
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printBillAction() async {
    setState(() => _isPrinting = true);

    try {
      final result = await BillPrinterService.printBill(_billData);

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
      setState(() => _isPrinting = false);
    }
  }

  void _navigateToPrinterSetup() {
    Navigator.pop(context); // Close bottom sheet if open
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterSelectionScreen()),
    ).then((_) {
      // Refresh printer status when returning
      setState(() {});
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
                  'Total: Rs. ${billingProvider.totalAmount.toStringAsFixed(2)}',
                ),
                Text('Payment: ${_selectedPaymentType.toUpperCase()}'),
                const SizedBox(height: 16),
                if (!BillPrinterService.isConnected)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.orange.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bill will be saved without printing',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
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
                  Navigator.pop(context);
                  _processBillCreation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  void _processBillCreation() {
    // TODO: Implement actual bill creation logic
    // This should:
    // 1. Create bill in local database
    // 2. Update stock quantities
    // 3. Sync to Firebase if online
    // 4. Navigate to success screen

    final billingProvider = context.read<BillingProvider>();

    // Clear the bill after creation
    billingProvider.clearBill();

    // Navigate to success screen
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/billing/success',
      (route) => route.settings.name == '/home',
    );
  }
}
