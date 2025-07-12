// lib/screens/upload/upload_data_screen.dart
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/widgets/common/loading_indicator.dart';
import 'package:provider/provider.dart';
import '../../models/user_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/unloading/unloading_service.dart';

class UploadDataScreen extends StatefulWidget {
  const UploadDataScreen({super.key});

  @override
  State<UploadDataScreen> createState() => _UploadDataScreenState();
}

class _UploadDataScreenState extends State<UploadDataScreen> {
  bool _isLoading = false;
  bool _isUploading = false;
  Map<String, dynamic>? _pendingData;
  Map<String, dynamic>? _validationResult;

  @override
  void initState() {
    super.initState();
    _loadPendingData();
  }

  Future<void> _loadPendingData() async {
    setState(() => _isLoading = true);

    try {
      final session = context.read<AuthProvider>().currentSession;
      if (session == null) return;

      final pendingData = await UnloadingService.getPendingUploadData(session);
      final validation = await UnloadingService.validateBeforeUpload(session);

      setState(() {
        _pendingData = pendingData;
        _validationResult = validation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadData() async {
    final session = context.read<AuthProvider>().currentSession;
    if (session == null) return;

    setState(() => _isUploading = true);

    try {
      final result = await UnloadingService.uploadDayData(session: session);

      if (mounted) {
        if (result['success']) {
          _showUploadSuccessDialog(result);
        } else {
          _showUploadErrorDialog(result);
        }
      }

      // Refresh data after upload attempt
      await _loadPendingData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showUploadSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text('Upload Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Bills uploaded: ${result['uploadedBills']}'),
                Text(
                  '💰 Total value: Rs.${result['details']['totalValue']?.toStringAsFixed(2)}',
                ),
                Text('📦 Unloading summary created'),
                const SizedBox(height: 8),
                const Text(
                  'Your day\'s data has been successfully uploaded to the server.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showUploadErrorDialog(Map<String, dynamic> result) {
    final errors = result['errors'] as List<String>;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text('Upload Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The following errors occurred:'),
                const SizedBox(height: 8),
                ...errors.map((error) => Text('• $error')).toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text('Upload Day Data')),
      body: _isLoading ? const LoadingIndicator() : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_pendingData == null || _validationResult == null) {
      return const Center(child: Text('Unable to load upload data'));
    }

    final hasPendingData = _pendingData!['hasPendingData'] as bool;
    final isValid = _validationResult!['isValid'] as bool;
    final errors = _validationResult!['errors'] as List<String>;
    final warnings = _validationResult!['warnings'] as List<String>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status Card
          _buildStatusCard(hasPendingData, isValid),

          const SizedBox(height: 16),

          // Pending Data Summary
          if (hasPendingData) _buildPendingDataCard(),

          const SizedBox(height: 16),

          // Validation Messages
          if (errors.isNotEmpty) _buildErrorCard(errors),
          if (warnings.isNotEmpty) _buildWarningCard(warnings),

          const SizedBox(height: 24),

          // Upload Button
          _buildUploadButton(hasPendingData, isValid),

          const SizedBox(height: 16),

          // Upload History Button
          _buildHistoryButton(),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool hasPendingData, bool isValid) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!hasPendingData) {
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle_outline;
      statusText = 'No pending data to upload';
    } else if (!isValid) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusText = 'Issues prevent upload';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.cloud_upload;
      statusText = 'Ready to upload';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: statusColor),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDataCard() {
    final billsCount = _pendingData!['pendingBillsCount'] as int;
    final totalValue = _pendingData!['totalPendingValue'] as double;
    final hasLoading = _pendingData!['hasLoading'] as bool;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Upload Data',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDataStatCard(
                  'Bills',
                  '$billsCount',
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDataStatCard(
                  'Total Value',
                  'Rs.${totalValue.toStringAsFixed(0)}',
                  Icons.monetization_on,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasLoading ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  hasLoading ? Icons.check_circle : Icons.warning,
                  color: hasLoading ? Colors.green[700] : Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  hasLoading
                      ? 'Loading data available'
                      : 'No loading data found',
                  style: TextStyle(
                    color: hasLoading ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorCard(List<String> errors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Errors',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...errors.map(
            (error) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $error', style: TextStyle(color: Colors.red[700])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(List<String> warnings) {
    return Container(
      width: double.infinity,
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
              Icon(Icons.warning, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Warnings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $warning',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(bool hasPendingData, bool isValid) {
    final canUpload = hasPendingData && isValid && !_isUploading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canUpload ? _uploadData : null,
        icon:
            _isUploading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : const Icon(Icons.cloud_upload),
        label: Text(
          _isUploading ? 'Uploading...' : 'Upload Day Data',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canUpload ? Colors.blue[600] : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/upload/history');
        },
        icon: const Icon(Icons.history),
        label: const Text(
          'View Upload History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
