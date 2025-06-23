import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class Optimized4InchPrinter extends StatefulWidget {
  const Optimized4InchPrinter({super.key});

  @override
  State<Optimized4InchPrinter> createState() => _Optimized4InchPrinterState();
}

class _Optimized4InchPrinterState extends State<Optimized4InchPrinter> {
  bool isConnected = false;
  bool isScanning = false;
  bool isPrinting = false;
  List<BluetoothInfo> devices = [];
  BluetoothInfo? selectedDevice;

  final NumberFormat currency = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  // Sample bill data
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

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  // Generate line of specific length for 4-inch paper (48 characters width)
  String _generateLine(String char, {int length = 48}) {
    return List.filled(length, char).join();
  }

  // Center text for 4-inch paper
  String _centerText(String text, {int width = 48}) {
    if (text.length >= width) return text.substring(0, width);
    int padding = (width - text.length) ~/ 2;
    return (' ' * padding) + text + (' ' * padding);
  }

  // Left-right alignment for 4-inch paper
  String _leftRightAlign(String left, String right, {int width = 48}) {
    int spacing = width - left.length - right.length;
    if (spacing < 1) spacing = 1;
    return left + (' ' * spacing) + right;
  }

  Future<void> _printBill() async {
    if (!isConnected) {
      _showMessage('Please connect to printer first', isError: true);
      return;
    }

    setState(() {
      isPrinting = true;
    });

    try {
      // Initialize printer
      await PrintBluetoothThermal.writeBytes('\x1B\x40'.codeUnits);
      await Future.delayed(const Duration(milliseconds: 200));

      // Store Header - Large and centered
      await _printLine('', size: 1);
      await _printLine(_centerText(billData['storeName']), size: 2);
      await _printLine(_centerText(billData['storeAddress']), size: 1);
      await _printLine(_centerText(billData['phone']), size: 1);
      await _printLine('', size: 1);
      await _printLine(_generateLine('='), size: 1);

      // Bill Information
      await _printLine('', size: 1);
      await _printLine('BILL DETAILS:', size: 1);
      await _printLine(
        _leftRightAlign('Bill No:', billData['billNo']),
        size: 1,
      );
      await _printLine(
        _leftRightAlign(
          'Date:',
          DateFormat('dd/MM/yyyy').format(DateTime.now()),
        ),
        size: 1,
      );
      await _printLine(
        _leftRightAlign('Time:', DateFormat('hh:mm a').format(DateTime.now())),
        size: 1,
      );
      await _printLine(
        _leftRightAlign('Cashier:', billData['cashier']),
        size: 1,
      );
      await _printLine('', size: 1);
      await _printLine(_generateLine('-'), size: 1);

      // Items Header
      await _printLine('', size: 1);
      await _printLine('ITEMS:', size: 1);
      await _printLine(_generateLine('-'), size: 1);

      // Print each item with proper spacing
      for (int i = 0; i < items.length; i++) {
        var item = items[i];
        double itemTotal = item['price'] * item['qty'];

        // Item number and name
        await _printLine('${i + 1}. ${item['name']}', size: 1);

        // Price details
        String priceInfo = '${currency.format(item['price'])} x ${item['qty']}';
        String totalInfo = currency.format(itemTotal);
        await _printLine(_leftRightAlign(priceInfo, totalInfo), size: 1);

        // Add space between items
        await _printLine('', size: 1);
      }

      // Summary section
      await _printLine(_generateLine('-'), size: 1);
      await _printLine('SUMMARY:', size: 1);
      await _printLine(_generateLine('-'), size: 1);

      await _printLine(
        _leftRightAlign('Subtotal:', currency.format(subtotal)),
        size: 1,
      );
      await _printLine(
        _leftRightAlign('Tax (8%):', currency.format(tax)),
        size: 1,
      );
      await _printLine(
        _leftRightAlign('Discount:', '-${currency.format(discount)}'),
        size: 1,
      );

      await _printLine(_generateLine('='), size: 1);

      // Total - Large and prominent
      await _printLine('', size: 1);
      await _printLine(_centerText('TOTAL AMOUNT'), size: 1);
      await _printLine(_centerText(currency.format(total)), size: 3);
      await _printLine('', size: 1);
      await _printLine(_generateLine('='), size: 1);

      // Footer
      await _printLine('', size: 1);
      await _printLine(_centerText('Thank you for shopping!'), size: 1);
      await _printLine(_centerText('Please visit again'), size: 1);
      await _printLine('', size: 1);
      await _printLine(_centerText('Powered by Lumora Biz'), size: 1);

      // Add extra spacing before cut
      await _printLine('', size: 1);
      await _printLine('', size: 1);
      await _printLine('', size: 1);

      // Cut paper
      await PrintBluetoothThermal.writeBytes('\x1D\x56\x42\x00'.codeUnits);

      _showMessage('✅ Bill printed successfully!');
    } catch (e) {
      _showMessage('❌ Print failed: $e', isError: true);
    } finally {
      setState(() {
        isPrinting = false;
      });
    }
  }

