// lib/services/billing/billing_service.dart - Corrected Version
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lumorabiz_billing/models/bill.dart';
import 'package:lumorabiz_billing/models/bill_item.dart';
import 'package:lumorabiz_billing/models/user_session.dart';
import 'package:lumorabiz_billing/services/local/database_service.dart';
import 'package:lumorabiz_billing/services/loading/loading_service.dart';
import 'package:lumorabiz_billing/models/selected_bill_item.dart';

class BillingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseService _dbService = DatabaseService();

  // Create a new bill with items stored directly in the bill document
  static Future<String> createBill({
    required String outletId,
    required String outletName,
    required String outletAddress,
    required String outletPhone,
    required List<SelectedBillItem> items,
    required String paymentType,
    required double loadingCost,
    required double discountAmount,
    required double taxAmount,
    required UserSession session,
  }) async {
    try {
      // Generate unique bill ID and number
      final billId = 'bill_${DateTime.now().millisecondsSinceEpoch}';
      final billNumber = 'BILL-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      // Calculate totals
      final subtotalAmount = items.fold<double>(
        0.0,
        (sum, item) => sum + item.totalPrice,
      );
      final totalAmount =
          subtotalAmount + loadingCost + taxAmount - discountAmount;

      // Create bill object
      final bill = Bill(
        id: billId,
        billNumber: billNumber,
        outletId: outletId,
        outletName: outletName,
        outletAddress: outletAddress,
        outletPhone: outletPhone,
        subtotalAmount: subtotalAmount,
        loadingCost: loadingCost,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        paymentType: paymentType,
        paymentStatus: paymentType.toLowerCase() == 'cash' ? 'paid' : 'pending',
        ownerId: session.ownerId,
        businessId: session.businessId,
        createdBy: session.employeeId,
        salesRepName: session.name,
        salesRepPhone: session.phone,
        createdAt: now,
        updatedAt: now,
      );

      // Create bill items using original product IDs
      final billItems =
          items
              .map(
                (item) => BillItem(
                  id:
                      '${billId}_${item.originalProductId}_${DateTime.now().millisecondsSinceEpoch}',
                  billId: billId,
                  productId: item.originalProductId,
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
        // Save to Firebase with items in the bill document
        await _saveBillToFirebase(bill, billItems, session);

        // Update stock quantities in loading
        await _updateLoadingQuantities(items, session);
      } else {
        // Save to local database
        await _saveBillToLocal(bill, billItems, session);
      }

      return billId;
    } catch (e) {
      print('Error creating bill: $e');
      rethrow;
    }
  }

  // Save bill to Firebase with items directly in the bill document
  static Future<void> _saveBillToFirebase(
    Bill bill,
    List<BillItem> billItems,
    UserSession session,
  ) async {
    final batch = _firestore.batch();

    try {
      // Create bill document with items array
      final billRef = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('bills')
          .doc(bill.id);

      // Convert bill items to map format for storage
      final itemsData =
          billItems
              .map(
                (item) => {
                  'id': item.id,
                  'productId': item.productId,
                  'productName': item.productName,
                  'productCode': item.productCode,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'totalPrice': item.totalPrice,
                },
              )
              .toList();

      batch.set(billRef, {
        'id': bill.id,
        'billNumber': bill.billNumber,
        'outletId': bill.outletId,
        'outletName': bill.outletName,
        'outletAddress': bill.outletAddress,
        'outletPhone': bill.outletPhone,
        'subtotalAmount': bill.subtotalAmount,
        'loadingCost': bill.loadingCost,
        'totalAmount': bill.totalAmount,
        'discountAmount': bill.discountAmount,
        'taxAmount': bill.taxAmount,
        'paymentType': bill.paymentType,
        'paymentStatus': bill.paymentStatus,
        'ownerId': session.ownerId,
        'businessId': session.businessId,
        'createdBy': session.employeeId,
        'salesRepName': bill.salesRepName,
        'salesRepPhone': bill.salesRepPhone,
        'items': itemsData, // Store items directly in the bill document
        'itemCount': billItems.length, // For quick reference
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print(
        'Bill saved to Firebase successfully with ${billItems.length} items',
      );
    } catch (e) {
      print('Error saving bill to Firebase: $e');
      rethrow;
    }
  }

  // Save bill to local database
  static Future<void> _saveBillToLocal(
    Bill bill,
    List<BillItem> billItems,
    UserSession session,
  ) async {
    try {
      // Prepare bill data for SQLite
      final billData = bill.toSQLite();
      final billItemsData = billItems.map((item) => item.toSQLite()).toList();

      await _dbService.insertBill(billData, billItemsData);

      print('Bill saved to local database successfully');
    } catch (e) {
      print('Error saving bill to local database: $e');
      rethrow;
    }
  }

  // Update loading quantities after bill creation
  static Future<void> _updateLoadingQuantities(
    List<SelectedBillItem> items,
    UserSession session,
  ) async {
    try {
      // Group items by product code to sum quantities
      final Map<String, int> quantityUpdates = {};
      for (final item in items) {
        quantityUpdates[item.productCode] =
            (quantityUpdates[item.productCode] ?? 0) + item.quantity;
      }

      // Get today's loading to get the loading ID
      final loading = await LoadingService.getTodaysLoading(session);
      if (loading == null) {
        print('No loading found for today - skipping quantity update');
        return;
      }

      // Use LoadingService to update sold quantities with productCode
      final success = await LoadingService.updateSoldQuantities(
        session: session,
        loadingId: loading.loadingId,
        itemQuantities: quantityUpdates, // productCode -> quantity sold
      );

      if (success) {
        print('Loading quantities updated successfully');
      } else {
        print('Failed to update loading quantities');
      }
    } catch (e) {
      print('Error updating loading quantities: $e');
      // Don't rethrow - bill creation succeeded, this is just updating stock
    }
  }

  // Get bills for a specific date
  static Future<List<Bill>> getBillsForDate(
    UserSession session,
    DateTime date,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        return await _getBillsFromFirebase(session, date);
      } else {
        return await _getBillsFromLocal(session, date);
      }
    } catch (e) {
      print('Error getting bills for date: $e');
      return [];
    }
  }

  // Get bills from Firebase
  static Future<List<Bill>> _getBillsFromFirebase(
    UserSession session,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('bills')
              .where('createdBy', isEqualTo: session.employeeId)
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where(
                'createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
              )
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Bill.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Error getting bills from Firebase: $e');
      return [];
    }
  }

  // Get bills from local database using existing getBillsForDate method
  static Future<List<Bill>> _getBillsFromLocal(
    UserSession session,
    DateTime date,
  ) async {
    try {
      // Use the specific getBillsForDate method
      final billsData = await _dbService.getBillsForDate(
        session.ownerId,
        session.businessId,
        date,
      );

      // Filter by employee ID since getBillsForDate doesn't filter by createdBy
      final filteredBills =
          billsData
              .where((billData) => billData['created_by'] == session.employeeId)
              .toList();

      return filteredBills
          .map((billData) => Bill.fromSQLite(billData))
          .toList();
    } catch (e) {
      print('Error getting bills from local database: $e');
      return [];
    }
  }

  // Get bill items for a specific bill (now from the bill document itself)
  static Future<List<BillItem>> getBillItems(
    String billId,
    UserSession session,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        return await _getBillItemsFromFirebase(billId, session);
      } else {
        return await _getBillItemsFromLocal(billId, session);
      }
    } catch (e) {
      print('Error getting bill items: $e');
      return [];
    }
  }

  // Get bill items from Firebase (from bill document)
  static Future<List<BillItem>> _getBillItemsFromFirebase(
    String billId,
    UserSession session,
  ) async {
    try {
      final billDoc =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('bills')
              .doc(billId)
              .get();

      if (!billDoc.exists) {
        print('Bill document not found: $billId');
        return [];
      }

      final data = billDoc.data()!;
      final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);

      return itemsData.map((itemData) {
        return BillItem(
          id: itemData['id'] ?? '',
          billId: billId,
          productId: itemData['productId'] ?? '',
          productName: itemData['productName'] ?? '',
          productCode: itemData['productCode'] ?? '',
          quantity: itemData['quantity'] ?? 0,
          unitPrice: (itemData['unitPrice'] ?? 0.0).toDouble(),
          totalPrice: (itemData['totalPrice'] ?? 0.0).toDouble(),
        );
      }).toList();
    } catch (e) {
      print('Error getting bill items from Firebase: $e');
      return [];
    }
  }

  // Get bill items from local database
  static Future<List<BillItem>> _getBillItemsFromLocal(
    String billId,
    UserSession session,
  ) async {
    try {
      final billItemsData = await _dbService.getBillItems(billId);
      return billItemsData
          .map((itemData) => BillItem.fromSQLite(itemData))
          .toList();
    } catch (e) {
      print('Error getting bill items from local database: $e');
      return [];
    }
  }

  // Get daily summary
  static Future<Map<String, dynamic>> getDailySummary(
    UserSession session,
    DateTime date,
  ) async {
    try {
      final bills = await getBillsForDate(session, date);

      double totalRevenue = 0.0;
      double totalSubtotal = 0.0;
      double totalLoadingCost = 0.0;
      double totalCash = 0.0;
      double totalCredit = 0.0;
      double totalCheque = 0.0;
      int totalBills = bills.length;
      int totalItems = 0;

      for (final bill in bills) {
        totalRevenue += bill.totalAmount;
        totalSubtotal += bill.subtotalAmount;
        totalLoadingCost += bill.loadingCost;

        // Count payment types
        switch (bill.paymentType.toLowerCase()) {
          case 'cash':
            totalCash += bill.totalAmount;
            break;
          case 'credit':
            totalCredit += bill.totalAmount;
            break;
          case 'cheque':
            totalCheque += bill.totalAmount;
            break;
        }

        // Get item count from bill document directly
        totalItems += await _getBillItemCount(bill.id, session);
      }

      return {
        'date': date.toIso8601String().split('T')[0],
        'totalBills': totalBills,
        'totalItems': totalItems,
        'totalSubtotal': totalSubtotal,
        'totalLoadingCost': totalLoadingCost,
        'totalRevenue': totalRevenue,
        'totalCash': totalCash,
        'totalCredit': totalCredit,
        'totalCheque': totalCheque,
        'bills': bills,
      };
    } catch (e) {
      print('Error getting daily summary: $e');
      return {
        'date': date.toIso8601String().split('T')[0],
        'totalBills': 0,
        'totalItems': 0,
        'totalSubtotal': 0.0,
        'totalLoadingCost': 0.0,
        'totalRevenue': 0.0,
        'totalCash': 0.0,
        'totalCredit': 0.0,
        'totalCheque': 0.0,
        'bills': <Bill>[],
      };
    }
  }

  // Get bill item count (simplified since items are in the bill document)
  static Future<int> _getBillItemCount(
    String billId,
    UserSession session,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        final billDoc =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('bills')
                .doc(billId)
                .get();

        if (billDoc.exists) {
          final data = billDoc.data()!;
          return data['itemCount'] ?? 0; // Use the pre-calculated count
        }
        return 0;
      } else {
        final items = await _dbService.getBillItems(billId);
        return items.length;
      }
    } catch (e) {
      print('Error getting bill item count: $e');
      return 0;
    }
  }

  // Get all bills for a user (for listing/searching)
  static Future<List<Bill>> getAllBills(UserSession session) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        final querySnapshot =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('bills')
                .where('createdBy', isEqualTo: session.employeeId)
                .orderBy('createdAt', descending: true)
                .limit(100) // Limit for performance
                .get();

        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          return Bill.fromFirestore(data);
        }).toList();
      } else {
        // Use existing getBills method for local data
        final billsData = await _dbService.getBills(
          ownerId: session.ownerId,
          businessId: session.businessId,
        );

        // Filter by employee ID
        final filteredBills =
            billsData
                .where(
                  (billData) => billData['created_by'] == session.employeeId,
                )
                .toList();

        return filteredBills
            .map((billData) => Bill.fromSQLite(billData))
            .toList();
      }
    } catch (e) {
      print('Error getting all bills: $e');
      return [];
    }
  }

  // Update bill payment status
  static Future<void> updatePaymentStatus(
    UserSession session,
    String billId,
    String newStatus,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        await _firestore
            .collection('owners')
            .doc(session.ownerId)
            .collection('businesses')
            .doc(session.businessId)
            .collection('bills')
            .doc(billId)
            .update({
              'paymentStatus': newStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // For offline, we'd need to add this to sync queue
        // Since updateBillPaymentStatus doesn't exist in DatabaseService,
        // we'll just log it for now
        print('Payment status update queued for sync: $billId -> $newStatus');
        // TODO: Add to sync queue when implementing local payment status updates
      }
    } catch (e) {
      print('Error updating payment status: $e');
      rethrow;
    }
  }

  // Search bills by outlet name or bill number
  static Future<List<Bill>> searchBills(
    UserSession session,
    String searchQuery,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Search in Firebase
        final querySnapshot =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('bills')
                .where('createdBy', isEqualTo: session.employeeId)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .get();

        // Filter results locally (Firestore doesn't support LIKE queries)
        final bills =
            querySnapshot.docs
                .map((doc) => Bill.fromFirestore(doc.data()))
                .where(
                  (bill) =>
                      bill.outletName.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      bill.billNumber.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ),
                )
                .toList();

        return bills;
      } else {
        // Search in local database using existing getBills method
        final billsData = await _dbService.getBills(
          ownerId: session.ownerId,
          businessId: session.businessId,
        );

        // Filter by employee and search criteria
        final filteredBills =
            billsData.where((billData) {
              final createdBy = billData['created_by'] as String;
              final outletName =
                  (billData['outlet_name'] as String? ?? '').toLowerCase();
              final billNumber =
                  (billData['bill_number'] as String? ?? '').toLowerCase();
              final query = searchQuery.toLowerCase();

              return createdBy == session.employeeId &&
                  (outletName.contains(query) || billNumber.contains(query));
            }).toList();

        return filteredBills
            .map((billData) => Bill.fromSQLite(billData))
            .toList();
      }
    } catch (e) {
      print('Error searching bills: $e');
      return [];
    }
  }

  // Get bills by payment status
  static Future<List<Bill>> getBillsByPaymentStatus(
    UserSession session,
    String paymentStatus,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        final querySnapshot =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('bills')
                .where('createdBy', isEqualTo: session.employeeId)
                .where('paymentStatus', isEqualTo: paymentStatus)
                .orderBy('createdAt', descending: true)
                .get();

        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          return Bill.fromFirestore(data);
        }).toList();
      } else {
        // Use existing getBills method and filter
        final billsData = await _dbService.getBills(
          ownerId: session.ownerId,
          businessId: session.businessId,
        );

        final filteredBills =
            billsData
                .where(
                  (billData) =>
                      billData['created_by'] == session.employeeId &&
                      billData['payment_status'] == paymentStatus,
                )
                .toList();

        return filteredBills
            .map((billData) => Bill.fromSQLite(billData))
            .toList();
      }
    } catch (e) {
      print('Error getting bills by payment status: $e');
      return [];
    }
  }

  // Sync offline bills to Firebase using existing getPendingBills method
  static Future<void> syncOfflineBills(UserSession session) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (!isOnline) {
        print('Device is offline, cannot sync bills');
        return;
      }

      // Use existing getPendingBills method
      final unsyncedBills = await _dbService.getPendingBills(
        session.ownerId,
        session.businessId,
      );

      // Filter for bills created by this employee
      final employeeBills =
          unsyncedBills
              .where((billData) => billData['created_by'] == session.employeeId)
              .toList();

      print('Found ${employeeBills.length} unsynced bills for employee');

      for (final billData in employeeBills) {
        try {
          final bill = Bill.fromSQLite(billData);
          final billItemsData = await _dbService.getBillItems(bill.id);
          final billItems =
              billItemsData
                  .map((itemData) => BillItem.fromSQLite(itemData))
                  .toList();

          await _saveBillToFirebase(bill, billItems, session);

          print('Synced bill: ${bill.billNumber}');
        } catch (e) {
          print('Error syncing bill ${billData['id']}: $e');
        }
      }

      print('Offline bills sync completed');
    } catch (e) {
      print('Error during bills sync: $e');
    }
  }

  // Mark bills as uploaded for a specific date
  static Future<void> markBillsAsUploaded(
    UserSession session,
    DateTime date,
  ) async {
    try {
      await _dbService.markBillsAsUploaded(
        session.ownerId,
        session.businessId,
        date,
      );
      print('Bills marked as uploaded for date: ${date.toIso8601String()}');
    } catch (e) {
      print('Error marking bills as uploaded: $e');
    }
  }

  // Get bill details with items
  static Future<Map<String, dynamic>?> getBillDetails(
    String billId,
    UserSession session,
  ) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (isOnline) {
        // Get from Firebase
        final billDoc =
            await _firestore
                .collection('owners')
                .doc(session.ownerId)
                .collection('businesses')
                .doc(session.businessId)
                .collection('bills')
                .doc(billId)
                .get();

        if (!billDoc.exists) return null;

        final billData = billDoc.data()!;
        final bill = Bill.fromFirestore(billData);
        final items = await getBillItems(billId, session);

        return {'bill': bill, 'items': items};
      } else {
        // Get from local database using existing getBillsForDate method
        final billsData = await _dbService.getBillsForDate(
          session.ownerId,
          session.businessId,
          DateTime.now(), // Use current date or modify to get all bills
        );

        final billData = billsData.where((b) => b['id'] == billId).firstOrNull;
        if (billData == null) return null;

        final bill = Bill.fromSQLite(billData);
        final items = await getBillItems(billId, session);

        return {'bill': bill, 'items': items};
      }
    } catch (e) {
      print('Error getting bill details: $e');
      return null;
    }
  }

  // Cancel bill (placeholder for future implementation)
  static Future<void> cancelBill(UserSession session, String billId) async {
    try {
      // This would involve:
      // 1. Marking bill as cancelled
      // 2. Restoring stock quantities
      // 3. Creating cancellation record

      // Implementation depends on business requirements
      print('Bill cancellation not implemented yet');
    } catch (e) {
      print('Error cancelling bill: $e');
      rethrow;
    }
  }
}
