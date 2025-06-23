import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:intl/intl.dart';

class PrinterSelectScreener extends StatefulWidget {
  const PrinterSelectScreener({super.key});

  @override
  State<PrinterSelectScreener> createState() => _PrinterSelectScreenerState();
}

class _PrinterSelectScreenerState extends State<PrinterSelectScreener> {
  ReceiptController? controller;
  String? address;

  final NumberFormat currency = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  final Map<String, dynamic> billData = {
    'storeName': 'LUMORA BIZ STORE',
    'storeAddress': 'Main Street, Negombo, Sri Lanka',
    'phone': '+94 71 234 5678',
    'billNo':
        'LMR${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    'cashier': 'Cashier 01',
  };

  final List<Map<String, dynamic>> items = [
    {'name': 'Kiri Samba Rice 5kg Pack', 'qty': 2, 'price': 850.0},
    {'name': 'Coconut Oil 500ml Bottle', 'qty': 1, 'price': 420.0},
    {'name': 'Ceylon Tea Bags 100pk', 'qty': 3, 'price': 180.0},
    {'name': 'White Sugar 1kg Pack', 'qty': 1, 'price': 220.0},
  ];

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));
  double get tax => subtotal * 0.08;
  double get discount => 50.0;
  double get total => subtotal + tax - discount;

  void _printReceipt() {
    if (controller != null && address != null) {
      controller!
          .print(address: address!)
          .then((result) {
            final msg =
                result ? '✅ Printing successful!' : '❌ Printing failed.';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          })
          .catchError((error) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a printer first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Receipt Page"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final selected = await FlutterBluetoothPrinter.selectDevice(
                context,
              );
              if (selected != null) {
                setState(() {
                  address = selected.address;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (address != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Selected Printer: $address'),
            ),
          Expanded(
            child: Receipt(
              onInitialized: (ctrl) => controller = ctrl,
              builder:
                  (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          billData['storeName'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Center(child: Text(billData['storeAddress'])),
                      Center(child: Text(billData['phone'])),
                      const SizedBox(height: 8),
                      const Divider(thickness: 1),
                      const Text(
                        'BILL DETAILS:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Bill No: ${billData['billNo']}'),
                      Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      ),
                      Text(
                        'Time: ${DateFormat('hh:mm a').format(DateTime.now())}',
                      ),
                      Text('Cashier: ${billData['cashier']}'),
                      const Divider(thickness: 1),
                      const SizedBox(height: 8),
                      const Text(
                        'ITEMS:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Divider(thickness: 1),
                      ...items.map((item) {
                        final totalItem = item['qty'] * item['price'];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${currency.format(item['price'])} x ${item['qty']}',
                                ),
                                Text(currency.format(totalItem)),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                      const Divider(thickness: 1),
                      const Text(
                        'SUMMARY:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(currency.format(subtotal)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tax (8%):'),
                          Text(currency.format(tax)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount:'),
                          Text('-${currency.format(discount)}'),
                        ],
                      ),
                      const Divider(thickness: 2),
                      Center(
                        child: Text(
                          'TOTAL: ${currency.format(total)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Divider(thickness: 1),
                      const SizedBox(height: 10),
                      const Center(child: Text('Thank you for shopping!')),
                      const Center(child: Text('Powered by Lumora Biz')),
                    ],
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _printReceipt,
              icon: const Icon(Icons.print),
              label: const Text("Print Receipt"),
            ),
          ),
        ],
      ),
    );
  }
}
