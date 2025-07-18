// lib/screens/home/home_screen.dart (UPDATED with One-Unloading-Per-Day Support)
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/addOutlet.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/loading_provider.dart';
import '../../services/unloading/unloading_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Timer _timer;
  DateTime _currentDateTime = DateTime.now();
  bool _isConnected = false;
  bool _isUploading = false;
  Map<String, dynamic>? _pendingUploadData;
  Map<String, dynamic>? _unloadingStatus; // NEW: Track unloading status

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _checkConnectivity();
    _startTimer();
    _loadTodaysData();
    _checkUnloadingStatus(); // NEW: Check today's unloading status
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      }
    });
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;
    });

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (mounted) {
        setState(() {
          _isConnected =
              result.isNotEmpty && result.first != ConnectivityResult.none;
        });
      }
    });
  }

  void _loadTodaysData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final loadingProvider = context.read<LoadingProvider>();

      if (authProvider.currentSession != null) {
        loadingProvider.loadTodaysLoading(authProvider.currentSession!);
      }
    });
  }

  // NEW: Check today's unloading status
  void _checkUnloadingStatus() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentSession != null) {
      try {
        final unloadingStatus = await UnloadingService.getTodaysUnloadingStatus(
          authProvider.currentSession!,
        );
        setState(() {
          _unloadingStatus = unloadingStatus;
        });

        // Also check pending upload data
        final pendingData = await UnloadingService.getPendingUploadData(
          authProvider.currentSession!,
        );
        setState(() {
          _pendingUploadData = pendingData;
        });
      } catch (e) {
        print('Error checking unloading status: $e');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _showProfile() {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${authProvider.currentSession?.name ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Email: ${authProvider.currentSession?.email ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Phone: ${authProvider.currentSession?.phone ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Role: ${authProvider.currentSession?.role ?? 'N/A'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final authProvider = context.read<AuthProvider>();
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _getData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting data from database...'),
        backgroundColor: Colors.blue,
      ),
    );

    final loadingProvider = context.read<LoadingProvider>();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentSession != null) {
      loadingProvider.refreshLoading(authProvider.currentSession!);
      // Refresh unloading status after getting new data
      _checkUnloadingStatus();
    }
  }

  // ENHANCED: Upload data method with one-per-day validation
  void _uploadData() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Cannot upload data.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user session found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // NEW: Check if unloading already exists for today
    if (_unloadingStatus != null && _unloadingStatus!['hasUnloading'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unloading already completed for today!\n'
            'Bill Count: ${_unloadingStatus!['billCount']}\n'
            'Total Value: Rs.${_unloadingStatus!['totalValue'].toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      _showUnloadingAlreadyExistsDialog();
      return;
    }

    // Validate before upload using enhanced validation
    final validation = await UnloadingService.validateBeforeUpload(
      authProvider.currentSession!,
    );

    if (!validation['isValid']) {
      final errors = validation['errors'] as List<String>;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot upload: ${errors.join(', ')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Show warnings if any
    final warnings = validation['warnings'] as List<String>;
    if (warnings.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Info: ${warnings.join(', ')}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() => _isUploading = true);

    try {
      // Show uploading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating daily unloading summary...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      // Use enhanced uploadDayData method with one-per-day enforcement
      final result = await UnloadingService.uploadDayData(
        session: authProvider.currentSession!,
      );

      if (mounted) {
        if (result['success']) {
          // Success - show detailed results
          final uploadedBills = result['uploadedBills'] as int;
          final details = result['details'] as Map<String, dynamic>;
          final totalValue = details['totalValue'] as double;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unloading successful!\n'
                '$uploadedBills bills uploaded\n'
                'Total value: Rs.${totalValue.toStringAsFixed(2)}\n'
                'Date: ${details['uploadDate']}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );

          // Refresh unloading status
          _checkUnloadingStatus();

          // Show detailed success dialog
          _showUnloadingSuccessDialog(result);
        } else {
          // Handle errors
          final errors = result['errors'] as List<String>;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unloading failed:\n${errors.join('\n')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unloading error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // NEW: Show dialog when unloading already exists
  void _showUnloadingAlreadyExistsDialog() {
    if (_unloadingStatus == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                const Text('Unloading Completed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s unloading has already been completed.'),
                const SizedBox(height: 12),
                Text(
                  '📅 Date: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                ),
                Text('📊 Bills: ${_unloadingStatus!['billCount']} bills'),
                Text(
                  '💰 Total: Rs.${_unloadingStatus!['totalValue'].toStringAsFixed(2)}',
                ),
                Text('📋 Status: ${_unloadingStatus!['status']}'),
                const SizedBox(height: 12),
                const Text(
                  'Only one unloading per sales rep per day is allowed.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // ENHANCED: Show detailed upload success dialog
  void _showUnloadingSuccessDialog(Map<String, dynamic> result) {
    final details = result['details'] as Map<String, dynamic>;
    final uploadedBills = result['uploadedBills'] as int;
    final billNumbers = details['billNumbers'] as List<String>;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                const Text('Unloading Complete'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✓ $uploadedBills bills uploaded'),
                  Text('✓ Date: ${details['uploadDate']}'),
                  Text('✓ Sales Rep: ${details['salesRep']}'),
                  const SizedBox(height: 8),
                  Text(
                    '💰 Total Sales: Rs.${details['totalValue'].toStringAsFixed(2)}',
                  ),
                  Text(
                    '💵 Cash: Rs.${details['totalCash']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  Text(
                    '💳 Credit: Rs.${details['totalCredit']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  Text(
                    '🏦 Cheque: Rs.${details['totalCheque']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  const SizedBox(height: 12),
                  Text('📋 Bill Numbers (${billNumbers.length}):'),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        billNumbers.join(', '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('✓ Unloading summary created'),
                  const Text('✓ Stock quantities updated'),
                  const Text('✓ All data synchronized'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade800,
        foregroundColor: Colors.white,
        title: const Text(
          'LumoraBiz',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          // Profile Button
          IconButton(
            onPressed: _showProfile,
            icon: const Icon(Icons.person, color: Colors.white54),
            tooltip: 'Profile',
          ),
          // Logout Button
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final authProvider = context.read<AuthProvider>();
          final loadingProvider = context.read<LoadingProvider>();

          if (authProvider.currentSession != null) {
            await loadingProvider.refreshLoading(authProvider.currentSession!);
            _checkUnloadingStatus(); // Refresh unloading status too
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and Route Info
                _buildInfoSection(),
                const SizedBox(height: 24),

                // ENHANCED: Unloading Status Alert
                _buildUnloadingStatusAlert(),

                // Today's Prices Section
                _buildTodaysPricesSection(),
                const SizedBox(height: 24),

                // Data Management Buttons
                _buildDataManagementSection(),
                const SizedBox(height: 24),

                // Main Action Buttons
                _buildMainActionsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ENHANCED: Unloading status alert widget
  Widget _buildUnloadingStatusAlert() {
    if (_unloadingStatus == null) {
      return const SizedBox.shrink();
    }

    final hasUnloading = _unloadingStatus!['hasUnloading'] as bool;

    if (hasUnloading) {
      // Show completed unloading status
      final billCount = _unloadingStatus!['billCount'] as int;
      final totalValue = _unloadingStatus!['totalValue'] as double;

      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Unloading Completed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$billCount bills processed worth Rs.${totalValue.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.green[700]),
            ),
            Text(
              'Date: ${DateTime.now().toLocal().toString().split(' ')[0]}',
              style: TextStyle(color: Colors.green[600], fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      // Show pending upload alert (if there are bills to upload)
      if (_pendingUploadData != null && _pendingUploadData!['hasPendingData']) {
        final billsCount = _pendingUploadData!['pendingBillsCount'] as int;
        final totalValue = _pendingUploadData!['totalPendingValue'] as double;
        final hasLoading = _pendingUploadData!['hasLoading'] as bool? ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.upload_outlined,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ready for Daily Unloading',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$billsCount bills worth Rs.${totalValue.toStringAsFixed(2)} ready for unloading.',
                style: TextStyle(color: Colors.orange[700]),
              ),
              if (!hasLoading) ...[
                const SizedBox(height: 4),
                Text(
                  'Warning: No loading data found for today.',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isConnected && !_isUploading && hasLoading
                          ? _uploadData
                          : null,
                  icon:
                      _isUploading
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
                          : const Icon(Icons.cloud_upload, size: 18),
                  label: Text(
                    _isUploading
                        ? 'Creating Unloading...'
                        : 'Create Daily Unloading',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_isConnected && hasLoading && !_isUploading)
                            ? Colors.orange[600]
                            : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Info
        Text(
          'Date: ${DateFormat('EEEE, MMMM d, y').format(_currentDateTime)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),

        // Today's Route
        Consumer<LoadingProvider>(
          builder: (context, loadingProvider, child) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Today Route: ${loadingProvider.hasRouteContext ? loadingProvider.currentRouteName : "No route assigned"}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                // Connection Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        _isConnected
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    border: Border.all(
                      color:
                          _isConnected
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color:
                            _isConnected
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected ? 'Online' : 'Offline',
                        style: TextStyle(
                          color:
                              _isConnected
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodaysPricesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Prices",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        Consumer<LoadingProvider>(
          builder: (context, loadingProvider, child) {
            final loading = loadingProvider.currentLoading;
            final paddyPrices = loading?.todayPaddyPrices;

            if (loadingProvider.isLoading) {
              return Container(
                height: 100,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            }

            if (paddyPrices == null || paddyPrices.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'No paddy prices set for today',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children:
                  paddyPrices.entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Rs.${entry.value}/kg',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Data Management",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _getData,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Get Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isConnected && !_isUploading ? _uploadData : null,
                icon:
                    _isUploading
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
                        : const Icon(Icons.upload, size: 18),
                label: Text(_isUploading ? 'Unloading...' : 'Unload Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isConnected && !_isUploading
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Main Actions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        Consumer<LoadingProvider>(
          builder: (context, loadingProvider, child) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildActionButton(
                  title: 'Create Bill',
                  subtitle: 'New billing',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        '/billing/outlet-selection',
                      ),
                ),
                _buildActionButton(
                  title: 'Add Customer',
                  subtitle: 'New outlet',
                  icon: Icons.store_outlined,
                  color: Colors.green,
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AddOutlet(
                                routeName:
                                    loadingProvider.currentRouteName ?? '',
                                routeId: loadingProvider.currentRouteId ?? '',
                              ),
                        ),
                      ),
                ),
                _buildActionButton(
                  title: 'Stock',
                  subtitle: 'Current stock',
                  icon: Icons.inventory,
                  color: Colors.orange,
                  onTap: () => Navigator.pushNamed(context, '/loading'),
                ),
                _buildActionButton(
                  title: 'Day Summary',
                  subtitle: 'Bill summary',
                  icon: Icons.assessment,
                  color: Colors.purple,
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        '/reports/daily-summary',
                      ),
                ),
                _buildActionButton(
                  title: 'View Bills',
                  subtitle: 'Created bills',
                  icon: Icons.list_alt,
                  color: Colors.indigo,
                  onTap:
                      () => Navigator.pushNamed(context, '/billing/view-bills'),
                ),
                _buildActionButton(
                  title: 'Outlets',
                  subtitle: 'Manage outlets',
                  icon: Icons.business,
                  color: Colors.teal,
                  onTap: () => Navigator.pushNamed(context, '/outlets'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isEnabled ? color : Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isEnabled ? Colors.grey.shade800 : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
