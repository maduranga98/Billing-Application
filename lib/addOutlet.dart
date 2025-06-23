import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

// Custom Text Input Formatter for capitalizing after spaces
class CapitalizationTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    // Capitalize first letter
    String formattedText = text[0].toUpperCase();

    // Capitalize letters after spaces
    for (int i = 1; i < text.length; i++) {
      if (text[i - 1] == ' ' && text[i] != ' ') {
        formattedText += text[i].toUpperCase();
      } else {
        formattedText += text[i];
      }
    }

    return TextEditingValue(text: formattedText, selection: newValue.selection);
  }
}

// Model class for offline outlet data
class OfflineOutletData {
  final String id;
  final String outletName;
  final String address;
  final String phoneNumber;
  final double latitude;
  final double longitude;
  final String ownerName;
  final String outletType;
  final String? imageBase64;
  final String? imagePath;
  final DateTime createdAt;
  final String businessId;
  final String ownerId;

  OfflineOutletData({
    required this.id,
    required this.outletName,
    required this.address,
    required this.phoneNumber,
    required this.latitude,
    required this.longitude,
    required this.ownerName,
    required this.outletType,
    this.imageBase64,
    this.imagePath,
    required this.createdAt,
    required this.businessId,
    required this.ownerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outletName': outletName,
      'address': address,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'ownerName': ownerName,
      'outletType': outletType,
      'imageBase64': imageBase64,
      'imagePath': imagePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'businessId': businessId,
      'ownerId': ownerId,
    };
  }

  factory OfflineOutletData.fromJson(Map<String, dynamic> json) {
    return OfflineOutletData(
      id: json['id'],
      outletName: json['outletName'],
      address: json['address'],
      phoneNumber: json['phoneNumber'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      ownerName: json['ownerName'],
      outletType: json['outletType'],
      imageBase64: json['imageBase64'],
      imagePath: json['imagePath'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      businessId: json['businessId'],
      ownerId: json['ownerId'],
    );
  }
}

// Offline storage service
class OfflineStorageService {
  static const String _offlineOutletsKey = 'offline_outlets';

  static Future<void> saveOfflineOutlet(OfflineOutletData outlet) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineOutlets = prefs.getStringList(_offlineOutletsKey) ?? [];

    offlineOutlets.add(jsonEncode(outlet.toJson()));
    await prefs.setStringList(_offlineOutletsKey, offlineOutlets);
  }

  static Future<List<OfflineOutletData>> getOfflineOutlets() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineOutlets = prefs.getStringList(_offlineOutletsKey) ?? [];

    return offlineOutlets.map((outletJson) {
      return OfflineOutletData.fromJson(jsonDecode(outletJson));
    }).toList();
  }

  static Future<void> removeOfflineOutlet(String outletId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineOutlets = prefs.getStringList(_offlineOutletsKey) ?? [];

    offlineOutlets.removeWhere((outletJson) {
      final outlet = OfflineOutletData.fromJson(jsonDecode(outletJson));
      return outlet.id == outletId;
    });

    await prefs.setStringList(_offlineOutletsKey, offlineOutlets);
  }

  static Future<void> clearAllOfflineOutlets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineOutletsKey);
  }

  static Future<int> getOfflineOutletCount() async {
    final outlets = await getOfflineOutlets();
    return outlets.length;
  }
}

// Connectivity service
// Fixed Connectivity service for connectivity_plus 3.0+
class ConnectivityService {
  static Future<bool> isConnected() async {
    final List<ConnectivityResult> connectivityResults =
        await Connectivity().checkConnectivity();
    return !connectivityResults.contains(ConnectivityResult.none);
  }

  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged;

  static bool isConnectionAvailable(List<ConnectivityResult> results) {
    return !results.contains(ConnectivityResult.none);
  }
}

class AddOutlet extends StatefulWidget {
  const AddOutlet({super.key});

  @override
  State<AddOutlet> createState() => _AddOutletState();
}

