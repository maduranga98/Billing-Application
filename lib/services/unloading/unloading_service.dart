// lib/services/unloading/unloading_service.dart (FIXED VERSION)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/unloading_summary.dart';
import '../../models/user_session.dart';
import '../../models/loading.dart';
import '../../models/bill.dart';
import '../../models/bill_item.dart';

import '../loading/loading_service.dart';
import '../local/database_service.dart';

class UnloadingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DatabaseService _dbService = DatabaseService();

  /// Main upload process - uploads day summary and all bills
  static Future<Map<String, dynamic>> uploadDayData({
    required UserSession session,
    DateTime? date,
  }) async {
    final uploadDate = date ?? DateTime.now();
    final result = <String, dynamic>{
      'success': false,
      'uploadedBills': 0,
      'unloadingSummary': null,
      'errors': <String>[],
      'details': <String, dynamic>{},
    };

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (!isOnline) {
        result['errors'].add('No internet connection available');
        return result;
      }

      print(
        'Starting upload process for date: ${uploadDate.toIso8601String()}',
      );

      // Step 1: Get today's loading data
      final loading = await LoadingService.getTodaysLoading(session);
      if (loading == null) {
        result['errors'].add('No loading data found for today');
        return result;
      }

      // Step 2: Get all bills for the day
      final bills = await _getBillsForDate(session, uploadDate);
      print('Found ${bills.length} bills to upload');

      // Step 3: Generate unloading summary
      final unloadingSummary = await _generateUnloadingSummary(
        session: session,
        loading: loading,
        bills: bills,
        date: uploadDate,
      );

      // Step 4: Upload unloading summary to Firebase
      final unloadingResult = await _uploadUnloadingSummary(
        session: session,
        summary: unloadingSummary,
      );

      if (!unloadingResult['success']) {
        result['errors'].add(
          'Failed to upload unloading summary: ${unloadingResult['error']}',
        );
        return result;
      }

      // Step 5: Upload all bills to Firebase
      final billsResult = await _uploadBillsToFirebase(session, bills);

      result['success'] = true;
      result['uploadedBills'] = billsResult['uploadedCount'];
      result['unloadingSummary'] = unloadingSummary;
      result['details'] = {
        'unloadingId': unloadingResult['unloadingId'],
        'billsUploaded': billsResult['uploadedCount'],
        'billsFailed': billsResult['failedCount'],
        'totalValue': unloadingSummary.totalSalesValue,
        'totalBills': bills.length,
      };

      // Step 6: Mark local data as uploaded
      await _markDataAsUploaded(session, uploadDate);

      print('Upload completed successfully');
      return result;
    } catch (e) {
      print('Error in upload process: $e');
      result['errors'].add('Upload failed: $e');
      return result;
    }
  }

  /// Generate comprehensive unloading summary
  static Future<UnloadingSummary> _generateUnloadingSummary({
    required UserSession session,
    required Loading loading,
    required List<Bill> bills,
    required DateTime date,
  }) async {
    try {
      print('Generating unloading summary...');

      // Calculate totals from bills
      double totalSalesValue = 0.0;
      double totalCashSales = 0.0;
      double totalCreditSales = 0.0;
      double totalChequeSales = 0.0;
      int totalBillCount = bills.length;

      for (final bill in bills) {
        totalSalesValue += bill.totalAmount;

        switch (bill.paymentType.toLowerCase()) {
          case 'cash':
            totalCashSales += bill.totalAmount;
            break;
          case 'credit':
            totalCreditSales += bill.totalAmount;
            break;
          case 'cheque':
            totalChequeSales += bill.totalAmount;
            break;
        }
      }

      // Calculate items sold by product code
      final Map<String, Map<String, dynamic>> itemsSold = {};
      for (final bill in bills) {
        final billItems = await _getBillItems(session, bill.id);
        for (final item in billItems) {
          if (!itemsSold.containsKey(item.productCode)) {
            itemsSold[item.productCode] = {
              'productCode': item.productCode,
              'productName': item.productName,
              'quantitySold': 0,
              'totalValue': 0.0,
              'unitPrice': item.unitPrice,
            };
          }
          itemsSold[item.productCode]!['quantitySold'] += item.quantity;
          itemsSold[item.productCode]!['totalValue'] += item.totalPrice;
        }
      }

      // Calculate remaining stock from loading
      final Map<String, Map<String, dynamic>> remainingStock = {};
      for (final item in loading.items) {
        remainingStock[item.productCode] = {
          'productCode': item.productCode,
          'productName': item.itemName,
          'initialQuantity': item.bagsCount, // Original loaded quantity
          'remainingQuantity': item.bagQuantity, // Current remaining
          'soldQuantity': item.bagsCount - item.bagQuantity,
          'remainingValue': item.bagQuantity * item.pricePerKg * item.bagSize,
        };
      }

      return UnloadingSummary(
        id: '', // Will be set by Firebase
        loadingId: loading.loadingId,
        businessId: session.businessId,
        ownerId: session.ownerId,
        salesRepId: session.employeeId,
        salesRepName: session.name,
        routeId: loading.routeId,
        routeName: loading.todayRoute?.name ?? 'Unknown Route',
        unloadingDate: date,

        // Sales totals
        totalBillCount: totalBillCount,
        totalSalesValue: totalSalesValue,
        totalCashSales: totalCashSales,
        totalCreditSales: totalCreditSales,
        totalChequeSales: totalChequeSales,

        // Stock information
        totalItemsLoaded: loading.totalBags,
        totalValueLoaded: loading.totalValue,
        itemsSold: itemsSold.values.toList(),
        remainingStock: remainingStock.values.toList(),

        // Metadata
        createdAt: DateTime.now(),
        createdBy: session.employeeId,

        // Additional details
        notes: 'Auto-generated unloading summary',
        status: 'completed',
      );
    } catch (e) {
      print('Error generating unloading summary: $e');
      rethrow;
    }
  }

  /// Upload unloading summary to Firebase
  static Future<Map<String, dynamic>> _uploadUnloadingSummary({
    required UserSession session,
    required UnloadingSummary summary,
  }) async {
    try {
      print('Uploading unloading summary to Firebase...');

      final unloadingRef =
          _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('unloadings')
              .doc();

      final summaryData = summary.toFirestore();
      summaryData['id'] = unloadingRef.id;
      summaryData['createdAt'] = FieldValue.serverTimestamp();
      summaryData['updatedAt'] = FieldValue.serverTimestamp();

      await unloadingRef.set(summaryData);

      print('Unloading summary uploaded successfully: ${unloadingRef.id}');

      return {'success': true, 'unloadingId': unloadingRef.id};
    } catch (e) {
      print('Error uploading unloading summary: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload all bills to Firebase
  static Future<Map<String, dynamic>> _uploadBillsToFirebase(
    UserSession session,
    List<Bill> bills,
  ) async {
    int uploadedCount = 0;
    int failedCount = 0;
    final List<String> errors = [];

    print('Uploading ${bills.length} bills to Firebase...');

    for (final bill in bills) {
      try {
        // Get bill items
        final billItems = await _getBillItems(session, bill.id);

        // FIXED: Use _saveBillToFirebase directly instead of non-existent method
        await _saveBillToFirebase(bill, billItems, session);

        uploadedCount++;
        print('Uploaded bill: ${bill.billNumber}');
      } catch (e) {
        failedCount++;
        final error = 'Failed to upload bill ${bill.billNumber}: $e';
        errors.add(error);
        print(error);
      }
    }

    return {
      'uploadedCount': uploadedCount,
      'failedCount': failedCount,
      'errors': errors,
    };
  }

  /// ADDED: Direct Firebase bill upload method
  static Future<void> _saveBillToFirebase(
    Bill bill,
    List<BillItem> billItems,
    UserSession session,
  ) async {
    final batch = _firestore.batch();

    try {
      // Create bill document
      final billRef = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('bills')
          .doc(bill.id);

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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add bill items as subcollection
      for (final item in billItems) {
        final itemRef = billRef.collection('items').doc();
        batch.set(itemRef, {
          'id': item.id,
          'billId': item.billId,
          'productId': item.productId,
          'productName': item.productName,
          'productCode': item.productCode,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'totalPrice': item.totalPrice,
        });
      }

      await batch.commit();
      print('Bill saved to Firebase successfully: ${bill.billNumber}');
    } catch (e) {
      print('Error saving bill to Firebase: $e');
      rethrow;
    }
  }

  /// FIXED: Get bills for specific date from local database
  static Future<List<Bill>> _getBillsForDate(
    UserSession session,
    DateTime date,
  ) async {
    try {
      // Get bills data from local database for the specific date
      final billsData = await _dbService.getBillsForDate(
        session.ownerId,
        session.businessId,
        date,
      );

      // FIXED: Convert Map<String, dynamic> to Bill objects
      return billsData.map((data) => Bill.fromSQLite(data)).toList();
    } catch (e) {
      print('Error getting bills for date: $e');
      return [];
    }
  }

  /// Get bill items from local database
  static Future<List<BillItem>> _getBillItems(
    UserSession session,
    String billId,
  ) async {
    try {
      final billItemsData = await _dbService.getBillItems(billId);
      return billItemsData.map((data) => BillItem.fromSQLite(data)).toList();
    } catch (e) {
      print('Error getting bill items: $e');
      return [];
    }
  }

  /// Mark local data as uploaded
  static Future<void> _markDataAsUploaded(
    UserSession session,
    DateTime date,
  ) async {
    try {
      // Mark bills as uploaded in local database
      await _dbService.markBillsAsUploaded(
        session.ownerId,
        session.businessId,
        date,
      );

      print(
        'Marked local data as uploaded for date: ${date.toIso8601String()}',
      );
    } catch (e) {
      print('Error marking data as uploaded: $e');
    }
  }

  /// Get unloading history
  static Future<List<UnloadingSummary>> getUnloadingHistory({
    required UserSession session,
    int limit = 10,
  }) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('unloadings')
              .where('salesRepId', isEqualTo: session.employeeId)
              .orderBy('unloadingDate', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs
          .map(
            (doc) => UnloadingSummary.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting unloading history: $e');
      return [];
    }
  }

  /// FIXED: Get pending upload data (data not yet uploaded)
  static Future<Map<String, dynamic>> getPendingUploadData(
    UserSession session,
  ) async {
    try {
      // Get pending bills from local database
      final pendingBillsData = await _dbService.getPendingBills(
        session.ownerId,
        session.businessId,
      );

      // FIXED: Convert to Bill objects and calculate total
      final pendingBills =
          pendingBillsData.map((data) => Bill.fromSQLite(data)).toList();

      // Get today's loading
      final loading = await LoadingService.getTodaysLoading(session);

      return {
        'hasPendingData': pendingBills.isNotEmpty,
        'pendingBillsCount': pendingBills.length,
        'hasLoading': loading != null,
        'loadingId': loading?.loadingId,
        'totalPendingValue': pendingBills.fold(
          0.0,
          (sum, bill) =>
              sum +
              bill.totalAmount, // FIXED: Now accessing Bill object property
        ),
      };
    } catch (e) {
      print('Error getting pending upload data: $e');
      return {
        'hasPendingData': false,
        'pendingBillsCount': 0,
        'hasLoading': false,
        'totalPendingValue': 0.0,
      };
    }
  }

  /// Validate data before upload
  static Future<Map<String, dynamic>> validateBeforeUpload(
    UserSession session,
  ) async {
    try {
      final validation = <String, dynamic>{
        'isValid': true,
        'errors': <String>[],
        'warnings': <String>[],
      };

      // Check if there's loading data
      final loading = await LoadingService.getTodaysLoading(session);
      if (loading == null) {
        validation['isValid'] = false;
        validation['errors'].add('No loading data found for today');
        return validation;
      }

      // Check if there are bills to upload
      final pendingData = await getPendingUploadData(session);
      if (!pendingData['hasPendingData']) {
        validation['warnings'].add('No bills found to upload');
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.first != ConnectivityResult.none;

      if (!isOnline) {
        validation['isValid'] = false;
        validation['errors'].add('No internet connection available');
      }

      return validation;
    } catch (e) {
      return {
        'isValid': false,
        'errors': ['Validation failed: $e'],
        'warnings': <String>[],
      };
    }
  }
}
