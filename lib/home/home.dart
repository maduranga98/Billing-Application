import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

// Add your OfflineOutletData and OfflineStorageService classes here
// (Copy from your AddOutlet file)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  DateTime _currentDateTime = DateTime.now();
  Timer? _timer;
  String _currentRoute = 'Home';
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Mock data for dashboard stats
  final int _todaysBills = 12;
  final double _todaysRevenue = 2450.75;
  final int _totalCustomers = 156;
  final int _totalOutlets = 3;

  // Offline data management
  bool _isConnected = true;
  int _offlineOutletCount = 0;
  bool _isUploadingOfflineData = false;
  double _uploadProgress = 0.0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Constants (should match your AddOutlet constants)
  static const String ownerId = 'UWX4f6ofSxaXDag2CC0aT0t6Ycd2';
  static const String businessId = 'yVjEcw88CxIinbdL3R2O';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _setupAnimations();
    _checkConnectivity();
    _loadOfflineOutletCount();
    _listenToConnectivityChanges();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentDateTime = DateTime.now();
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final List<ConnectivityResult> connectivityResults =
        await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = !connectivityResults.contains(ConnectivityResult.none);
    });
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isConnected = !results.contains(ConnectivityResult.none);
      setState(() {
        _isConnected = isConnected;
      });

      if (_isConnected) {
        _loadOfflineOutletCount();
      }
    });
  }

  Future<void> _loadOfflineOutletCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineOutlets =
          prefs.getStringList('offline_outlets') ?? [];
      setState(() {
        _offlineOutletCount = offlineOutlets.length;
      });
    } catch (e) {
      print('Error loading offline outlet count: $e');
    }
  }

  Future<void> _uploadOfflineData() async {
    if (_offlineOutletCount == 0) {
      _showSnackBar('No offline data to upload');
      return;
    }

    setState(() => _isUploadingOfflineData = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineOutlets =
          prefs.getStringList('offline_outlets') ?? [];

      if (offlineOutlets.isEmpty) {
        _showSnackBar('No offline data to upload');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < offlineOutlets.length; i++) {
        try {
          final outletData = jsonDecode(offlineOutlets[i]);

          // Create Firestore document
          final DocumentReference outletRef =
              _firestore
                  .collection('owners')
                  .doc(ownerId)
                  .collection('businesses')
                  .doc(businessId)
                  .collection('customers')
                  .doc();

          final String firestoreId = outletRef.id;

          // Upload image if exists
          String? imageUrl;
          if (outletData['imageBase64'] != null) {
            try {
              final Uint8List imageBytes = base64Decode(
                outletData['imageBase64'],
              );

              final String fileName =
                  'outlet_${firestoreId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

              final Reference storageRef = _storage
                  .ref()
                  .child('owners')
                  .child(ownerId)
                  .child('businesses')
                  .child(businessId)
                  .child('outlets')
                  .child(firestoreId)
                  .child('images')
                  .child(fileName);

              final UploadTask uploadTask = storageRef.putData(imageBytes);
              final TaskSnapshot snapshot = await uploadTask;
              imageUrl = await snapshot.ref.getDownloadURL();
            } catch (e) {
              print('Error uploading image for outlet ${outletData['id']}: $e');
            }
          }

          // Prepare outlet data for Firestore
          final Map<String, dynamic> firestoreData = {
            'id': firestoreId,
            'outletName': outletData['outletName'],
            'address': outletData['address'],
            'phoneNumber': outletData['phoneNumber'],
            'coordinates': {
              'latitude': outletData['latitude'],
              'longitude': outletData['longitude'],
            },
            'ownerName': outletData['ownerName'],
            'outletType': outletData['outletType'],
            'imageUrl': imageUrl,
            'createdAt': Timestamp.fromMillisecondsSinceEpoch(
              outletData['createdAt'],
            ),
            'registeredDate': Timestamp.fromMillisecondsSinceEpoch(
              outletData['createdAt'],
            ),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'isActive': true,
            'businessId': businessId,
            'ownerId': ownerId,
          };

          // Save to Firestore
          await outletRef.set(firestoreData);

          successCount++;

          // Update progress
          setState(() {
            _uploadProgress = (i + 1) / offlineOutlets.length;
          });
        } catch (e) {
          print('Error uploading outlet: $e');
          failCount++;
        }
      }

      // Clear offline data after successful upload
      if (successCount > 0) {
        await prefs.remove('offline_outlets');
      }

      // Update offline count
      await _loadOfflineOutletCount();

      // Show result
      if (failCount == 0) {
        _showSnackBar('All $successCount outlets uploaded successfully!');
      } else {
        _showSnackBar(
          'Uploaded $successCount outlets. $failCount failed.',
          isError: failCount > successCount,
        );
      }
    } catch (e) {
      print('Error uploading offline data: $e');
      _showSnackBar('Error uploading offline data: $e', isError: true);
    } finally {
      setState(() {
        _isUploadingOfflineData = false;
        _uploadProgress = 0.0;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  void _navigateToCreateBill() {
    setState(() => _currentRoute = 'Create Bill');
    Navigator.pushNamed(context, '/create-bill');
  }

  void _navigateToAddOutlet() {
    setState(() => _currentRoute = 'Add Outlet');
    Navigator.pushNamed(context, '/add-outlet');
  }

  void _navigateToCustomers() {
    setState(() => _currentRoute = 'Customers');
    Navigator.pushNamed(context, '/customers');
  }

  void _navigateToBills() {
    setState(() => _currentRoute = 'Bills');
    Navigator.pushNamed(context, '/bills');
  }

  void _navigateToOutlets() {
    setState(() => _currentRoute = 'Outlets');
    Navigator.pushNamed(context, '/outlets');
  }

  void _navigateToReports() {
    setState(() => _currentRoute = 'Reports');
    Navigator.pushNamed(context, '/reports');
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'EEEE, MMMM d, y',
    ).format(_currentDateTime);
    final String formattedTime = DateFormat(
      'HH:mm:ss',
    ).format(_currentDateTime);
    final String userName =
        _currentUser?.displayName ??
        _currentUser?.email?.split('@')[0] ??
        'User';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back to BillMaster',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: CircleAvatar(
                        backgroundColor: Colors.blue.shade600,
                        child: Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'logout') _signOut();
                      },
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline),
                                  SizedBox(width: 12),
                                  Text('Profile'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(Icons.settings_outlined),
                                  SizedBox(width: 12),
                                  Text('Settings'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Connection Status & Offline Data Card
                if (!_isConnected || _offlineOutletCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color:
                          !_isConnected
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            !_isConnected
                                ? Colors.orange.shade200
                                : Colors.blue.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              !_isConnected ? Icons.wifi_off : Icons.sync,
                              color:
                                  !_isConnected
                                      ? Colors.orange.shade600
                                      : Colors.blue.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                !_isConnected
                                    ? 'Offline Mode'
                                    : _offlineOutletCount > 0
                                    ? 'Offline Data Ready for Sync'
                                    : 'All Data Synced',
                                style: TextStyle(
                                  color:
                                      !_isConnected
                                          ? Colors.orange.shade700
                                          : Colors.blue.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_offlineOutletCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_offlineOutletCount',
                                  style: TextStyle(
                                    color:
                                        !_isConnected
                                            ? Colors.orange.shade700
                                            : Colors.blue.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_offlineOutletCount > 0) ...[
                          const SizedBox(height: 12),
                          Text(
                            _isConnected
                                ? '$_offlineOutletCount outlet(s) waiting to be uploaded to cloud'
                                : 'Data will sync automatically when connection is restored',
                            style: TextStyle(
                              color:
                                  !_isConnected
                                      ? Colors.orange.shade600
                                      : Colors.blue.shade600,
                              fontSize: 14,
                            ),
                          ),
                          if (_isConnected && !_isUploadingOfflineData) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _uploadOfflineData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.cloud_upload, size: 20),
                                label: const Text(
                                  'Sync Now',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_isUploadingOfflineData) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Syncing... ${(_uploadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.blue.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                // Date & Time Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Current Route: $_currentRoute',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Quick Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Today\'s Bills',
                        _todaysBills.toString(),
                        Icons.receipt_long,
                        Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Revenue',
                        '\$${_todaysRevenue.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Customers',
                        _totalCustomers.toString(),
                        Icons.people,
                        Colors.purple.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Outlets',
                        _totalOutlets.toString(),
                        Icons.store,
                        Colors.teal.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Main Action Buttons
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Create Bill',
                              Icons.add_card,
                              Colors.blue.shade600,
                              _navigateToCreateBill,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              'Add Outlet',
                              Icons.add_business,
                              Colors.green.shade600,
                              _navigateToAddOutlet,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Secondary Action Buttons
                      Text(
                        'Quick Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),

                      const SizedBox(height: 16),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                        children: [
                          _buildQuickAccessCard(
                            'Customers',
                            Icons.people_outline,
                            Colors.purple.shade100,
                            Colors.purple.shade600,
                            _navigateToCustomers,
                          ),
                          _buildQuickAccessCard(
                            'All Bills',
                            Icons.receipt_outlined,
                            Colors.blue.shade100,
                            Colors.blue.shade600,
                            _navigateToBills,
                          ),
                          _buildQuickAccessCard(
                            'Outlets',
                            Icons.store_outlined,
                            Colors.teal.shade100,
                            Colors.teal.shade600,
                            _navigateToOutlets,
                          ),
                          _buildQuickAccessCard(
                            'Reports',
                            Icons.analytics_outlined,
                            Colors.orange.shade100,
                            Colors.orange.shade600,
                            _navigateToReports,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      // Floating Action Button for Sync (Alternative approach)
      floatingActionButton:
          _offlineOutletCount > 0 && _isConnected && !_isUploadingOfflineData
              ? FloatingActionButton.extended(
                onPressed: _uploadOfflineData,
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.sync),
                label: Text('Sync $_offlineOutletCount'),
              )
              : null,
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(
    String title,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
