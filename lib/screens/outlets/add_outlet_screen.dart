// lib/screens/outlets/add_outlet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../services/local/database_service.dart';

// Import your existing models and services
import '../../models/user_session.dart';
import '../../providers/auth_provider.dart';

class AddOutletScreen extends StatefulWidget {
  const AddOutletScreen({super.key});

  @override
  State<AddOutletScreen> createState() => _AddOutletScreenState();
}

class _AddOutletScreenState extends State<AddOutletScreen>
    with TickerProviderStateMixin {
  // Form & Controllers
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _outletNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _ownerNameController = TextEditingController();

  // State Variables
  String _selectedOutletType = 'Retail';
  File? _outletImage;
  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isConnected = true;
  double _uploadProgress = 0.0;
  int _offlineOutletCount = 0;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Outlet Types
  final List<String> _outletTypes = [
    'Retail',
    'Wholesale',
    'Hotel',
    'Restaurant',
    'Supermarket',
    'Pharmacy',
    'Other',
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = !connectivityResult.contains(ConnectivityResult.none);
    });
  }

  void _listenToConnectivityChanges() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      setState(() {
        _isConnected = !results.contains(ConnectivityResult.none);
      });
      if (_isConnected) {
        _loadOfflineOutletCount();
      }
    });
  }

  Future<void> _loadOfflineOutletCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOutlets = prefs.getStringList('offline_outlets') ?? [];
      setState(() {
        _offlineOutletCount = offlineOutlets.length;
      });
    } catch (e) {
      print('Error loading offline outlet count: $e');
    }
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
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(position: _slideAnimation, child: _buildBody()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Add New Outlet',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: Color(0xFF666666),
          ),
        ),
      ),
      actions: [
        if (!_isConnected)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 14, color: Colors.orange[700]),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connectivity Status Card
            if (!_isConnected || _offlineOutletCount > 0) ...[
              _buildStatusCard(),
              const SizedBox(height: 24),
            ],

            // Image Upload Section
            _buildImageSection(),
            const SizedBox(height: 32),

            // Basic Information
            _buildSectionTitle('Basic Information', Icons.info_outline),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _outletNameController,
              label: 'Outlet Name',
              hint: 'Enter outlet name',
              icon: Icons.store_outlined,
              validator:
                  (value) =>
                      value?.trim().isEmpty ?? true
                          ? 'Outlet name is required'
                          : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              hint: 'Enter complete address',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              validator:
                  (value) =>
                      value?.trim().isEmpty ?? true
                          ? 'Address is required'
                          : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Phone number is required';
                }
                if (value!.length < 10) {
                  return 'Enter valid phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Location Section
            _buildSectionTitle('Location', Icons.my_location_outlined),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _latitudeController,
                    label: 'Latitude',
                    hint: 'e.g., 6.0535',
                    icon: Icons.place_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Required';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Invalid';
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
                    icon: Icons.explore_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Required';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationButton(),

            const SizedBox(height: 32),

            // Owner & Type Section
            _buildSectionTitle('Owner Information', Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ownerNameController,
              label: 'Owner Name',
              hint: 'Enter owner name',
              icon: Icons.person_outlined,
              validator:
                  (value) =>
                      value?.trim().isEmpty ?? true
                          ? 'Owner name is required'
                          : null,
            ),
            const SizedBox(height: 16),
            _buildOutletTypeDropdown(),

            const SizedBox(height: 40),

            // Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              _isConnected
                  ? [Colors.blue[50]!, Colors.blue[100]!]
                  : [Colors.orange[50]!, Colors.orange[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected ? Colors.blue[200]! : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: _isConnected ? Colors.blue[700] : Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isConnected ? 'Online Mode' : 'Offline Mode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isConnected ? Colors.blue[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected
                ? 'Data will be saved directly to Firebase'
                : 'Data will be saved locally and synced when online',
            style: TextStyle(
              fontSize: 14,
              color: _isConnected ? Colors.blue[600] : Colors.orange[600],
            ),
          ),
          if (_offlineOutletCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '$_offlineOutletCount outlets pending sync',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_outletImage != null) ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.file(
                _outletImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_outletImage == null) ...[
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Outlet Photo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Fixed button layout to prevent overflow
                if (_outletImage == null) ...[
                  // No image: Show Camera and Gallery side by side
                  Row(
                    children: [
                      Expanded(
                        child: _buildImageButton(
                          label: 'Camera',
                          icon: Icons.camera_alt_outlined,
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildImageButton(
                          label: 'Gallery',
                          icon: Icons.photo_library_outlined,
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Image selected: Stack buttons vertically to prevent overflow
                  Column(
                    children: [
                      // First row: Camera and Gallery
                      Row(
                        children: [
                          Expanded(
                            child: _buildImageButton(
                              label: 'Camera',
                              icon: Icons.camera_alt_outlined,
                              onTap: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildImageButton(
                              label: 'Gallery',
                              icon: Icons.photo_library_outlined,
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Second row: Remove button (full width)
                      SizedBox(
                        width: double.infinity,
                        child: _buildImageButton(
                          label: 'Remove Photo',
                          icon: Icons.delete_outline,
                          onTap: () => setState(() => _outletImage = null),
                          isDelete: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isDelete = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isDelete ? Colors.red[50] : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDelete ? Colors.red[200]! : Colors.blue[200]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Added to prevent overflow
          children: [
            Icon(
              icon,
              size: 18,
              color: isDelete ? Colors.red[600] : Colors.blue[600],
            ),
            const SizedBox(width: 8),
            Flexible(
              // Changed from Text to Flexible to handle overflow
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDelete ? Colors.red[600] : Colors.blue[600],
                ),
                overflow: TextOverflow.ellipsis, // Handle text overflow
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 16, color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationButton() {
    return SizedBox(
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
                : const Icon(Icons.my_location, size: 18),
        label: Text(
          _isLocationLoading ? 'Getting Location...' : 'Get Current Location',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue[600],
          side: BorderSide(color: Colors.blue[200]!, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildOutletTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Outlet Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedOutletType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              Icons.category_outlined,
              color: Colors.grey[500],
              size: 20,
            ),
          ),
          items:
              _outletTypes.map((String type) {
                return DropdownMenuItem<String>(value: type, child: Text(type));
              }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedOutletType = newValue;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Save Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveOutlet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      _isConnected ? 'Save Outlet' : 'Save Offline',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),

        // Progress indicator for upload
        if (_isLoading && _uploadProgress > 0) ...[
          const SizedBox(height: 16),
          Column(
            children: [
              Text(
                'Uploading... ${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.blue[100],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Methods
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _outletImage = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      _showSnackBar('Location updated successfully!');
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
    } finally {
      setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _saveOutlet() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_isConnected) {
      await _saveOutletOnline();
    } else {
      await _saveOutletOffline();
    }
  }

  Future<void> _saveOutletOnline() async {
    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userSession = authProvider.currentSession;

      if (userSession == null) {
        throw Exception('User session not found');
      }

      // Generate outlet ID
      final outletRef =
          _firestore
              .collection('owners')
              .doc(userSession.ownerId)
              .collection('businesses')
              .doc(userSession.businessId)
              .collection('customers')
              .doc();

      // Upload image if selected
      String? imageUrl;
      if (_outletImage != null) {
        imageUrl = await _uploadImageToFirebase(outletRef.id, userSession);
      }

      // Create outlet data
      final DateTime now = DateTime.now();
      final outletData = {
        'id': outletRef.id,
        'outletName': _outletNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'coordinates': {
          'latitude': double.parse(_latitudeController.text),
          'longitude': double.parse(_longitudeController.text),
        },
        'ownerName': _ownerNameController.text.trim(),
        'outletType': _selectedOutletType,
        'imageUrl': imageUrl,
        'ownerId': userSession.ownerId,
        'businessId': userSession.businessId,
        'createdBy': userSession.employeeId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await outletRef.set(outletData);

      _showSnackBar('Outlet saved successfully!');
      _clearForm();

      // Navigate back after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Error saving outlet: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOutletOffline() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userSession = authProvider.currentSession;

      if (userSession == null) {
        throw Exception('User session not found');
      }

      // Generate unique ID
      final String outletId = DateTime.now().millisecondsSinceEpoch.toString();

      // Convert image to base64 for offline storage
      String? imageBase64;
      if (_outletImage != null) {
        final Uint8List imageBytes = await _outletImage!.readAsBytes();
        imageBase64 = base64Encode(imageBytes);
      }

      // Create offline outlet data
      final offlineOutletData = {
        'id': outletId,
        'outletName': _outletNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'latitude': double.parse(_latitudeController.text),
        'longitude': double.parse(_longitudeController.text),
        'ownerName': _ownerNameController.text.trim(),
        'outletType': _selectedOutletType,
        'imageBase64': imageBase64,
        'imagePath': _outletImage?.path,
        'ownerId': userSession.ownerId,
        'businessId': userSession.businessId,
        'createdBy': userSession.employeeId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'syncStatus': 'pending',
      };

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineOutlets =
          prefs.getStringList('offline_outlets') ?? [];
      offlineOutlets.add(jsonEncode(offlineOutletData));
      await prefs.setStringList('offline_outlets', offlineOutlets);

      // Also save to local database if available
      try {
        final dbService = DatabaseService();
        await dbService.insertOutlet(offlineOutletData);
      } catch (e) {
        print('Error saving to local database: $e');
        // Continue with SharedPreferences backup
      }

      _showSnackBar('Outlet saved offline! Will sync when online.');
      await _loadOfflineOutletCount();
      _clearForm();

      // Navigate back after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Error saving outlet offline: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImageToFirebase(
    String outletId,
    UserSession userSession,
  ) async {
    if (_outletImage == null) return null;

    try {
      setState(() => _uploadProgress = 0.1);

      final String fileName =
          'outlet_${outletId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage
          .ref()
          .child('owners')
          .child(userSession.ownerId)
          .child('businesses')
          .child(userSession.businessId)
          .child('outlets')
          .child(outletId)
          .child('images')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(_outletImage!);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
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
      _uploadProgress = 0.0;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}
