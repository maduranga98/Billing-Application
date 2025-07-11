// lib/screens/reports/daily_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/billing/billing_service.dart';
import '../../models/user_session.dart';
import '../../models/bill.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _summaryData;
  Map<String, ItemSummary> _itemSummaries = {};

  @override
  void initState() {
    super.initState();
    // Ensure we start with today's date only (no time component)
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _loadDailySummary();
  }

  Future<void> _loadDailySummary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final session = authProvider.currentSession;

      if (session == null) {
        throw Exception('No active session');
      }

      // Get daily summary
      final summaryData = await BillingService.getDailySummary(
        session,
        _selectedDate,
      );
      final bills = summaryData['bills'] as List<Bill>;

      // Calculate item summaries
      final itemSummaries = await _calculateItemSummaries(bills, session);

      setState(() {
        _summaryData = summaryData;
        _itemSummaries = itemSummaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading summary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, ItemSummary>> _calculateItemSummaries(
    List<Bill> bills,
    UserSession session,
  ) async {
    final Map<String, ItemSummary> itemSummaries = {};

    for (final bill in bills) {
      try {
        // Get bill items for each bill
        final billItems = await BillingService.getBillItems(bill.id, session);

        for (final item in billItems) {
          final key = item.productCode;

          if (itemSummaries.containsKey(key)) {
            // Update existing summary
            final existing = itemSummaries[key]!;
            itemSummaries[key] = ItemSummary(
              productCode: existing.productCode,
              productName: existing.productName,
              totalQuantity: existing.totalQuantity + item.quantity,
              totalValue: existing.totalValue + item.totalPrice,
              averagePrice: 0, // Will calculate after
            );
          } else {
            // Create new summary
            itemSummaries[key] = ItemSummary(
              productCode: item.productCode,
              productName: item.productName,
              totalQuantity: item.quantity,
              totalValue: item.totalPrice,
              averagePrice: 0, // Will calculate after
            );
          }
        }
      } catch (e) {
        print('Error processing bill ${bill.id}: $e');
      }
    }

    // Calculate average prices
    for (final entry in itemSummaries.entries) {
      final summary = entry.value;
      if (summary.totalQuantity > 0) {
        itemSummaries[entry.key] = ItemSummary(
          productCode: summary.productCode,
          productName: summary.productName,
          totalQuantity: summary.totalQuantity,
          totalValue: summary.totalValue,
          averagePrice:
              summary.totalValue /
              (summary.totalQuantity * 25), // Assuming 25kg bags
        );
      }
    }

    return itemSummaries;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        // Normalize the picked date to remove time component
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      _loadDailySummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple.shade800,
        foregroundColor: Colors.white,
        title: Text(
          _selectedDate.year == DateTime.now().year &&
                  _selectedDate.month == DateTime.now().month &&
                  _selectedDate.day == DateTime.now().day
              ? 'Today\'s Summary'
              : 'Daily Summary',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date',
          ),
          IconButton(
            onPressed: _loadDailySummary,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _summaryData == null
              ? _buildErrorState()
              : RefreshIndicator(
                onRefresh: _loadDailySummary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateHeader(),
                      const SizedBox(height: 16),
                      _buildOverviewCards(),
                      const SizedBox(height: 24),
                      _buildItemsSummary(),
                      const SizedBox(height: 24),
                      _buildPaymentBreakdown(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDailySummary,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final isToday =
        _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isToday ? 'Today\'s Sales Summary' : 'Sales Summary',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    if (_summaryData == null) return const SizedBox.shrink();

    final totalBills = _summaryData!['totalBills'] as int;
    final totalRevenue = _summaryData!['totalRevenue'] as double;

    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            title: 'Total Bills',
            value: totalBills.toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildOverviewCard(
            title: 'Total Revenue',
            value: 'Rs.${NumberFormat('#,##0.00').format(totalRevenue)}',
            icon: Icons.attach_money,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        if (_itemSummaries.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No items sold today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Header Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Product',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Quantity',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Total Value',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Item Rows
                ...(_itemSummaries.entries.toList()..sort(
                      (a, b) =>
                          b.value.totalValue.compareTo(a.value.totalValue),
                    ))
                    .map((entry) => _buildItemRow(entry.value)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemRow(ItemSummary item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.productCode,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.totalQuantity} bags',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Rs.${NumberFormat('#,##0.00').format(item.totalValue)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    if (_summaryData == null) return const SizedBox.shrink();

    final totalSale = _summaryData!['totalRevenue'] as double;
    final totalCash = _summaryData!['totalCash'] as double;
    final totalCredit = _summaryData!['totalCredit'] as double;
    final totalCheque = _summaryData!['totalCheque'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildPaymentRow(
                'Total Sale',
                totalSale,
                Colors.blue,
                isTotal: true,
              ),
              _buildPaymentRow('Cash Payments', totalCash, Colors.green),
              _buildPaymentRow('Credit Payments', totalCredit, Colors.orange),
              _buildPaymentRow(
                'Cheque Payments',
                totalCheque,
                Colors.purple,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(
    String label,
    double amount,
    Color color, {
    bool isTotal = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTotal ? color.withOpacity(0.05) : null,
        border: Border(
          bottom:
              isLast
                  ? BorderSide.none
                  : BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Text(
            'Rs.${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for item summaries
class ItemSummary {
  final String productCode;
  final String productName;
  final int totalQuantity;
  final double totalValue;
  final double averagePrice;

  ItemSummary({
    required this.productCode,
    required this.productName,
    required this.totalQuantity,
    required this.totalValue,
    required this.averagePrice,
  });
}
