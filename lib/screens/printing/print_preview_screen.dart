// lib/screens/printing/print_preview_screen.dart (Updated with Loading Cost Support)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bill.dart';
import '../../models/bill_item.dart';
import '../../models/print_bill.dart';
import '../../services/printing/bill_printer_service.dart';
import 'printer_selection_screen.dart';

class PrintPreviewScreen extends StatefulWidget {
  final Bill bill;
  final List<BillItem> billItems;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String outletName;
  final String outletAddress;
  final String outletPhone;
  final String salesRepName;
  final String salesRepPhone;

  const PrintPreviewScreen({
    super.key,
    required this.bill,
    required this.billItems,
    this.companyName = 'Sajith Rice Mill',
    this.companyAddress = 'Sajith Rice Mill,Nadalagamuwa,Wadumunnegedara',
    this.companyPhone = '(077) 92-58293',
    this.outletName = '',
    this.outletAddress = '',
    this.outletPhone = '',
    this.salesRepName = '',
    this.salesRepPhone = '',
  });

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  bool _isPrinting = false;
  late PrintBill _printBill;

  @override
  void initState() {
    super.initState();
    _initializePrintBill();
    _checkPrinterStatus();
  }

  void _initializePrintBill() {
    // Convert BillItem to PrintBillItem
    final printItems =
        widget.billItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return PrintBillItem(
            itemNumber: index + 1,
            itemName: item.productName,
            itemCode: item.productCode,
            quantity: item.quantity,
            unit: 'pcs', // Default unit, you can customize this
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          );
        }).toList();

    // Create PrintBill from Bill with loading cost support
    _printBill = PrintBill(
      billNumber: widget.bill.billNumber,
      billDate: widget.bill.createdAt,
      outletName: widget.outletName.isNotEmpty ? widget.outletName : 'Customer',
      outletAddress: widget.outletAddress,
      outletPhone: widget.outletPhone,
      customerName:
          widget.outletName.isNotEmpty ? widget.outletName : 'Walk-in Customer',
      salesRepName:
          widget.salesRepName.isNotEmpty ? widget.salesRepName : 'Sales Rep',
      salesRepPhone: widget.salesRepPhone,
      paymentType: widget.bill.paymentType,
      items: printItems,
      subtotalAmount: widget.bill.subtotalAmount, // NEW: Add subtotal
      loadingCost: widget.bill.loadingCost, // NEW: Add loading cost
      totalAmount: widget.bill.totalAmount,
      discountAmount: widget.bill.discountAmount,
      taxAmount: widget.bill.taxAmount,
    );
  }

  Future<void> _checkPrinterStatus() async {
    await BillPrinterService.isDeviceConnected();
    if (mounted) setState(() {});
  }

  Future<void> _printBillReceipt() async {
    if (!BillPrinterService.isConnected) {
      _showPrinterNotConnectedDialog();
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final success = await BillPrinterService.printBill(_printBill);

      if (success) {
        _showSuccessSnackBar('Bill printed successfully!');
        // Optional: Navigate back after successful print
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        _showErrorSnackBar(
          'Failed to print bill. Please check printer connection.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Printing error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<void> _testPrint() async {
    if (!BillPrinterService.isConnected) {
      _showPrinterNotConnectedDialog();
      return;
    }

    try {
      final success = await BillPrinterService.testPrint();
      if (success) {
        _showSuccessSnackBar('Test print successful!');
      } else {
        _showErrorSnackBar('Test print failed');
      }
    } catch (e) {
      _showErrorSnackBar('Test print error: $e');
    }
  }

  void _showPrinterNotConnectedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                const Text('Printer Not Connected'),
              ],
            ),
            content: const Text(
              'Please connect to a thermal printer first to print the bill.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrinterSelectionScreen(),
                    ),
                  ).then((_) => _checkPrinterStatus());
                },
                icon: const Icon(Icons.settings_bluetooth),
                label: const Text('Setup Printer'),
              ),
            ],
          ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Updated calculation to properly use bill's totalAmount
  double get _finalAmount {
    return widget.bill.totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Print Preview',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_bluetooth),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrinterSelectionScreen(),
                ),
              );
              await _checkPrinterStatus();
            },
          ),
          if (BillPrinterService.isConnected)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _testPrint,
              tooltip: 'Test Print',
            ),
        ],
      ),
      body: Column(
        children: [
          // Printer Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color:
                BillPrinterService.isConnected
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
            child: Row(
              children: [
                Icon(
                  BillPrinterService.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color:
                      BillPrinterService.isConnected
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    BillPrinterService.isConnected
                        ? 'Thermal Printer Connected & Ready'
                        : 'No Thermal Printer Connected',
                    style: TextStyle(
                      color:
                          BillPrinterService.isConnected
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (BillPrinterService.isConnected)
                  TextButton.icon(
                    onPressed: _testPrint,
                    icon: Icon(
                      Icons.print,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    label: Text(
                      'Test',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bill Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Header
                    Center(
                      child: Column(
                        children: [
                          Text(
                            widget.companyName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.companyAddress,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Tel: ${widget.companyPhone}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(thickness: 1),

                    // Invoice Header
                    const Center(
                      child: Text(
                        'SALES INVOICE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bill Details
                    _buildDetailRow('Bill No:', widget.bill.billNumber),
                    _buildDetailRow(
                      'Date:',
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(widget.bill.createdAt),
                    ),
                    _buildDetailRow(
                      'Payment:',
                      widget.bill.paymentType.toUpperCase(),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),

                    // Customer Details
                    const Text(
                      'CUSTOMER DETAILS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Customer:',
                      widget.outletName.isNotEmpty
                          ? widget.outletName
                          : 'Walk-in Customer',
                    ),
                    if (widget.outletAddress.isNotEmpty)
                      _buildDetailRow('Address:', widget.outletAddress),
                    if (widget.outletPhone.isNotEmpty)
                      _buildDetailRow('Phone:', widget.outletPhone),

                    const SizedBox(height: 16),

                    // Sales Rep Details
                    if (widget.salesRepName.isNotEmpty) ...[
                      const Text(
                        'SALES REPRESENTATIVE:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Name:', widget.salesRepName),
                      if (widget.salesRepPhone.isNotEmpty)
                        _buildDetailRow('Phone:', widget.salesRepPhone),
                      const SizedBox(height: 16),
                    ],

                    const Divider(),

                    // Items Header
                    const Text(
                      'ITEMS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items List
                    ...widget.billItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${item.productName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.productCode.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Code: ${item.productCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${BillPrinterService.currency.format(item.unitPrice)} x ${item.quantity}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                Text(
                                  BillPrinterService.currency.format(
                                    item.totalPrice,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    const Divider(),

                    // Summary - UPDATED with loading cost support
                    const Text(
                      'SUMMARY:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtotal
                    _buildSummaryRow(
                      'Subtotal:',
                      BillPrinterService.currency.format(
                        widget.bill.subtotalAmount,
                      ),
                    ),

                    // Loading Cost (only show if > 0)
                    if (widget.bill.loadingCost > 0)
                      _buildSummaryRow(
                        'Loading Cost:',
                        BillPrinterService.currency.format(
                          widget.bill.loadingCost,
                        ),
                      ),

                    // Discount (only show if > 0)
                    if (widget.bill.discountAmount > 0)
                      _buildSummaryRow(
                        'Discount:',
                        '-${BillPrinterService.currency.format(widget.bill.discountAmount)}',
                        isNegative: true,
                      ),

                    // Tax (only show if > 0)
                    if (widget.bill.taxAmount > 0)
                      _buildSummaryRow(
                        'Tax:',
                        BillPrinterService.currency.format(
                          widget.bill.taxAmount,
                        ),
                      ),

                    const Divider(thickness: 2),

                    // Total
                    _buildSummaryRow(
                      'TOTAL:',
                      BillPrinterService.currency.format(_finalAmount),
                      isTotal: true,
                    ),

                    const SizedBox(height: 24),

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Thank you for your business!',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Visit us again soon',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Powered by LUMORA BIZ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Back Button
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
                    'Back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Print Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isPrinting ? null : _printBillReceipt,
                  icon:
                      _isPrinting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Icon(
                            BillPrinterService.isConnected
                                ? Icons.print
                                : Icons.print_disabled,
                            color: Colors.white,
                          ),
                  label: Text(
                    _isPrinting
                        ? 'Printing...'
                        : BillPrinterService.isConnected
                        ? 'Print Receipt'
                        : 'Setup Printer First',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        BillPrinterService.isConnected
                            ? Colors.blue.shade600
                            : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isNegative = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color:
                  isNegative
                      ? Colors.red.shade600
                      : isTotal
                      ? Colors.black
                      : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
