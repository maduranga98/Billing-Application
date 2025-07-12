// lib/screens/outlets/add_outlet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import '../../models/outlet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outlet_provider.dart';

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

class AddOutlet extends StatefulWidget {
  final Outlet? outlet; // For editing existing outlet
  final String routeName, routeId;
  const AddOutlet({
    super.key,
    this.outlet,
    required this.routeName,
    required this.routeId,
  });

  @override
  State<AddOutlet> createState() => _AddOutletState();
}

class _AddOutletState extends State<AddOutlet> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

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
  bool _isLocationLoading = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Outlet Type Options
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
    _initializeForm();
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

  void _initializeForm() {
    if (widget.outlet != null) {
      // Pre-fill form for editing
      final outlet = widget.outlet!;
      _outletNameController.text = outlet.outletName;
      _addressController.text = outlet.address;
      _phoneController.text = outlet.phoneNumber;
      _latitudeController.text = outlet.latitude.toString();
      _longitudeController.text = outlet.longitude.toString();
      _ownerNameController.text = outlet.ownerName;
      _selectedOutletType = outlet.outletType;
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

  Future<void> _saveOutlet() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final outletProvider = Provider.of<OutletProvider>(context, listen: false);

    if (authProvider.currentSession == null) {
      _showSnackBar('No user session found', isError: true);
      return;
    }

    final userSession = authProvider.currentSession!;

    try {
      // Convert image to base64 for storage
      String? imageBase64;
      if (_outletImage != null) {
        imageBase64 = await _convertImageToBase64();
      }

      // Create outlet object
      final outlet = Outlet(
        id: widget.outlet?.id ?? '', // Will be generated by service
        outletName: _outletNameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        latitude: double.tryParse(_latitudeController.text) ?? 0.0,
        longitude: double.tryParse(_longitudeController.text) ?? 0.0,
        ownerName: _ownerNameController.text.trim(),
        outletType: _selectedOutletType,
        imageUrl: widget.outlet?.imageUrl,
        ownerId: userSession.ownerId,
        businessId: userSession.businessId,
        createdBy: userSession.employeeId,
        routeId: widget.routeId,
        routeName: widget.routeName,
        isActive: true,
        createdAt: widget.outlet?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;

      if (widget.outlet != null) {
        // Update existing outlet
        final updates = <String, dynamic>{
          'outletName': outlet.outletName,
          'address': outlet.address,
          'phoneNumber': outlet.phoneNumber,
          'coordinates': {
            'latitude': outlet.latitude,
            'longitude': outlet.longitude,
          },
          'ownerName': outlet.ownerName,
          'outletType': outlet.outletType,
        };

        // Add image if changed
        if (imageBase64 != null) {
          updates['imageBase64'] = imageBase64;
        }

        success = await outletProvider.updateOutlet(
          outletId: widget.outlet!.id,
          updates: updates,
          userSession: userSession,
        );

        if (success) {
          _showSnackBar('Outlet updated successfully!');
        }
      } else {
        // Add new outlet
        success = await outletProvider.addOutlet(
          outlet: outlet,
          userSession: userSession,
          imageBase64: imageBase64,
        );

        if (success) {
          _showSnackBar(
            outletProvider.isConnected
                ? 'Outlet added successfully!'
                : 'Outlet saved offline. Will sync when online.',
          );
        }
      }

      if (success) {
        // Clear form and navigate back
        _clearForm();
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true); // Return success
        }
      } else {
        _showSnackBar(
          outletProvider.errorMessage ?? 'Failed to save outlet',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error saving outlet: $e', isError: true);
    }
  }

  Future<void> _syncOfflineOutlets() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final outletProvider = Provider.of<OutletProvider>(context, listen: false);

    if (authProvider.currentSession == null) {
      _showSnackBar('No user session found', isError: true);
      return;
    }

    final result = await outletProvider.syncOfflineOutlets(
      authProvider.currentSession!,
    );

    if (result != null && mounted) {
      _showSnackBar(result.message, isError: !result.success);
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
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(opacity: _fadeAnimation, child: _buildBody()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.deepPurple.shade800,
      foregroundColor: Colors.white,
      title: Text(
        widget.outlet != null ? 'Edit Outlet' : 'Add New Outlet',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      actions: [
        Consumer<OutletProvider>(
          builder: (context, outletProvider, child) {
            if (outletProvider.offlineOutletCount > 0 &&
                outletProvider.isConnected) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _syncOfflineOutlets,
                  icon: Stack(
                    children: [
                      const Icon(Icons.cloud_upload, color: Colors.blue),
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
                            '${outletProvider.offlineOutletCount}',
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
                  tooltip:
                      'Sync ${outletProvider.offlineOutletCount} offline outlets',
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<OutletProvider>(
      builder: (context, outletProvider, child) {
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status
                if (!outletProvider.isConnected) _buildOfflineIndicator(),

                // Header
                _buildHeader(outletProvider),

                const SizedBox(height: 24),

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
                _buildLocationSection(),

                const SizedBox(height: 24),

                // Owner Information Section
                _buildOwnerSection(),

                const SizedBox(height: 24),

                // Outlet Type Section
                _buildOutletTypeSection(),

                const SizedBox(height: 24),

                // Image Section
                _buildImageSection(),

                const SizedBox(height: 32),

                // Save Button
                _buildSaveButton(outletProvider),

                // Sync Button
                if (outletProvider.offlineOutletCount > 0 &&
                    outletProvider.isConnected)
                  _buildSyncButton(outletProvider),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
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
          Icon(Icons.wifi_off, color: Colors.orange.shade600, size: 20),
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
                  style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(OutletProvider outletProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
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
              color: Colors.deepPurple.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.outlet != null ? Icons.edit : Icons.add_business,
              color: Colors.deepPurple.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.outlet != null
                      ? 'Edit Outlet'
                      : 'New Outlet Registration',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  outletProvider.isConnected
                      ? 'Fill in the details below'
                      : 'Data will be saved offline',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        outletProvider.isConnected
                            ? Colors.grey
                            : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (outletProvider.offlineOutletCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${outletProvider.offlineOutletCount} pending',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              side: BorderSide(color: Colors.deepPurple.shade600),
              foregroundColor: Colors.deepPurple.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Owner Information'),
        const SizedBox(height: 16),
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
                color: Colors.deepPurple.shade600,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
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
      ],
    );
  }

  Widget _buildOutletTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Outlet Type'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedOutletType,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              iconSize: 24,
              elevation: 16,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedOutletType = newValue!;
                });
              },
              items:
                  _outletTypes.map<DropdownMenuItem<String>>((String value) {
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
                      case 'Restaurant':
                        icon = Icons.restaurant;
                        color = Colors.red;
                        break;
                      case 'Supermarket':
                        icon = Icons.local_grocery_store;
                        color = Colors.green;
                        break;
                      case 'Pharmacy':
                        icon = Icons.local_pharmacy;
                        color = Colors.teal;
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
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        ? Colors.deepPurple.shade600
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
                            onTap: () => setState(() => _outletImage = null),
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
      ],
    );
  }

  Widget _buildSaveButton(OutletProvider outletProvider) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: outletProvider.isLoading ? null : _saveOutlet,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              outletProvider.isConnected
                  ? Colors.deepPurple.shade600
                  : Colors.orange.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child:
            outletProvider.isLoading
                ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      widget.outlet != null
                          ? Icons.update
                          : (outletProvider.isConnected
                              ? Icons.save
                              : Icons.save_alt),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.outlet != null
                          ? 'Update Outlet'
                          : (outletProvider.isConnected
                              ? 'Save Outlet'
                              : 'Save Offline'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildSyncButton(OutletProvider outletProvider) {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: outletProvider.isLoading ? null : _syncOfflineOutlets,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.blue.shade600),
              foregroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_upload, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sync ${outletProvider.offlineOutletCount} Offline Outlets',
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
          borderSide: BorderSide(color: Colors.deepPurple.shade600, width: 2),
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
