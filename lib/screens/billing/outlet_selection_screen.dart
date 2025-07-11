// lib/screens/billing/outlet_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/outlet.dart';

class OutletSelectionScreen extends StatefulWidget {
  const OutletSelectionScreen({super.key});

  @override
  State<OutletSelectionScreen> createState() => _OutletSelectionScreenState();
}

class _OutletSelectionScreenState extends State<OutletSelectionScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AuthProvider>();
    final billingProvider = context.read<BillingProvider>();

    if (authProvider.currentSession != null) {
      await billingProvider.initializeBilling(authProvider.currentSession!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          'Select Outlet',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search outlets...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Outlets List
          Expanded(
            child: Consumer<BillingProvider>(
              builder: (context, billingProvider, child) {
                if (billingProvider.isLoadingOutlets) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredOutlets =
                    billingProvider.availableOutlets
                        .where(
                          (outlet) =>
                              outlet.outletName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              outlet.address.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              outlet.ownerName.toLowerCase().contains(
                                _searchQuery,
                              ),
                        )
                        .toList();

                if (filteredOutlets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No outlets available'
                              : 'No outlets found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchQuery.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Add outlets to start billing',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOutlets.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final outlet = filteredOutlets[index];
                    return _buildOutletCard(outlet);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard(Outlet outlet) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectOutlet(outlet),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Outlet Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getOutletTypeColor(
                    outlet.outletType,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getOutletTypeIcon(outlet.outletType),
                  color: _getOutletTypeColor(outlet.outletType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Outlet Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outlet.outletName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outlet.ownerName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      outlet.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (outlet.phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        outlet.phoneNumber,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectOutlet(Outlet outlet) {
    final billingProvider = context.read<BillingProvider>();
    billingProvider.selectOutlet(outlet);

    Navigator.pushNamed(context, '/billing/items');
  }

  IconData _getOutletTypeIcon(String outletType) {
    switch (outletType.toLowerCase()) {
      case 'retail':
        return Icons.shopping_bag;
      case 'wholesale':
        return Icons.warehouse;
      case 'hotel':
        return Icons.hotel;
      case 'customer':
        return Icons.person;
      default:
        return Icons.store;
    }
  }

  Color _getOutletTypeColor(String outletType) {
    switch (outletType.toLowerCase()) {
      case 'retail':
        return Colors.blue;
      case 'wholesale':
        return Colors.orange;
      case 'hotel':
        return Colors.purple;
      case 'customer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
