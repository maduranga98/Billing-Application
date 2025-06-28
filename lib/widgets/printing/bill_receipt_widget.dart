// lib/widgets/printing/bill_receipt_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:intl/intl.dart';
import '../../models/print_bill.dart';
import '../../services/printing/bill_printer_service.dart';

class BillReceiptWidget extends StatefulWidget {
  final PrintBill bill;
  final VoidCallback? onControllerReady;

  const BillReceiptWidget({
    super.key,
    required this.bill,
    this.onControllerReady,
  });

  @override
  State<BillReceiptWidget> createState() => _BillReceiptWidgetState();
}

class _BillReceiptWidgetState extends State<BillReceiptWidget> {
  ReceiptController? controller;

  @override
  Widget build(BuildContext context) {
    return Receipt(
      onInitialized: (ctrl) {
        controller = ctrl;
        BillPrinterService.setController(ctrl);
        widget.onControllerReady?.call();
      },
      builder:
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Header
              Center(
                child: Text(
                  'LUMORA BUSINESS',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Center(child: Text('No. 123, Business Street, Colombo 03')),
              const Center(child: Text('Tel: +94 11 234 5678')),
              const SizedBox(height: 8),
              const Divider(thickness: 1),

              // Invoice Header
              const Text(
                'INVOICE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // Bill Details
              Text('Bill No: ${widget.bill.billNumber}'),
              Text(
                'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.bill.billDate)}',
              ),
              Text('Payment: ${widget.bill.paymentType.toUpperCase()}'),
              const SizedBox(height: 8),

              // Customer Details
              const Text(
                'CUSTOMER DETAILS:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Name: ${widget.bill.customerName}'),
              Text('Outlet: ${widget.bill.outletName}'),
              Text('Address: ${widget.bill.outletAddress}'),
              if (widget.bill.outletPhone.isNotEmpty)
                Text('Phone: ${widget.bill.outletPhone}'),
              const SizedBox(height: 8),

              // Sales Rep Details
              const Text(
                'SALES REPRESENTATIVE:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Name: ${widget.bill.salesRepName}'),
              Text('Phone: ${widget.bill.salesRepPhone}'),
              const SizedBox(height: 8),

              const Divider(thickness: 1),

              // Items Header
              const Text(
                'ITEMS:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(thickness: 1),

              // Items List
              ...widget.bill.items.map((item) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.itemNumber}. ${item.itemName}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (item.itemCode.isNotEmpty)
                      Text(
                        'Code: ${item.itemCode}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${BillPrinterService.currency.format(item.unitPrice)} x ${item.quantity} ${item.unit}',
                        ),
                        Text(
                          BillPrinterService.currency.format(item.totalPrice),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),

              const Divider(thickness: 1),

              // Summary Section
              const Text(
                'SUMMARY:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:'),
                  Text(
                    BillPrinterService.currency.format(widget.bill.totalAmount),
                  ),
                ],
              ),
              if (widget.bill.discountAmount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount:'),
                    Text(
                      '-${BillPrinterService.currency.format(widget.bill.discountAmount)}',
                    ),
                  ],
                ),
              if (widget.bill.taxAmount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tax:'),
                    Text(
                      BillPrinterService.currency.format(widget.bill.taxAmount),
                    ),
                  ],
                ),
              const Divider(thickness: 2),

              // Total
              Center(
                child: Text(
                  'TOTAL: ${BillPrinterService.currency.format(widget.bill.finalAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 16),

              // Signatures
              const Text('Customer Signature: _______________'),
              const SizedBox(height: 16),
              const Text('Sales Rep Signature: _______________'),
              const SizedBox(height: 16),

              // Footer
              const Center(child: Text('Thank you for your business!')),
              Center(
                child: Text(
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Center(child: Text('Powered by Lumora Biz')),
            ],
          ),
    );
  }
}
