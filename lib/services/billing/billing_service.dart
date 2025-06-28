// lib/services/billing/billing_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/bill.dart';
import '../../models/bill_item.dart';
import '../../models/selected_bill_item.dart';
import '../../models/user_session.dart';
import '../../models/outlet.dart';
import '../local/database_service.dart';
import '../loading/loading_service.dart';

class BillingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseService _dbService = DatabaseService();

  // Create a new bill
  static Future<String> createBill({
    required UserSession session,
    required Outlet outlet,
    required List<SelectedBillItem> items,
    required String paymentType,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
  }) async {
    try {
      // Generate bill ID and number
      final billId = _generateBillId();
      final billNumber = _generateBillNumber();
      final now = DateTime.now();

      // Calculate total amount
      final totalAmount =
          items.fold(0.0, (sum, item) => sum + item.totalPrice) -
          discountAmount +
          taxAmount;

      // Create bill object
      final bill = Bill(
        id: billId,
        billNumber: billNumber,
        outletId: outlet.id,
        outletName: outlet.outletName,
        outletAddress: outlet.address,
        outletPhone: outlet.phoneNumber,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        paymentType: paymentType,
        paymentStatus: paymentType == 'cash' ? 'paid' : 'pending',
        ownerId: session.ownerId,
        businessId: session.businessId,
        createdBy: session.employeeId,
        salesRepName: session.name,
        salesRepPhone: session.phone,
        createdAt: now,
        updatedAt: now,
      );

      // Create bill items
      final billItems =
          items
              .map(
                (item) => BillItem(
                  id: '${billId}_${item.productId}',
                  billId: billId,
                  productId: item.productId,
                  productName: item.productName,
                  productCode: item.productCode,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  totalPrice: item.totalPrice,
                ),
              )
              .toList();

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Create bill online
        await _createBillOnline(session, bill, billItems);
      }

      // Always save to local database
      await _createBillOffline(bill, billItems);

      // Update stock quantities
      final itemQuantities = <String, int>{};
      for (final item in items) {
        itemQuantities[item.productId] = item.quantity;
      }

      await LoadingService.updateSoldQuantities(
        session: session,
        loadingId: '', // Will be determined by LoadingService
        itemQuantities: itemQuantities,
      );

      return billId;
    } catch (e) {
      print('Error creating bill: $e');
      throw Exception('Failed to create bill: $e');
    }
  }

  // Create bill in Firebase
  static Future<void> _createBillOnline(
    UserSession session,
    Bill bill,
    List<BillItem> billItems,
  ) async {
    try {
      final batch = _firestore.batch();

      // Create bill document
      final billRef = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('bills')
          .doc(bill.id);

      batch.set(billRef, bill.toFirestore());

      // Add bill items as subcollection
      for (final item in billItems) {
        final itemRef = billRef.collection('items').doc(item.productId);
        batch.set(itemRef, item.toFirestore());
      }

      await batch.commit();
    } catch (e) {
      print('Error creating bill online: $e');
      throw e;
    }
  }

  // Create bill in local database
  static Future<void> _createBillOffline(
    Bill bill,
    List<BillItem> billItems,
  ) async {
    try {
      final billData = bill.toSQLite();
      final billItemsData = billItems.map((item) => item.toSQLite()).toList();

      await _dbService.insertBill(billData, billItemsData);
    } catch (e) {
      print('Error creating bill offline: $e');
      throw e;
    }
  }

  // Get bills for an outlet
  static Future<List<Bill>> getBillsForOutlet({
    required UserSession session,
    required String outletId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Try to get from Firebase first if online
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        return await _getBillsFromFirebase(session, outletId, fromDate, toDate);
      } else {
        return await _getBillsFromLocal(session, outletId, fromDate, toDate);
      }
    } catch (e) {
      // Fallback to local data
      return await _getBillsFromLocal(session, outletId, fromDate, toDate);
    }
  }

  // Get bills from Firebase
  static Future<List<Bill>> _getBillsFromFirebase(
    UserSession session,
    String outletId,
    DateTime? fromDate,
    DateTime? toDate,
  ) async {
    try {
      Query query = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('bills')
          .where('outletId', isEqualTo: outletId);

      if (fromDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: fromDate);
      }

      if (toDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: toDate);
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Bill(
          id: doc.id,
          billNumber: data['billNumber'],
          outletId: data['outletId'],
          outletName: data['outletName'],
          outletAddress: data['outletAddress'],
          outletPhone: data['outletPhone'],
          totalAmount: (data['totalAmount'] ?? 0).toDouble(),
          discountAmount: (data['discountAmount'] ?? 0).toDouble(),
          taxAmount: (data['taxAmount'] ?? 0).toDouble(),
          paymentType: data['paymentType'],
          paymentStatus: data['paymentStatus'],
          ownerId: data['ownerId'],
          businessId: data['businessId'],
          createdBy: data['createdBy'],
          salesRepName: data['salesRepName'],
          salesRepPhone: data['salesRepPhone'],
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: (data['updatedAt'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      print('Error getting bills from Firebase: $e');
      throw e;
    }
  }

  // Get bills from local database
  static Future<List<Bill>> _getBillsFromLocal(
    UserSession session,
    String outletId,
    DateTime? fromDate,
    DateTime? toDate,
  ) async {
    try {
      final billsData = await _dbService.getBills(
        ownerId: session.ownerId,
        businessId: session.businessId,
        outletId: outletId,
        fromDate: fromDate,
        toDate: toDate,
      );

      return billsData
          .map(
            (data) => Bill(
              id: data['id'],
              billNumber: data['bill_number'],
              outletId: data['outlet_id'],
              outletName: data['outlet_name'],
              outletAddress: data['outlet_address'],
              outletPhone: data['outlet_phone'],
              totalAmount: data['total_amount'],
              discountAmount: data['discount_amount'],
              taxAmount: data['tax_amount'],
              paymentType: data['payment_type'],
              paymentStatus: data['payment_status'],
              ownerId: data['owner_id'],
              businessId: data['business_id'],
              createdBy: data['created_by'],
              salesRepName: data['sales_rep_name'],
              salesRepPhone: data['sales_rep_phone'],
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                data['created_at'],
              ),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                data['updated_at'],
              ),
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting bills from local database: $e');
      throw e;
    }
  }

  // Generate unique bill ID
  static String _generateBillId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Generate bill number
  static String _generateBillNumber() {
    final now = DateTime.now();
    final dateStr =
        now.year.toString() +
        now.month.toString().padLeft(2, '0') +
        now.day.toString().padLeft(2, '0');
    final timeStr =
        now.hour.toString().padLeft(2, '0') +
        now.minute.toString().padLeft(2, '0');
    return 'LB$dateStr$timeStr';
  }

  // Get daily summary for sales rep
  static Future<Map<String, dynamic>> getDailySummary({
    required UserSession session,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final billsData = await _dbService.getBills(
        ownerId: session.ownerId,
        businessId: session.businessId,
        fromDate: startOfDay,
        toDate: endOfDay,
      );

      int billCount = billsData.length;
      double totalValue = 0;
      double totalCash = 0;
      double totalCredit = 0;
      double totalCheque = 0;

      for (final bill in billsData) {
        final amount = bill['total_amount'] as double;
        final paymentType = bill['payment_type'] as String;

        totalValue += amount;

        switch (paymentType.toLowerCase()) {
          case 'cash':
            totalCash += amount;
            break;
          case 'credit':
            totalCredit += amount;
            break;
          case 'cheque':
            totalCheque += amount;
            break;
        }
      }

      return {
        'date': targetDate,
        'billCount': billCount,
        'totalValue': totalValue,
        'totalCash': totalCash,
        'totalCredit': totalCredit,
        'totalCheque': totalCheque,
      };
    } catch (e) {
      print('Error getting daily summary: $e');
      return {
        'date': targetDate,
        'billCount': 0,
        'totalValue': 0.0,
        'totalCash': 0.0,
        'totalCredit': 0.0,
        'totalCheque': 0.0,
      };
    }
  }
}
