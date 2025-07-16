// lib/dialogs/payment_method_dialog.dart (Fixed Version - No Overflow)
import 'package:flutter/material.dart';

class PaymentMethodDialog extends StatefulWidget {
  final String? initialSelection;
  final Function(String) onConfirm;

  const PaymentMethodDialog({
    super.key,
    this.initialSelection,
    required this.onConfirm,
  });

  static Future<String?> show(
    BuildContext context, {
    String? currentSelection,
  }) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PaymentMethodDialog(
            initialSelection: currentSelection,
            onConfirm: (paymentType) {
              Navigator.of(context).pop(paymentType);
            },
          ),
    );
  }

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog>
    with SingleTickerProviderStateMixin {
  String? _selectedPaymentType;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<PaymentMethodOption> _paymentMethods = [
    PaymentMethodOption(
      type: 'cash',
      label: 'Cash Payment',
      icon: Icons.payments,
      color: Colors.green,
      description: 'Immediate payment in cash',
    ),
    PaymentMethodOption(
      type: 'credit',
      label: 'Credit Payment',
      icon: Icons.credit_card,
      color: Colors.orange,
      description: 'Payment on credit terms',
    ),
    PaymentMethodOption(
      type: 'cheque',
      label: 'Cheque Payment',
      icon: Icons.receipt_long,
      color: Colors.purple,
      description: 'Payment by bank cheque',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPaymentType = widget.initialSelection;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.8, // Maximum 80% of screen height
                  maxWidth: screenWidth * 0.9, // Maximum 90% of screen width
                  minWidth: 300, // Minimum width
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.blue.shade50, Colors.white],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      // FIXED: Make the main content scrollable
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPaymentOptions(),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20), // Reduced padding from 24 to 20
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8), // Reduced from 12 to 8
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payment,
              size: 28, // Reduced from 32 to 28
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16 to 12
          // Title
          const Text(
            'Select Payment Method',
            style: TextStyle(
              fontSize: 20, // Reduced from 22 to 20
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6), // Reduced from 8 to 6
          // Subtitle
          Text(
            'Choose how the customer will pay for this bill',
            style: TextStyle(
              fontSize: 13, // Reduced from 14 to 13
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Padding(
      padding: const EdgeInsets.all(16), // Reduced from 20 to 16
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            _paymentMethods.map((method) {
              final isSelected = _selectedPaymentType == method.type;

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ), // Reduced from 12 to 10
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentType = method.type;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(14), // Reduced from 16 to 14
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? method.color.withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? method.color : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: method.color.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                    ),
                    child: Row(
                      children: [
                        // Icon container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(
                            10,
                          ), // Reduced from 12 to 10
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? method.color.withValues(alpha: 0.2)
                                    : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            method.icon,
                            size: 24, // Reduced from 28 to 24
                            color:
                                isSelected
                                    ? method.color
                                    : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 14), // Reduced from 16 to 14
                        // Payment method info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method.label,
                                style: TextStyle(
                                  fontSize: 15, // Reduced from 16 to 15
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isSelected
                                          ? method.color
                                          : Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 3), // Reduced from 4 to 3
                              Text(
                                method.description,
                                style: TextStyle(
                                  fontSize: 12, // Reduced from 13 to 12
                                  color:
                                      isSelected
                                          ? method.color.withValues(alpha: 0.8)
                                          : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Selection indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 22, // Reduced from 24 to 22
                          height: 22, // Reduced from 24 to 22
                          decoration: BoxDecoration(
                            color:
                                isSelected ? method.color : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? method.color
                                      : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child:
                              isSelected
                                  ? const Icon(
                                    Icons.check,
                                    size: 14, // Reduced from 16 to 14
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced from 20 to 16
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ), // Reduced from 16 to 14
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15, // Reduced from 16 to 15
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Confirm button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed:
                  _selectedPaymentType != null
                      ? () => widget.onConfirm(_selectedPaymentType!)
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedPaymentType != null
                        ? _getSelectedMethodColor()
                        : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ), // Reduced from 16 to 14
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _selectedPaymentType != null ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                  ), // Reduced from 20 to 18
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _selectedPaymentType != null
                          ? 'Confirm ${_getSelectedMethodLabel()}'
                          : 'Select Payment Method',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15, // Reduced from 16 to 15
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSelectedMethodColor() {
    if (_selectedPaymentType == null) return Colors.grey;
    return _paymentMethods
        .firstWhere((method) => method.type == _selectedPaymentType)
        .color;
  }

  String _getSelectedMethodLabel() {
    if (_selectedPaymentType == null) return '';
    return _paymentMethods
        .firstWhere((method) => method.type == _selectedPaymentType)
        .type
        .toUpperCase();
  }
}

// Payment Method Option Model
class PaymentMethodOption {
  final String type;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const PaymentMethodOption({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}
