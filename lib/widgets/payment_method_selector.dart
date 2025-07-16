// lib/widgets/payment_method_selector.dart
import 'package:flutter/material.dart';

class PaymentMethodSelector extends StatefulWidget {
  final String? selectedPaymentType;
  final Function(String) onPaymentTypeSelected;
  final bool isRequired;
  final String? errorText;

  const PaymentMethodSelector({
    super.key,
    this.selectedPaymentType,
    required this.onPaymentTypeSelected,
    this.isRequired = true,
    this.errorText,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      type: 'cash',
      label: 'Cash',
      icon: Icons.payments,
      color: Colors.green,
      description: 'Immediate payment',
    ),
    PaymentMethod(
      type: 'credit',
      label: 'Credit',
      icon: Icons.credit_card,
      color: Colors.orange,
      description: 'Deferred payment',
    ),
    PaymentMethod(
      type: 'cheque',
      label: 'Cheque',
      icon: Icons.receipt_long,
      color: Colors.purple,
      description: 'Bank instrument',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            if (widget.isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Payment Method Cards
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  widget.errorText != null
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
              width: 1.5,
            ),
            color: Colors.grey.shade50,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _paymentMethods.length,
                itemBuilder: (context, index) {
                  final method = _paymentMethods[index];
                  final isSelected = widget.selectedPaymentType == method.type;

                  return GestureDetector(
                    onTap: () {
                      _animationController.forward().then((_) {
                        _animationController.reverse();
                      });
                      widget.onPaymentTypeSelected(method.type);
                    },
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: isSelected ? _scaleAnimation.value : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? method.color.withOpacity(0.15)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? method.color
                                        : Colors.grey.shade300,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: method.color.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                      : [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon with selection indicator
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? method.color.withOpacity(0.2)
                                            : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    method.icon,
                                    size: 24,
                                    color:
                                        isSelected
                                            ? method.color
                                            : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Label
                                Text(
                                  method.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                    color:
                                        isSelected
                                            ? method.color
                                            : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Description
                                Text(
                                  method.description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isSelected
                                            ? method.color.withOpacity(0.8)
                                            : Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                // Selection indicator
                                if (isSelected) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: method.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              // Selected Payment Info
              if (widget.selectedPaymentType != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getSelectedMethod()!.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getSelectedMethod()!.color.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: _getSelectedMethod()!.color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected: ${_getSelectedMethod()!.label} Payment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _getSelectedMethod()!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Error Text
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
              const SizedBox(width: 4),
              Text(
                widget.errorText!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  PaymentMethod? _getSelectedMethod() {
    if (widget.selectedPaymentType == null) return null;
    return _paymentMethods.firstWhere(
      (method) => method.type == widget.selectedPaymentType,
    );
  }
}

// Payment Method Model
class PaymentMethod {
  final String type;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const PaymentMethod({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

// Payment Method Bottom Sheet (for compact spaces)
class PaymentMethodBottomSheet extends StatelessWidget {
  final String? selectedPaymentType;
  final Function(String) onPaymentTypeSelected;

  const PaymentMethodBottomSheet({
    super.key,
    this.selectedPaymentType,
    required this.onPaymentTypeSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    String? currentSelection,
  }) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => PaymentMethodBottomSheet(
            selectedPaymentType: currentSelection,
            onPaymentTypeSelected: (type) {
              Navigator.of(context).pop(type);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Select Payment Method',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how the customer will pay for this bill',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Payment Methods
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PaymentMethodSelector(
              selectedPaymentType: selectedPaymentType,
              onPaymentTypeSelected: onPaymentTypeSelected,
              isRequired: false,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