class _AddOutletState extends State<AddOutlet> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Form Controllers
  final _outletNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _ownerNameController = TextEditingController();

  // Form State
  String _selectedOutletType = 'Retail';
  File? _outletImage;
  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isConnected = true;
  bool _isUploadingOfflineData = false;
  double _uploadProgress = 0.0;
  int _offlineOutletCount = 0;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Firebase paths
  static const String ownerId = 'UWX4f6ofSxaXDag2CC0aT0t6Ycd2';
  static const String businessId = 'yVjEcw88CxIinbdL3R2O';

  // Outlet Type Options
  final List<String> _outletTypes = [
    'Retail',
    'Wholesale',
    'Hotel',
    'Customer',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkConnectivity();
    _loadOfflineOutletCount();
    _listenToConnectivityChanges();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  // Replace these methods in your _AddOutletState class:

  Future<void> _checkConnectivity() async {
    final isConnected = await ConnectivityService.isConnected();
    setState(() {
      _isConnected = isConnected;
    });
  }

  void _listenToConnectivityChanges() {
    ConnectivityService.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isConnected = ConnectivityService.isConnectionAvailable(results);
      setState(() {
        _isConnected = isConnected;
      });

      if (_isConnected) {
        _loadOfflineOutletCount();
      }
    });
  }

  Future<void> _loadOfflineOutletCount() async {
    final count = await OfflineStorageService.getOfflineOutletCount();
    setState(() {
      _offlineOutletCount = count;
    });
  }

  @override
  void dispose() {
    _outletNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _ownerNameController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show image source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Select Image Source'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: Colors.green,
                    ),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
      );

      if (source != null) {
        try {
          final XFile? image = await picker.pickImage(
            source: source,
            maxWidth: 1080,
            maxHeight: 1080,
            imageQuality: 85,
          );

          if (image != null) {
            setState(() {
              _outletImage = File(image.path);
            });
            _showSnackBar('Image selected successfully!');
          }
        } on PlatformException catch (e) {
          if (e.code == 'camera_access_denied') {
            _showSnackBar(
              'Camera access denied. Please enable camera permission in settings.',
              isError: true,
            );
          } else if (e.code == 'photo_access_denied') {
            _showSnackBar(
              'Photo access denied. Please enable photo permission in settings.',
              isError: true,
            );
          } else {
            _showSnackBar('Failed to pick image: ${e.message}', isError: true);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error accessing image picker: $e', isError: true);
    }
  }

  Future<String?> _uploadImageToStorage(String outletId) async {
    if (_outletImage == null) return null;

    try {
      // Create a unique filename with timestamp
      final String fileName =
          'outlet_${outletId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Create storage reference
      final Reference storageRef = _storage
          .ref()
          .child('owners')
          .child(ownerId)
          .child('businesses')
          .child(businessId)
          .child('outlets')
          .child(outletId)
          .child('images')
          .child(fileName);

      // Upload file with progress tracking
      final UploadTask uploadTask = storageRef.putFile(_outletImage!);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Wait for upload completion
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      _showSnackBar('Error uploading image: $e', isError: true);
      return null;
    }
  }

  Future<String?> _convertImageToBase64() async {
    if (_outletImage == null) return null;

    try {
      final Uint8List imageBytes = await _outletImage!.readAsBytes();
      return base64Encode(imageBytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      // TODO: Implement location service integration
      // For now, showing demo coordinates
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _latitudeController.text = '6.0535'; // Matara, Sri Lanka demo
        _longitudeController.text = '80.5550';
      });

      _showSnackBar('Location updated successfully!');
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
    } finally {
      setState(() => _isLocationLoading = false);
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

  Future<void> _saveOutletOffline() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate unique ID
      final String outletId = DateTime.now().millisecondsSinceEpoch.toString();

      // Convert image to base64 for offline storage
      String? imageBase64;
      if (_outletImage != null) {
        imageBase64 = await _convertImageToBase64();
      }

      // Create offline outlet data
      final offlineOutlet = OfflineOutletData(
        id: outletId,
        outletName: _outletNameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        latitude: double.tryParse(_latitudeController.text) ?? 0.0,
        longitude: double.tryParse(_longitudeController.text) ?? 0.0,
        ownerName: _ownerNameController.text.trim(),
        outletType: _selectedOutletType,
        imageBase64: imageBase64,
        imagePath: _outletImage?.path,
        createdAt: DateTime.now(),
        businessId: businessId,
        ownerId: ownerId,
      );

      // Save to offline storage
      await OfflineStorageService.saveOfflineOutlet(offlineOutlet);

      _showSnackBar(
        'Outlet saved offline successfully! Will sync when online.',
      );

      // Update offline count
      await _loadOfflineOutletCount();

      // Clear form
      _clearForm();

      // Navigate back after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, offlineOutlet.toJson());
      }
    } catch (e) {
      print('Error saving outlet offline: $e');
      _showSnackBar('Error saving outlet offline: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOutletOnline() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Generate a unique document ID for the outlet
      final DocumentReference outletRef =
          _firestore
              .collection('owners')
              .doc(ownerId)
              .collection('businesses')
              .doc(businessId)
              .collection('customers')
              .doc();

      final String outletId = outletRef.id;

      // Upload image to Firebase Storage (if selected)
      String? imageUrl;
      if (_outletImage != null) {
        _showSnackBar('Uploading image...');
        imageUrl = await _uploadImageToStorage(outletId);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Prepare outlet data
      final DateTime now = DateTime.now();
      final Map<String, dynamic> outletData = {
        'id': outletId,
        'outletName': _outletNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'coordinates': {
          'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
          'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        },
        'ownerName': _ownerNameController.text.trim(),
        'outletType': _selectedOutletType,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.fromDate(now),
        'registeredDate': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isActive': true,
        'businessId': businessId,
        'ownerId': ownerId,
      };

      // Save to Firestore
      _showSnackBar('Saving outlet data...');
      await outletRef.set(outletData);

      // Update business document with outlet count (optional)
      try {
        final DocumentReference businessRef = _firestore
            .collection('owners')
            .doc(ownerId)
            .collection('businesses')
            .doc(businessId);

        await _firestore.runTransaction((transaction) async {
          final DocumentSnapshot businessDoc = await transaction.get(
            businessRef,
          );

          if (businessDoc.exists) {
            final Map<String, dynamic> businessData =
                businessDoc.data() as Map<String, dynamic>;
            final int currentOutletCount = businessData['outletCount'] ?? 0;

            transaction.update(businessRef, {
              'outletCount': currentOutletCount + 1,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
          }
        });
      } catch (e) {
        print('Error updating business outlet count: $e');
      }

      print('Outlet saved successfully: $outletData');
      _showSnackBar('Outlet added successfully!');

      // Clear form
      _clearForm();

      // Navigate back after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, outletData);
      }
    } catch (e) {
      print('Error saving outlet: $e');
      _showSnackBar('Error saving outlet: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _uploadOfflineData() async {
    setState(() => _isUploadingOfflineData = true);

    try {
      final offlineOutlets = await OfflineStorageService.getOfflineOutlets();

      if (offlineOutlets.isEmpty) {
        _showSnackBar('No offline data to upload');
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < offlineOutlets.length; i++) {
        final outlet = offlineOutlets[i];

        try {
          // Create Firestore document
          final DocumentReference outletRef =
              _firestore
                  .collection('owners')
                  .doc(outlet.ownerId)
                  .collection('businesses')
                  .doc(outlet.businessId)
                  .collection('customers')
                  .doc();

          final String firestoreId = outletRef.id;

          // Upload image if exists
          String? imageUrl;
          if (outlet.imageBase64 != null) {
            try {
              final Uint8List imageBytes = base64Decode(outlet.imageBase64!);

              final String fileName =
                  'outlet_${firestoreId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

              final Reference storageRef = _storage
                  .ref()
                  .child('owners')
                  .child(outlet.ownerId)
                  .child('businesses')
                  .child(outlet.businessId)
                  .child('outlets')
                  .child(firestoreId)
                  .child('images')
                  .child(fileName);

              final UploadTask uploadTask = storageRef.putData(imageBytes);
              final TaskSnapshot snapshot = await uploadTask;
              imageUrl = await snapshot.ref.getDownloadURL();
            } catch (e) {
              print('Error uploading image for outlet ${outlet.id}: $e');
            }
          }

          // Prepare outlet data for Firestore
          final Map<String, dynamic> outletData = {
            'id': firestoreId,
            'outletName': outlet.outletName,
            'address': outlet.address,
            'phoneNumber': outlet.phoneNumber,
            'coordinates': {
              'latitude': outlet.latitude,
              'longitude': outlet.longitude,
            },
            'ownerName': outlet.ownerName,
            'outletType': outlet.outletType,
            'imageUrl': imageUrl,
            'createdAt': Timestamp.fromDate(outlet.createdAt),
            'registeredDate': Timestamp.fromDate(outlet.createdAt),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'isActive': true,
            'businessId': outlet.businessId,
            'ownerId': outlet.ownerId,
          };

          // Save to Firestore
          await outletRef.set(outletData);

          // Remove from offline storage
          await OfflineStorageService.removeOfflineOutlet(outlet.id);

          successCount++;

          // Update progress
          setState(() {
            _uploadProgress = (i + 1) / offlineOutlets.length;
          });
        } catch (e) {
          print('Error uploading outlet ${outlet.id}: $e');
          failCount++;
        }
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

  Future<void> _saveOutlet() async {
    if (_isConnected) {
      await _saveOutletOnline();
    } else {
      await _saveOutletOffline();
    }
  }

  void _clearForm() {
    _outletNameController.clear();
    _addressController.clear();
    _phoneController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _ownerNameController.clear();
    setState(() {
      _selectedOutletType = 'Retail';
      _outletImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        title: const Text(
          'Add New Outlet',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_offlineOutletCount > 0 && _isConnected)
            IconButton(
              onPressed: _isUploadingOfflineData ? null : _uploadOfflineData,
              icon: Stack(
                children: [
                  const Icon(Icons.cloud_upload),
                  if (_offlineOutletCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_offlineOutletCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Upload $_offlineOutletCount offline outlets',
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status
                if (!_isConnected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offline Mode',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Data will be saved locally and synced when online',
                                style: TextStyle(
                                  color: Colors.orange.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Offline data upload progress
                if (_isUploadingOfflineData)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sync,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Syncing offline data... ${(_uploadProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.blue.shade700,
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
                    ),
                  ),

                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_business,
                          color: Colors.green.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Outlet Registration',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _isConnected
                                  ? 'Fill in the details below'
                                  : 'Data will be saved offline',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    _isConnected
                                        ? Colors.grey
                                        : Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_offlineOutletCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_offlineOutletCount pending',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Progress indicator for upload
                if (_isLoading && _uploadProgress > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Uploading image... ${(_uploadProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.blue.shade700,
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
                    ),
                  ),

                // Basic Information Section
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _outletNameController,
                  label: 'Outlet Name',
                  hint: 'Enter outlet name',
                  icon: Icons.store,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Outlet name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter complete address',
                  icon: Icons.location_on,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Address is required';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter phone number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Phone number is required';
                    }
                    if (value!.length < 10) return 'Enter valid phone number';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Location Section
                _buildSectionTitle('Location Coordinates'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _latitudeController,
                        label: 'Latitude',
                        hint: 'e.g., 6.0535',
                        icon: Icons.my_location,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Latitude is required';
                          }
                          if (double.tryParse(value!) == null) {
                            return 'Enter valid latitude';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _longitudeController,
                        label: 'Longitude',
                        hint: 'e.g., 80.5550',
                        icon: Icons.explore,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Longitude is required';
                          }
                          if (double.tryParse(value!) == null) {
                            return 'Enter valid longitude';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Get Current Location Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLocationLoading ? null : _getCurrentLocation,
                    icon:
                        _isLocationLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.gps_fixed),
                    label: Text(
                      _isLocationLoading
                          ? 'Getting Location...'
                          : 'Get Current Location',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.green.shade600),
                      foregroundColor: Colors.green.shade600,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Owner Information Section
                _buildSectionTitle('Owner Information'),
                const SizedBox(height: 16),

                // Owner Name Field with Custom Capitalization
                TextFormField(
                  controller: _ownerNameController,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [CapitalizationTextInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Owner Name',
                    hintText: 'Enter owner\'s full name',
                    prefixIcon: Icon(Icons.person, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green.shade600,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.red.shade400,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Owner name is required';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Outlet Type Section
                _buildSectionTitle('Outlet Type'),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedOutletType,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                      ),
                      iconSize: 24,
                      elevation: 16,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 16,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedOutletType = newValue!;
                        });
                      },
                      items:
                          _outletTypes.map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            IconData icon;
                            Color color;
                            switch (value) {
                              case 'Retail':
                                icon = Icons.shopping_bag;
                                color = Colors.blue;
                                break;
                              case 'Wholesale':
                                icon = Icons.warehouse;
                                color = Colors.orange;
                                break;
                              case 'Hotel':
                                icon = Icons.hotel;
                                color = Colors.purple;
                                break;
                              case 'Customer':
                                icon = Icons.person;
                                color = Colors.green;
                                break;
                              default:
                                icon = Icons.store;
                                color = Colors.grey;
                            }

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 20),
                                  const SizedBox(width: 12),
                                  Text(value),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Image Section
                _buildSectionTitle('Outlet Image'),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _outletImage != null
                                ? Colors.green.shade600
                                : Colors.grey.shade300,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child:
                        _outletImage != null
                            ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    _outletImage!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap:
                                        () =>
                                            setState(() => _outletImage = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to add outlet image',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Camera or Gallery',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading || _isUploadingOfflineData
                            ? null
                            : _saveOutlet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isConnected
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child:
                        _isLoading
                            ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Saving...'),
                              ],
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isConnected ? Icons.save : Icons.save_alt,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isConnected ? 'Save Outlet' : 'Save Offline',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),

                // Upload offline data button
                if (_offlineOutletCount > 0 && _isConnected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed:
                          _isUploadingOfflineData ? null : _uploadOfflineData,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blue.shade600),
                        foregroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isUploadingOfflineData
                              ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Syncing...'),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_upload, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Upload $_offlineOutletCount Offline Outlets',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
