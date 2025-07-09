import 'dart:async';
import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';
import '../../models/print_bill.dart';

class BillPrinterService {
  static BluetoothInfo? _selectedDevice;
  static bool _isConnected = false;

  // Get current connected device
  static BluetoothInfo? get selectedDevice => _selectedDevice;
  static bool get isConnected => _isConnected;

  // Currency formatter
  static final NumberFormat currency = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

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
  static Future<bool> connectToDevice(BluetoothInfo device) async {
    try {
      print('Attempting to connect to ${device.name} (${device.macAdress})');

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
        }
      }

      return status;
    } catch (e) {
      print('Error checking connection: $e');
      return false;
    }
  }

  // Print bill receipt - main method
  static Future<bool> printBill(PrintBill bill) async {
    return await printBillFormatted(bill);
  }

  // Print bill with ESC/POS commands for better formatting
  static Future<bool> printBillFormatted(PrintBill bill) async {
    try {
      // Check connection
      final connected = await isDeviceConnected();
      if (!connected) {
        throw Exception('Printer not connected');
      }

      print('Generating formatted receipt for bill ${bill.billNumber}');

      // Generate receipt using ESC/POS commands
      final List<int> bytes = _generateReceiptBytes(bill);

      // Print the receipt
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        print('Formatted bill printed successfully');
        return true;
      } else {
        print('Formatted print failed');
        return false;
      }
    } catch (e) {
      print('Error printing formatted bill: $e');
      return false;
    }
  }

  // Print bill using text format (fallback)
  static Future<bool> printBillText(PrintBill bill) async {
    try {
      // Check connection
      final connected = await isDeviceConnected();
      if (!connected) {
        throw Exception('Printer not connected');
      }

      print('Generating text receipt for bill ${bill.billNumber}');

      // Generate receipt using formatted text
      final String receiptText = _generateReceiptText(bill);

      // Convert string to bytes and print
      final List<int> bytes = receiptText.codeUnits;
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        print('Text bill printed successfully');
        return true;
      } else {
        print('Text print failed');
        return false;
      }
    } catch (e) {
      print('Error printing text bill: $e');
      return false;
    }
  }

  // Test print functionality
  static Future<bool> testPrint() async {
    try {
      // Check connection
      final connected = await isDeviceConnected();
      if (!connected) {
        throw Exception('Printer not connected');
      }

      print('Performing test print');

      // Generate test receipt
      final String testText = _generateTestReceipt();

      // Convert string to bytes and print
      final List<int> bytes = testText.codeUnits;
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

  // Generate simple text receipt
  static String _generateReceiptText(PrintBill bill) {
    final StringBuffer receipt = StringBuffer();
    const int paperWidth = 48; // 104mm paper width in characters
    const String margin = '    '; // 4-space margin for left and right

    // Company Header - Centered
    receipt.writeln('$margin${'=' * (paperWidth - 8)}');
    receipt.writeln('$margin${_centerText('LUMORA BUSINESS', paperWidth - 8)}');
    receipt.writeln(
      '$margin${_centerText('No. 123, Main Street', paperWidth - 8)}',
    );
    receipt.writeln(
      '$margin${_centerText('Colombo, Sri Lanka', paperWidth - 8)}',
    );
    receipt.writeln(
      '$margin${_centerText('Tel: +94 11 123 4567', paperWidth - 8)}',
    );
    receipt.writeln('$margin${'=' * (paperWidth - 8)}');
    receipt.writeln();

    // Bill details
    receipt.writeln('${margin}Bill No: ${bill.billNumber}');
    receipt.writeln(
      '${margin}Date: ${DateFormat('dd/MM/yyyy').format(bill.billDate)}',
    );
    receipt.writeln(
      '${margin}Time: ${DateFormat('HH:mm:ss').format(bill.billDate)}',
    );
    receipt.writeln();
    receipt.writeln();

    // Customer and Sales Rep details in side-by-side format with more space
    String customerName =
        bill.customerName.length > 20
            ? '${bill.customerName.substring(0, 17)}...'
            : bill.customerName.padRight(20);
    String repName =
        bill.salesRepName.length > 20
            ? '${bill.salesRepName.substring(0, 17)}...'
            : bill.salesRepName.padRight(20);

    receipt.writeln(
      '$margin${'Customer:'.padRight(10)}$customerName  ${'Rep:'.padRight(6)}$repName',
    );

    if (bill.outletAddress.isNotEmpty || bill.salesRepPhone.isNotEmpty) {
      String address =
          bill.outletAddress.length > 20
              ? '${bill.outletAddress.substring(0, 17)}...'
              : bill.outletAddress.padRight(20);
      String repPhone =
          bill.salesRepPhone.length > 20
              ? '${bill.salesRepPhone.substring(0, 17)}...'
              : bill.salesRepPhone.padRight(20);

      receipt.writeln(
        '$margin${'Address:'.padRight(10)}$address  ${'Phone:'.padRight(6)}$repPhone',
      );
    }

    if (bill.outletPhone.isNotEmpty) {
      receipt.writeln('$margin${'Phone:'.padRight(10)}${bill.outletPhone}');
    }
    receipt.writeln();
    receipt.writeln();
    receipt.writeln();

    receipt.writeln('$margin${'-' * (paperWidth - 8)}');

    // FIXED TABLE HEADER - Total width = 40 chars (3+18+8+4+7)
    receipt.writeln(
      '$margin${'#'.padRight(3)}${'Item Name'.padRight(18)}${'Price'.padLeft(8)}${'Qty'.padLeft(4)}${'Total'.padLeft(7)}',
    );
    receipt.writeln('$margin${'-' * (paperWidth - 8)}');

    // FIXED ITEMS - Consistent spacing and alignment
    for (final item in bill.items) {
      String itemName =
          item.itemName.length > 17
              ? '${item.itemName.substring(0, 15)}...'
              : item.itemName.padRight(18); // Fixed: should be 18, not 17

      String itemNumber = item.itemNumber.toString().padRight(3);
      String price = item.unitPrice.toStringAsFixed(2).padLeft(8);
      String quantity = item.quantity.toString().padLeft(4);
      String total = item.totalPrice.toStringAsFixed(2).padLeft(7);

      receipt.writeln('$margin$itemNumber$itemName$price$quantity$total');
    }

    receipt.writeln('$margin${'-' * (paperWidth - 8)}');

    // FIXED TOTALS - Proper alignment with table width
    const int totalSectionWidth = 40; // Same as table width (3+18+8+4+7)

    if (bill.discountAmount > 0) {
      receipt.writeln(
        '$margin${'Subtotal:'.padLeft(totalSectionWidth - 8)}${(bill.totalAmount + bill.discountAmount).toStringAsFixed(2).padLeft(8)}',
      );
      receipt.writeln(
        '$margin${'Discount:'.padLeft(totalSectionWidth - 8)}${'-${bill.discountAmount.toStringAsFixed(2)}'.padLeft(8)}',
      );
    }

    if (bill.taxAmount > 0) {
      receipt.writeln(
        '$margin${'Tax:'.padLeft(totalSectionWidth - 8)}${bill.taxAmount.toStringAsFixed(2).padLeft(8)}',
      );
    }

    receipt.writeln(
      '$margin${'TOTAL:'.padLeft(totalSectionWidth - 11)}${'Rs.${bill.finalAmount.toStringAsFixed(2)}'.padLeft(11)}',
    );
    receipt.writeln('$margin${'-' * (paperWidth - 8)}');
    receipt.writeln();
    receipt.writeln();

    // Signature section - side by side format
    receipt.writeln(
      '$margin${'Customer Signature:'.padRight(25)}${'Sales Rep Signature:'.padRight(19)}',
    );
    receipt.writeln(
      '$margin${'___________________'.padRight(25)}${'___________________'.padRight(19)}',
    );
    receipt.writeln();
    receipt.writeln();

    // Thank you message
    receipt.writeln(
      '$margin${_centerText('Thank you for your business!', paperWidth - 8)}',
    );
    receipt.writeln();
    receipt.writeln('$margin${'-' * (paperWidth - 8)}');

    // Solution by section
    receipt.writeln('$margin${_centerText('Solution by', paperWidth - 8)}');
    receipt.writeln(
      '$margin${_centerText('Lumora Ventures Pvt Ltd', paperWidth - 8)}',
    );
    receipt.writeln(
      '$margin${_centerText('Mobile: +94 76 620 6555', paperWidth - 8)}',
    );
    receipt.writeln();
    receipt.writeln();
    receipt.writeln();

    return receipt.toString();
  }

  // Helper method to center text
  static String _centerText(String text, int width) {
    if (text.length >= width) return text;
    int padding = (width - text.length) ~/ 2;
    return '${' ' * padding}$text${' ' * (width - text.length - padding)}';
  }

  // FIXED ESC/POS formatted receipt with corrected table
  static List<int> _generateReceiptBytes(PrintBill bill) {
    List<int> bytes = [];

    // Margin configuration
    const int paperWidthChars = 80; // Paper width
    const int leftMarginChars = 3;
    const int rightMarginChars = 3;
    const int contentWidth =
        paperWidthChars - leftMarginChars - rightMarginChars;

    // Convert margins to dots (8 dots per character for most thermal printers)
    const int leftMarginDots = leftMarginChars * 8;

    // Create margin strings for text-based approach
    final String leftMarginText = ' ' * leftMarginChars;

    // ESC/POS commands
    const ESC = 0x1B;
    const GS = 0x1D;

    // Initialize printer
    bytes.addAll([ESC, 0x40]);

    // Method 1: Try ESC/POS margin commands
    bytes.addAll([ESC, 0x6C, leftMarginDots]); // Set left margin

    // Method 2: Set print area width (creates right margin effect)
    final int printAreaDots = contentWidth * 8;
    bytes.addAll([GS, 0x57, printAreaDots & 0xFF, (printAreaDots >> 8) & 0xFF]);

    // Helper function to add text margins manually (fallback)
    List<int> addTextMargin(String text) {
      return '$leftMarginText$text'.codeUnits;
    }

    // Helper function for horizontal lines with proper width
    String getHorizontalLine() {
      return '-' * contentWidth;
    }

    // Helper function for safe string truncation
    String safeTruncate(String text, int maxLength, {String suffix = '...'}) {
      if (maxLength <= 0) return '';
      if (text.length <= maxLength) return text;
      if (maxLength <= suffix.length) return text.substring(0, maxLength);
      return '${text.substring(0, maxLength - suffix.length)}$suffix';
    }

    // Set center alignment for company header
    bytes.addAll([ESC, 0x61, 0x01]);

    // Company header - bold and larger
    bytes.addAll([ESC, 0x45, 0x01]); // Bold on
    bytes.addAll([GS, 0x21, 0x11]); // Double height and width

    // For headers, use text margins as ESC/POS margins might not work with center alignment
    bytes.addAll(addTextMargin('Sajith Rice Mill'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll([GS, 0x21, 0x00]); // Normal size
    bytes.addAll([ESC, 0x45, 0x00]); // Bold off

    // Company details with text margins
    bytes.addAll(addTextMargin('No. 123, Main Street'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll(addTextMargin('Colombo, Sri Lanka'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll(addTextMargin('Tel: +94 11 123 4567'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll('\n'.codeUnits);

    // Horizontal line with proper width
    bytes.addAll(addTextMargin(getHorizontalLine()));
    bytes.addAll('\n'.codeUnits);

    // Set left alignment for bill details
    bytes.addAll([ESC, 0x61, 0x00]);

    // Bill details with text margins
    bytes.addAll(addTextMargin('Bill No: ${bill.billNumber}'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll(
      addTextMargin('Date: ${DateFormat('dd/MM/yyyy').format(bill.billDate)}'),
    );
    bytes.addAll('\n'.codeUnits);
    bytes.addAll(
      addTextMargin('Time: ${DateFormat('HH:mm:ss').format(bill.billDate)}'),
    );
    bytes.addAll('\n'.codeUnits);
    bytes.addAll('\n'.codeUnits);

    // Customer and Sales Rep details with your working spacing
    const int separatorWidth = 5;
    final int availableWidth = contentWidth - separatorWidth;
    final int customerSectionWidth = (availableWidth * 0.6).round();
    final int repSectionWidth = availableWidth - customerSectionWidth;

    final int safeCustomerWidth =
        customerSectionWidth < 15 ? 15 : customerSectionWidth;
    final int safeRepWidth = repSectionWidth < 10 ? 10 : repSectionWidth;

    final int customerNameSpace = safeCustomerWidth - 10;
    final int customerAddressSpace = safeCustomerWidth - 9;
    final int customerPhoneSpace = safeCustomerWidth - 7;
    final int repNameSpace = safeRepWidth - 5;
    final int repPhoneSpace = safeRepWidth - 7;

    final String separator = ' ' * separatorWidth;

    String customerName = safeTruncate(bill.customerName, customerNameSpace);
    String customerAddress = safeTruncate(
      bill.outletAddress,
      customerAddressSpace,
    );
    String customerPhone = safeTruncate(bill.outletPhone, customerPhoneSpace);
    String repName = safeTruncate(bill.salesRepName, repNameSpace);
    String repPhone = safeTruncate(bill.salesRepPhone, repPhoneSpace);

    // Row 1: Customer Name | Rep Name
    String customerNameRow = 'Customer: $customerName'.padRight(
      safeCustomerWidth,
    );
    String repNameRow = 'Rep: $repName';
    bytes.addAll(addTextMargin(customerNameRow + separator + repNameRow));
    bytes.addAll('\n'.codeUnits);

    // Row 2: Customer Address | Rep Phone (if either exists)
    if (bill.outletAddress.isNotEmpty || bill.salesRepPhone.isNotEmpty) {
      String customerAddressRow =
          bill.outletAddress.isNotEmpty
              ? 'Address: $customerAddress'.padRight(safeCustomerWidth)
              : ''.padRight(safeCustomerWidth);
      String repPhoneRow =
          bill.salesRepPhone.isNotEmpty ? 'Phone: $repPhone' : '';
      bytes.addAll(addTextMargin(customerAddressRow + separator + repPhoneRow));
      bytes.addAll('\n'.codeUnits);
    }

    // Row 3: Customer Phone (if exists)
    if (bill.outletPhone.isNotEmpty) {
      String customerPhoneRow = 'Phone: $customerPhone'.padRight(
        safeCustomerWidth,
      );
      bytes.addAll(addTextMargin(customerPhoneRow + separator));
      bytes.addAll('\n'.codeUnits);
    }

    bytes.addAll('\n'.codeUnits);

    // Horizontal line before table
    bytes.addAll(addTextMargin(getHorizontalLine()));
    bytes.addAll('\n'.codeUnits);

    // FIXED TABLE HEADER - Proper total width calculation
    bytes.addAll([ESC, 0x45, 0x01]); // Bold on

    // Fixed column widths that add up correctly
    const int numWidth = 3; // # column
    const int nameWidth = 18; // Item Name column
    const int priceWidth = 8; // Price column
    const int qtyWidth = 4; // Qty column
    const int totalWidth = 7; // Total column
    // Total table width = 3+18+8+4+7 = 40 characters

    String headerRow =
        '#'.padRight(numWidth) +
        'Item Name'.padRight(nameWidth) +
        'Price'.padLeft(priceWidth) +
        'Qty'.padLeft(qtyWidth) +
        'Total'.padLeft(totalWidth);

    bytes.addAll(addTextMargin(headerRow));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll([ESC, 0x45, 0x00]); // Bold off

    bytes.addAll(addTextMargin(getHorizontalLine()));
    bytes.addAll('\n'.codeUnits);

    // FIXED TABLE ITEMS - Consistent with header alignment
    for (final item in bill.items) {
      String itemName = safeTruncate(
        item.itemName,
        nameWidth - 1,
      ); // Leave space for padding

      String itemRow =
          '${item.itemNumber}'.padRight(numWidth) +
          itemName.padRight(nameWidth) +
          '${item.unitPrice.toStringAsFixed(2)}'.padLeft(priceWidth) +
          '${item.quantity}'.padLeft(qtyWidth) +
          '${item.totalPrice.toStringAsFixed(2)}'.padLeft(totalWidth);

      bytes.addAll(addTextMargin(itemRow));
      bytes.addAll('\n'.codeUnits);
    }

    bytes.addAll(addTextMargin(getHorizontalLine()));
    bytes.addAll('\n'.codeUnits);

    // FIXED TOTALS - Aligned with table width (40 chars)
    const int tableWidth =
        numWidth + nameWidth + priceWidth + qtyWidth + totalWidth;

    if (bill.discountAmount > 0) {
      bytes.addAll(
        addTextMargin(
          'Subtotal:'.padLeft(tableWidth - 8) +
              '${(bill.totalAmount + bill.discountAmount).toStringAsFixed(2)}'
                  .padLeft(8),
        ),
      );
      bytes.addAll('\n'.codeUnits);

      bytes.addAll(
        addTextMargin(
          'Discount:'.padLeft(tableWidth - 8) +
              '-${bill.discountAmount.toStringAsFixed(2)}'.padLeft(8),
        ),
      );
      bytes.addAll('\n'.codeUnits);
    }

    if (bill.taxAmount > 0) {
      bytes.addAll(
        addTextMargin(
          'Tax:'.padLeft(tableWidth - 8) +
              '${bill.taxAmount.toStringAsFixed(2)}'.padLeft(8),
        ),
      );
      bytes.addAll('\n'.codeUnits);
    }

    // Total amount - bold and properly aligned
    bytes.addAll([ESC, 0x45, 0x01]); // Bold on
    bytes.addAll(
      addTextMargin(
        'TOTAL:'.padLeft(tableWidth - 11) +
            'Rs.${bill.finalAmount.toStringAsFixed(2)}'.padLeft(11),
      ),
    );
    bytes.addAll('\n'.codeUnits);
    bytes.addAll([ESC, 0x45, 0x00]); // Bold off

    bytes.addAll(addTextMargin(getHorizontalLine()));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll('\n'.codeUnits);

    // Signature section with proper spacing
    final int leftSignWidth = (contentWidth * 0.4).round();
    final int rightSignWidth = (contentWidth * 0.4).round();
    final int signSeparator = contentWidth - leftSignWidth - rightSignWidth;

    bytes.addAll(
      addTextMargin(
        'Customer Signature:'.padRight(leftSignWidth) +
            ' ' * signSeparator +
            'Rep Signature:'.padLeft(rightSignWidth),
      ),
    );
    bytes.addAll('\n'.codeUnits);
    bytes.addAll(
      addTextMargin(
        '${'_' * (leftSignWidth - 1)}${' ' * (signSeparator + 1)}${'_' * (rightSignWidth - 1)}',
      ),
    );
    bytes.addAll('\n'.codeUnits);
    bytes.addAll('\n'.codeUnits);

    // Thank you message - center aligned
    bytes.addAll([ESC, 0x61, 0x01]); // Center alignment
    bytes.addAll(addTextMargin('Thank you for your business!'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll('\n'.codeUnits);

    // Horizontal line
    bytes.addAll(addTextMargin(getHorizontalLine()));
    bytes.addAll('\n'.codeUnits);

    // Solution by section - center aligned
    bytes.addAll(addTextMargin('Solution by'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll([ESC, 0x45, 0x01]); // Bold on
    bytes.addAll(addTextMargin('Lumora Ventures Pvt Ltd'));
    bytes.addAll('\n'.codeUnits);
    bytes.addAll([ESC, 0x45, 0x00]); // Bold off
    bytes.addAll(addTextMargin('Mobile: +94 76 620 6555'));
    bytes.addAll('\n'.codeUnits);

    // Feed and cut
    bytes.addAll('\n\n\n'.codeUnits);
    bytes.addAll([GS, 0x56, 0x00]); // Cut paper

    return bytes;
  }

  // Generate test receipt
  static String _generateTestReceipt() {
    final StringBuffer test = StringBuffer();
    const int paperWidth = 48; // 104mm paper width in characters
    const String margin = '    '; // 4-space margin

    test.writeln('$margin${'=' * (paperWidth - 8)}');
    test.writeln('$margin${_centerText('TEST PRINT', paperWidth - 8)}');
    test.writeln('$margin${_centerText('Lumora Business', paperWidth - 8)}');
    test.writeln('$margin${_centerText('Printer Test', paperWidth - 8)}');
    test.writeln('$margin${'=' * (paperWidth - 8)}');
    test.writeln();
    test.writeln(
      '$margin${_centerText(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()), paperWidth - 8)}',
    );
    test.writeln();
    test.writeln(
      '$margin${_centerText('If you can read this,', paperWidth - 8)}',
    );
    test.writeln(
      '$margin${_centerText('your printer is working!', paperWidth - 8)}',
    );
    test.writeln();
    test.writeln('$margin${'=' * (paperWidth - 8)}');
    test.writeln();
    test.writeln();
    test.writeln();

    return test.toString();
  }

  // Get available paper sizes
  static Future<List<String>> getAvailablePaperSizes() async {
    try {
      // Common thermal printer paper sizes
      return ['58mm', '80mm', '104mm'];
    } catch (e) {
      print('Error getting paper sizes: $e');
      return ['58mm', '80mm', '104mm'];
    }
  }

  // Get printer status
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
        'lastUpdate': DateTime.now().toString(),
      };
    } catch (e) {
      return {'isConnected': false, 'error': e.toString()};
    }
  }

  // Check if ready to print
  static bool isReadyToPrint() {
    return _isConnected && _selectedDevice != null;
  }

  // Print raw text (useful for testing)
  static Future<bool> printRawText(String text) async {
    if (!_isConnected || _selectedDevice == null) {
      throw Exception('Printer not connected');
    }

    try {
      // Convert string to bytes and print
      final List<int> bytes = text.codeUnits;
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      print('Error printing raw text: $e');
      return false;
    }
  }

  // Advanced: Print with custom ESC/POS commands
  static Future<bool> printWithCommands(List<int> commands) async {
    if (!_isConnected || _selectedDevice == null) {
      throw Exception('Printer not connected');
    }

    try {
      final bool result = await PrintBluetoothThermal.writeBytes(commands);
      return result;
    } catch (e) {
      print('Error printing with commands: $e');
      return false;
    }
  }
}