  Future<void> _printLine(String text, {int size = 1}) async {
    await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: size, text: text),
    );
    await PrintBluetoothThermal.writeBytes('\n'.codeUnits);
    // Small delay for better printing
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _scanDevices() async {
    setState(() {
      isScanning = true;
    });

    try {
      final bool bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!bluetoothOn) {
        _showMessage('Please enable Bluetooth first', isError: true);
        return;
      }

      final List<BluetoothInfo> pairedDevices =
          await PrintBluetoothThermal.pairedBluetooths;
      setState(() {
        devices =
            pairedDevices.where((device) => device.name.isNotEmpty).toList();
      });
    } catch (e) {
      _showMessage('Scan failed: $e', isError: true);
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> _connectDevice(BluetoothInfo device) async {
    try {
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );
      setState(() {
        selectedDevice = device;
        isConnected = result;
      });

      _showMessage(
        result ? '✅ Connected to ${device.name}' : '❌ Failed to connect',
      );
    } catch (e) {
      _showMessage('Connection error: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('4-inch Thermal Printer'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            ),
            onPressed: _showDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected ? Colors.green[200]! : Colors.orange[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.info,
                  color: isConnected ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected
                            ? '4-inch Printer Connected'
                            : 'No Printer Connected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isConnected
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                        ),
                      ),
                      if (selectedDevice != null)
                        Text(
                          selectedDevice!.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bill Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
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
                      Icon(Icons.receipt, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text(
                        'Bill Preview (4-inch width)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          billData['storeName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          billData['storeAddress'],
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          List.filled(48, '=').join(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        ...items.map((item) {
                          double itemTotal = item['price'] * item['qty'];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${currency.format(item['price'])} x ${item['qty']}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      currency.format(itemTotal),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        Text(
                          List.filled(48, '=').join(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TOTAL: ${currency.format(total)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Print Button
          Container(
            margin: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    isPrinting
                        ? null
                        : (isConnected ? _printBill : _showDevices),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isConnected ? Colors.blue[600] : Colors.orange[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon:
                    isPrinting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Icon(
                          isConnected ? Icons.print : Icons.bluetooth,
                          color: Colors.white,
                        ),
                label: Text(
                  isPrinting
                      ? 'Printing on 4-inch paper...'
                      : (isConnected
                          ? 'Print on 4-inch Paper'
                          : 'Connect Printer'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDevices() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            height: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '4-inch Thermal Printers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: isScanning ? null : _scanDevices,
                      icon:
                          isScanning
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.refresh),
                      label: Text(isScanning ? 'Scanning...' : 'Scan'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child:
                      devices.isEmpty
                          ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.print, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No devices found'),
                                SizedBox(height: 8),
                                Text(
                                  'Make sure your 4-inch thermal printer is:\n• Paired in Bluetooth settings\n• Turned on',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              final isSelected =
                                  selectedDevice?.macAdress == device.macAdress;

                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.print,
                                    color:
                                        isSelected ? Colors.green : Colors.blue,
                                  ),
                                  title: Text(
                                    device.name,
                                    style: TextStyle(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${device.macAdress}\n4-inch paper compatible',
                                  ),
                                  trailing:
                                      isSelected
                                          ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                          : const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                          ),
                                  onTap: () {
                                    _connectDevice(device);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }
}
