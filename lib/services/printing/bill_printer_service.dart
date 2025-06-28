// lib/services/printing/bill_printer_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:intl/intl.dart';
import '../../models/print_bill.dart';

class BillPrinterService {
  static String? _selectedAddress;
  static bool _isConnected = false;
  static ReceiptController? _controller;

  // Get current connected device address
  static String? get selectedAddress => _selectedAddress;
  static bool get isConnected => _isConnected;

  // Select a Bluetooth printer device
  static Future<String?> selectDevice(BuildContext context) async {
    try {
      final selected = await FlutterBluetoothPrinter.selectDevice(context);
      if (selected != null) {
        _selectedAddress = selected.address;
        _isConnected = true;
        return selected.address;
      }
      return null;
    } catch (e) {
      print('Error selecting device: $e');
      return null;
    }
  }

  // Disconnect from printer
  static void disconnect() {
    _selectedAddress = null;
    _isConnected = false;
    _controller = null;
  }

  // Set the receipt controller
  static void setController(ReceiptController controller) {
    _controller = controller;
  }

  // Print bill using Receipt widget
  static Future<bool> printBill(PrintBill bill) async {
    if (_controller == null || _selectedAddress == null) {
      throw Exception('Printer not connected or controller not set');
    }

    try {
      final result = await _controller!.print(address: _selectedAddress!);
      return result;
    } catch (e) {
      print('Error printing bill: $e');
      return false;
    }
  }

  // Print raw text (for testing)
  static Future<bool> printText(String text) async {
    if (_controller == null || _selectedAddress == null) {
      throw Exception('Printer not connected or controller not set');
    }

    try {
      final result = await _controller!.print(address: _selectedAddress!);
      return result;
    } catch (e) {
      print('Error printing text: $e');
      return false;
    }
  }

  // Test print functionality
  static Future<bool> testPrint() async {
    if (_controller == null || _selectedAddress == null) {
      throw Exception('Printer not connected or controller not set');
    }

    try {
      final result = await _controller!.print(address: _selectedAddress!);
      return result;
    } catch (e) {
      print('Error in test print: $e');
      return false;
    }
  }

  // Check if ready to print
  static bool isReadyToPrint() {
    return _controller != null && _selectedAddress != null;
  }

  // Get printer status
  static Map<String, dynamic> getPrinterStatus() {
    return {
      'isConnected': _isConnected,
      'hasController': _controller != null,
      'deviceAddress': _selectedAddress ?? 'None',
      'isReady': isReadyToPrint(),
    };
  }

  // Format currency (matching your existing pattern)
  static final NumberFormat currency = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );
}
