import 'dart:async';
import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../../models/print_bill.dart';

class BillPrinterService {
  static BluetoothInfo? _selectedDevice;
  static bool _isConnected = false;
  static CapabilityProfile? _profile;
  static Generator? _generator;

  // Updated to 64 character width
  static const int RECEIPT_WIDTH = 64;

  // Get current connected device
  static BluetoothInfo? get selectedDevice => _selectedDevice;
  static bool get isConnected => _isConnected;

  // Currency formatter
  static final NumberFormat currency = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  // Initialize printer profile and generator
  static Future<void> _initializePrinter({
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      // Load capability profile for better printer support
      _profile = await CapabilityProfile.load();

      // For 4-inch (103mm) paper, use mm80 as base but adjust layout
      _generator = Generator(paperSize, _profile!);
      print('Printer initialized with ${paperSize.toString()} paper size');
    } catch (e) {
      print('Error initializing printer: $e');
      // Fallback to default profile
      _profile = await CapabilityProfile.load();
      _generator = Generator(PaperSize.mm80, _profile!);
    }
  }

  // Check if Bluetooth is available and enabled
  static Future<bool> isBluetoothAvailable() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      print('Error checking Bluetooth availability: $e');
      return false;
    }
  }

  // Scan for available devices
  static Future<List<BluetoothInfo>> scanDevices() async {
    try {
      print('Checking Bluetooth availability...');
      final bluetoothEnabled = await isBluetoothAvailable();
      if (!bluetoothEnabled) {
        throw Exception('Bluetooth is not enabled');
      }

      print('Starting device scan...');
      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;

      print('Found ${devices.length} paired devices');
      for (final device in devices) {
        print('Device: ${device.name} (${device.macAdress})');
      }

      return devices;
    } catch (e) {
      print('Error scanning devices: $e');
      return [];
    }
  }

  // Connect to a specific device
  static Future<bool> connectToDevice(
    BluetoothInfo device, {
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      print('Attempting to connect to ${device.name} (${device.macAdress})');

      // Initialize printer first
      await _initializePrinter(paperSize: paperSize);

      // Check if already connected
      final currentStatus = await PrintBluetoothThermal.connectionStatus;
      if (currentStatus) {
        print('Already connected, disconnecting first...');
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(seconds: 1));
      }

      // Attempt connection
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );

      if (result) {
        _selectedDevice = device;
        _isConnected = true;
        print('Successfully connected to ${device.name}');

        // Verify connection
        await Future.delayed(const Duration(milliseconds: 500));
        final verifyStatus = await PrintBluetoothThermal.connectionStatus;
        if (verifyStatus) {
          print('Connection verified successfully');
          return true;
        } else {
          print('Connection verification failed');
          _isConnected = false;
          _selectedDevice = null;
          return false;
        }
      } else {
        print('Failed to connect to ${device.name}');
        return false;
      }
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  // Disconnect from current device
  static Future<void> disconnect() async {
    try {
      print('Disconnecting from printer...');

      final currentStatus = await PrintBluetoothThermal.connectionStatus;
      if (currentStatus) {
        await PrintBluetoothThermal.disconnect;
        print('Disconnection command sent');
      }
    } catch (e) {
      print('Error during disconnection: $e');
    } finally {
      _selectedDevice = null;
      _isConnected = false;
      _generator = null;
      _profile = null;
      print('Printer state cleared');
    }
  }

  // Check if device is connected
  static Future<bool> isDeviceConnected() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;

      // Update internal state if it's out of sync
      if (_isConnected != status) {
        _isConnected = status;
        if (!status) {
          _selectedDevice = null;
          _generator = null;
          _profile = null;
        }
      }

      return status;
    } catch (e) {
      print('Error checking connection: $e');
      return false;
    }
  }

  // Print bill receipt - main method using esc_pos_utils_plus
  static Future<bool> printBill(
    PrintBill bill, {
    PaperSize paperSize = PaperSize.mm80,
  }) async {
    try {
      // Check connection
      final connected = await isDeviceConnected();
      if (!connected) {
        throw Exception('Printer not connected');
      }

      // Ensure generator is initialized
      if (_generator == null) {
        await _initializePrinter(paperSize: paperSize);
      }

      print('Generating optimized receipt for bill ${bill.billNumber}');

      // Generate receipt using esc_pos_utils_plus
      final List<int> bytes = _generateOptimizedReceipt(bill);

      // Print the receipt
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        print('Optimized bill printed successfully');
        return true;
      } else {
        print('Print failed');
        return false;
      }
    } catch (e) {
      print('Error printing bill: $e');
      return false;
    }
  }

  // UPDATED: Generate optimized bill with loading cost support
  static List<int> _generateOptimizedReceipt(PrintBill bill) {
    List<int> bytes = [];

    // Paper specifications:
    // Total paper width: 68 characters
    // Left margin: 2 characters
    // Right margin: 2 characters
    // Content width: 64 characters
    const int totalPaperWidth = 68;
    const int leftMargin = 2;
    const int rightMargin = 2;
    const int contentWidth =
        totalPaperWidth - leftMargin - rightMargin; // 64 chars

    // Separators for different sections
    final String mainSeparator = '=' * contentWidth; // 64 chars
    final String lightSeparator = '-' * contentWidth; // 64 chars
    final String dottedSeparator = '.' * contentWidth; // 64 chars

    // Helper function to add left margin
    String addMargin(String text) {
      return ' ' * leftMargin + text;
    }

    // Helper function for centered text with margins
    String centerWithMargin(String text) {
      if (text.length >= contentWidth) {
        return addMargin(text.substring(0, contentWidth));
      }

      int padding = (contentWidth - text.length) ~/ 2;
      String centeredText =
          ' ' * padding + text + ' ' * (contentWidth - text.length - padding);
      return addMargin(centeredText);
    }

    // Top spacing
    bytes += _generator!.feed(1);

    // === HEADER SECTION ===
    bytes += _generator!.text(
      centerWithMargin('Sajith Rice Mill'),
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    );

    bytes += _generator!.text(
      centerWithMargin('Sajith Rice Mill,Nadalagamuwa,Wadumunnegedara'),
    );

    bytes += _generator!.text(centerWithMargin('Tel: (077) 92-58293'));

    bytes += _generator!.text(addMargin(mainSeparator));
    bytes += _generator!.feed(1);

    // === BILL INFORMATION IN ONE ROW ===
    String billInfo =
        'Bill: LB${bill.billNumber}'.padRight(32) +
        '${DateFormat('dd/MM/yyyy HH:mm').format(bill.billDate)}';
    bytes += _generator!.text(
      addMargin(billInfo),
      styles: const PosStyles(bold: true),
    );

    bytes += _generator!.feed(1);

    // === CUSTOMER AND SALES REP INFORMATION IN ROWS ===
    // Row 1: Customer Name and Sales Rep Name
    String customerName = _truncateText(bill.customerName, 30);
    String repName = _truncateText(bill.salesRepName, 30);
    String row1 = 'Customer: $customerName'.padRight(32) + 'Rep: $repName';
    bytes += _generator!.text(addMargin(row1));

    // Row 2: Customer Address and Rep Phone (if available)
    if (bill.outletAddress.isNotEmpty || bill.salesRepPhone.isNotEmpty) {
      String customerAddress =
          bill.outletAddress.isNotEmpty
              ? _truncateText(bill.outletAddress, 28)
              : '';
      String repPhone = bill.salesRepPhone.isNotEmpty ? bill.salesRepPhone : '';

      String addressLabel =
          customerAddress.isNotEmpty ? 'Address: $customerAddress' : '';
      String phoneLabel = repPhone.isNotEmpty ? 'Phone: $repPhone' : '';

      String row2 = addressLabel.padRight(32) + phoneLabel;
      if (addressLabel.isNotEmpty || phoneLabel.isNotEmpty) {
        bytes += _generator!.text(addMargin(row2));
      }
    }

    // Row 3: Customer Phone (if available)
    if (bill.outletPhone.isNotEmpty) {
      String row3 = 'Phone: ${bill.outletPhone}';
      bytes += _generator!.text(addMargin(row3));
    }

    bytes += _generator!.text(addMargin(mainSeparator));
    bytes += _generator!.feed(1);

    // === ITEMS TABLE ===
    // Table layout for 64-character content width:
    // Item Name: 32 chars | Price: 10 chars | Qty: 6 chars | Total: 10 chars = 58 chars
    // Remaining 6 chars for spacing between columns

    // Table header
    String headerRow =
        'Item Name'.padRight(32) +
        'Price'.padLeft(10) +
        'Qty'.padLeft(8) +
        'Total'.padLeft(10);

    bytes += _generator!.text(
      addMargin(headerRow),
      styles: const PosStyles(bold: true, underline: true),
    );

    bytes += _generator!.text(addMargin(lightSeparator));

    // Items
    for (int i = 0; i < bill.items.length; i++) {
      final item = bill.items[i];

      // Format item name with item number
      String itemDisplayName = '${i + 1}. ${item.itemName}';
      String truncatedName = _truncateText(itemDisplayName, 32).padRight(32);

      String itemRow =
          truncatedName +
          item.unitPrice.toStringAsFixed(2).padLeft(10) +
          item.quantity.toString().padLeft(8) +
          item.totalPrice.toStringAsFixed(2).padLeft(10);

      bytes += _generator!.text(addMargin(itemRow));
    }

    bytes += _generator!.text(addMargin(lightSeparator));
    bytes += _generator!.feed(1);

    // === TOTALS SECTION WITH LOADING COST ===
    // Calculate subtotal (items only)
    double itemsSubtotal = bill.subtotalAmount;

    // Right-aligned totals (reduced by 4 characters from the right edge)
    const int totalsWidth = contentWidth - 4; // 64 - 4 = 60 characters

    String subtotalLine =
        'Items Subtotal: Rs. ${itemsSubtotal.toStringAsFixed(2)}';
    bytes += _generator!.text(addMargin(subtotalLine.padLeft(totalsWidth)));

    // ADDED: Loading cost line (if > 0)
    if (bill.loadingCost > 0) {
      String loadingLine =
          'Loading Cost: Rs. ${bill.loadingCost.toStringAsFixed(2)}';
      bytes += _generator!.text(
        addMargin(loadingLine.padLeft(totalsWidth)),
        styles: const PosStyles(bold: true), // Make loading cost bold
      );
    }

    // Discount (if applicable)
    if (bill.discountAmount > 0) {
      String discountLine =
          'Discount: Rs. -${bill.discountAmount.toStringAsFixed(2)}';
      bytes += _generator!.text(addMargin(discountLine.padLeft(totalsWidth)));
    }

    // Tax (if applicable)
    if (bill.taxAmount > 0) {
      String taxLine = 'Tax: Rs. ${bill.taxAmount.toStringAsFixed(2)}';
      bytes += _generator!.text(addMargin(taxLine.padLeft(totalsWidth)));
    }

    bytes += _generator!.text(addMargin(lightSeparator));

    // Grand total with emphasis (includes loading cost)
    String totalLine = 'TOTAL: Rs. ${bill.totalAmount.toStringAsFixed(2)}';
    bytes += _generator!.text(
      addMargin(totalLine.padLeft(totalsWidth)),
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    );

    bytes += _generator!.text(addMargin(mainSeparator));
    bytes += _generator!.feed(1);

    // === PAYMENT INFORMATION ===
    bytes += _generator!.text(
      addMargin('Payment Method: ${bill.paymentType.toUpperCase()}'),
      styles: const PosStyles(bold: true),
    );

    bytes += _generator!.feed(2);

    // === THANK YOU MESSAGE (Above dotted line) ===
    bytes += _generator!.text(
      centerWithMargin('Thank you for your business!'),
      styles: const PosStyles(bold: true),
    );

    bytes += _generator!.feed(2);

    // === SIGNATURE SECTION (Above dotted line) ===
    String signatureLine = '${'_' * 30}    ${'_' * 30}';
    bytes += _generator!.text(addMargin(signatureLine));
    bytes += _generator!.feed(1);

    // Signature labels
    String signatureLabels =
        'Customer Signature'.padRight(32) + 'Sales Rep Signature';
    bytes += _generator!.text(addMargin(signatureLabels));
    bytes += _generator!.feed(1);

    // === DOTTED SEPARATOR ===
    bytes += _generator!.text(addMargin(dottedSeparator));
    bytes += _generator!.feed(1);

    // === SOLUTION BY SECTION (Below dotted line) ===
    bytes += _generator!.text(
      centerWithMargin('Solution by Lumora Ventures Pvt Ltd'),
    );

    bytes += _generator!.text(centerWithMargin('Mobile: +94 76 620 6555'));

    // Bottom spacing and cut
    bytes += _generator!.feed(2);
    bytes += _generator!.cut();

    return bytes;
  }

  // Update the PAPER_CONFIGS to include your specific configuration
  static const Map<String, Map<String, dynamic>> PAPER_CONFIGS = {
    '58mm': {
      'width': 32,
      'description': '2.3" thermal paper',
      'paperSize': PaperSize.mm58,
    },
    '80mm': {
      'width': 42,
      'description': '3.1" thermal paper',
      'paperSize': PaperSize.mm80,
    },
    '104mm (68 chars)': {
      'width': 68,
      'description': '4.1" thermal paper - 68 total, 64 content',
      'paperSize': PaperSize.mm80,
    },
    '112mm': {
      'width': 64,
      'description': '4.4" thermal paper',
      'paperSize': PaperSize.mm80,
    },
  };

  // Test print functionality using esc_pos_utils_plus
  static Future<bool> testPrint({PaperSize paperSize = PaperSize.mm80}) async {
    try {
      // Check connection
      final connected = await isDeviceConnected();
      if (!connected) {
        throw Exception('Printer not connected');
      }

      // Ensure generator is initialized
      if (_generator == null) {
        await _initializePrinter(paperSize: paperSize);
      }

      print('Performing test print');

      // Generate test receipt using esc_pos_utils_plus
      final List<int> bytes = _generateTestReceipt();

      final bool result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        print('Test print successful');
        return true;
      } else {
        print('Test print failed');
        return false;
      }
    } catch (e) {
      print('Error in test print: $e');
      return false;
    }
  }

  // Generate test receipt using esc_pos_utils_plus - optimized for 64 chars
  static List<int> _generateTestReceipt() {
    if (_generator == null) {
      throw Exception('Generator not initialized');
    }

    List<int> bytes = [];

    // Create a 64-character line for testing
    final String testLine = '=' * RECEIPT_WIDTH;
    bytes += _generator!.text(
      testLine,
      styles: const PosStyles(align: PosAlign.left),
    );

    bytes += _generator!.text(
      'TEST PRINT - 64 CHARACTER WIDTH',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += _generator!.text(
      'Lumora Business',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += _generator!.text(
      'Printer Test',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += _generator!.text(
      testLine,
      styles: const PosStyles(align: PosAlign.left),
    );

    bytes += _generator!.text(
      DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += _generator!.feed(1);

    // Test character width display
    bytes += _generator!.text(
      '123456789012345678901234567890123456789012345678901234567890123456789',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += _generator!.text(
      '         1         2         3         4         5         6    ',
      styles: const PosStyles(align: PosAlign.left),
    );

    bytes += _generator!.feed(1);

    // Test different styles
    bytes += _generator!.text('Bold text', styles: const PosStyles(bold: true));
    bytes += _generator!.text(
      'Underlined text',
      styles: const PosStyles(underline: true),
    );
    bytes += _generator!.text(
      'Reverse text',
      styles: const PosStyles(reverse: true),
    );

    bytes += _generator!.feed(1);

    // Test alignment
    bytes += _generator!.text(
      'Left aligned',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += _generator!.text(
      'Center aligned',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += _generator!.text(
      'Right aligned',
      styles: const PosStyles(align: PosAlign.right),
    );

    bytes += _generator!.feed(1);

    // Test table with 64-char width
    bytes += _generator!.row([
      PosColumn(
        text: 'Column 1',
        width: 4,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'Column 2',
        width: 4,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'Column 3',
        width: 4,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
    ]);

    bytes += _generator!.row([
      PosColumn(text: 'Test Data 1', width: 4),
      PosColumn(text: 'Test Data 2', width: 4),
      PosColumn(text: 'Test Data 3', width: 4),
    ]);

    bytes += _generator!.feed(1);

    bytes += _generator!.text(
      'If you can read this clearly,',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += _generator!.text(
      'your 64-character width printer is working perfectly!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += _generator!.text(
      testLine,
      styles: const PosStyles(align: PosAlign.left),
    );

    bytes += _generator!.feed(3);
    bytes += _generator!.cut();

    return bytes;
  }

  // Helper method to truncate text safely
  static String _truncateText(
    String text,
    int maxLength, {
    String suffix = '...',
  }) {
    if (maxLength <= 0) return '';
    if (text.length <= maxLength) return text;
    if (maxLength <= suffix.length) return text.substring(0, maxLength);
    return '${text.substring(0, maxLength - suffix.length)}$suffix';
  }

  // Get available paper sizes - updated for 4-inch support
  static List<PaperSize> getAvailablePaperSizes() {
    return [
      PaperSize.mm58, // 2.3 inches
      PaperSize.mm80, // 3.1 inches (close to your 4-inch, use this)
    ];
  }

  // Get paper size name with 4-inch info
  static String getPaperSizeName(PaperSize paperSize) {
    switch (paperSize) {
      case PaperSize.mm58:
        return '58mm (2.3")';
      case PaperSize.mm80:
        return '80mm (3.1") - Use for 4" paper (64 chars)';
      default:
        return '80mm (3.1") - Use for 4" paper (64 chars)';
    }
  }

  // Get printer status with enhanced information
  static Future<Map<String, dynamic>> getPrinterStatus() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      final bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;

      return {
        'isConnected': _isConnected,
        'deviceName': _selectedDevice?.name ?? 'None',
        'deviceAddress': _selectedDevice?.macAdress ?? 'None',
        'connectionStatus': status,
        'bluetoothEnabled': bluetoothEnabled,
        'generatorInitialized': _generator != null,
        'profileLoaded': _profile != null,
        'receiptWidth': RECEIPT_WIDTH,
        'lastUpdate': DateTime.now().toString(),
      };
    } catch (e) {
      return {
        'isConnected': false,
        'error': e.toString(),
        'generatorInitialized': false,
        'profileLoaded': false,
        'receiptWidth': RECEIPT_WIDTH,
      };
    }
  }

  // Check if ready to print
  static bool isReadyToPrint() {
    return _isConnected && _selectedDevice != null && _generator != null;
  }

  // Print raw bytes (for advanced users)
  static Future<bool> printRawBytes(List<int> bytes) async {
    if (!_isConnected || _selectedDevice == null) {
      throw Exception('Printer not connected');
    }

    try {
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      print('Error printing raw bytes: $e');
      return false;
    }
  }

  // Print custom formatted text using esc_pos_utils_plus
  static Future<bool> printCustomText(
    String text, {
    PosAlign align = PosAlign.left,
    bool bold = false,
    bool underline = false,
    bool reverse = false,
    PosTextSize height = PosTextSize.size1,
    PosTextSize width = PosTextSize.size1,
  }) async {
    if (!isReadyToPrint()) {
      throw Exception('Printer not ready');
    }

    try {
      List<int> bytes = [];
      bytes += _generator!.text(
        text,
        styles: PosStyles(
          align: align,
          bold: bold,
          underline: underline,
          reverse: reverse,
          height: height,
          width: width,
        ),
      );
      bytes += _generator!.feed(1);

      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      print('Error printing custom text: $e');
      return false;
    }
  }

  // Get receipt width for external reference
  static int getReceiptWidth() {
    return RECEIPT_WIDTH;
  }
}
