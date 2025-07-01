// lib/screens/printing/printer_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/printing/bill_printer_service.dart';

class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  List<BluetoothInfo> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  BluetoothInfo? _selectedDevice;
  String _connectionStatus = '';
  bool _bluetoothEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    await _checkPermissions();
    await _checkBluetoothStatus();
    _selectedDevice = BillPrinterService.selectedDevice;
    if (mounted) {
      setState(() {
        _connectionStatus =
            BillPrinterService.isConnected
                ? 'Connected to ${_selectedDevice?.name ?? 'Unknown'}'
                : 'Not connected';
      });
    }
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      final enabled = await BillPrinterService.isBluetoothAvailable();
      setState(() {
        _bluetoothEnabled = enabled;
      });

      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please enable Bluetooth to use thermal printer',
              ),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  await openAppSettings();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking Bluetooth status: $e');
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Bluetooth permissions required for thermal printing',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _scanForDevices() async {
    if (!_bluetoothEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable Bluetooth first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      final devices = await BillPrinterService.scanDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });

        if (devices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No paired thermal printers found. Please pair your printer in Bluetooth settings first.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting to ${device.name}...';
    });

    // Show connecting dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Connecting to ${device.name}...'),
                  const SizedBox(height: 8),
                  const Text(
                    'Establishing thermal printer connection',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
      );
    }

    try {
      final success = await BillPrinterService.connectToDevice(device);

      if (mounted) {
        Navigator.pop(context); // Close connecting dialog

        setState(() {
          _isConnecting = false;
          if (success) {
            _selectedDevice = device;
            _connectionStatus = 'Connected to ${device.name}';
          } else {
            _connectionStatus = 'Failed to connect to ${device.name}';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Successfully connected to ${device.name}! Ready to print.'
                  : 'Failed to connect to ${device.name}. Make sure the printer is on and in range.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: success ? 3 : 5),
          ),
        );

        if (success) {
          // Auto-navigate back after successful connection
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close connecting dialog

        setState(() {
          _isConnecting = false;
          _connectionStatus = 'Connection error';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await BillPrinterService.disconnect();
      if (mounted) {
        setState(() {
          _selectedDevice = null;
          _connectionStatus = 'Disconnected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from thermal printer'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnect error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    try {
      final success = await BillPrinterService.testPrint();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Test print successful! Check your thermal printer output.'
                  : 'Test print failed. Check printer connection.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'Thermal Printer Setup',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (BillPrinterService.isConnected)
            IconButton(
              onPressed: _testPrint,
              icon: const Icon(Icons.print),
              tooltip: 'Test Print',
            ),
        ],
      ),
      body: Column(
        children: [
          // Bluetooth Status Banner
          if (!_bluetoothEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bluetooth is disabled. Please enable it in device settings.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: _checkBluetoothStatus,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),

          // Connection Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      BillPrinterService.isConnected
                          ? Icons.print
                          : Icons.print_disabled,
                      color:
                          BillPrinterService.isConnected
                              ? Colors.green
                              : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thermal Printer Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _connectionStatus,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (BillPrinterService.isConnected)
                      TextButton(
                        onPressed: _disconnectDevice,
                        child: const Text('Disconnect'),
                      ),
                  ],
                ),
                if (BillPrinterService.isConnected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testPrint,
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Test Print Receipt'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Scan Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_isScanning || !_bluetoothEnabled)
                        ? null
                        : _scanForDevices,
                icon:
                    _isScanning
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.bluetooth_searching, size: 18),
                label: Text(
                  _isScanning
                      ? 'Scanning for Printers...'
                      : 'Find Paired Thermal Printers',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _bluetoothEnabled ? Colors.blue.shade600 : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Devices List
          Expanded(
            child:
                _devices.isEmpty && !_isScanning
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.print_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No thermal printers found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Make sure your thermal printer is:\n• Turned on and ready\n• Paired in Bluetooth settings\n• ESC/POS compatible (58mm recommended)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed:
                                _bluetoothEnabled ? _scanForDevices : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () async {
                              await openAppSettings();
                            },
                            child: const Text('Open Bluetooth Settings'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected =
                            _selectedDevice?.macAdress == device.macAdress;
                        final isConnected =
                            BillPrinterService.isConnected && isSelected;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.green.shade300
                                      : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor:
                                  isConnected
                                      ? Colors.green.shade100
                                      : Colors.blue.shade100,
                              child: Icon(
                                isConnected ? Icons.print : Icons.bluetooth,
                                color:
                                    isConnected
                                        ? Colors.green.shade600
                                        : Colors.blue.shade600,
                              ),
                            ),
                            title: Text(
                              device.name.isNotEmpty
                                  ? device.name
                                  : 'Thermal Printer',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'MAC: ${device.macAdress}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (isConnected) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Connected & Ready',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing:
                                _isConnecting && isSelected
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : isConnected
                                    ? PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: Colors.green.shade600,
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'test') {
                                          await _testPrint();
                                        } else if (value == 'disconnect') {
                                          await _disconnectDevice();
                                        }
                                      },
                                      itemBuilder:
                                          (context) => [
                                            const PopupMenuItem(
                                              value: 'test',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.print, size: 16),
                                                  SizedBox(width: 8),
                                                  Text('Test Print'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'disconnect',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.bluetooth_disabled,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Disconnect'),
                                                ],
                                              ),
                                            ),
                                          ],
                                    )
                                    : Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                            onTap:
                                (isConnected || _isConnecting)
                                    ? null
                                    : () => _connectToDevice(device),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
