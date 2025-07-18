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

  /// Main upload process - uploads day summary with bill numbers and detailed quantities
  /// Ensures only one unloading per sales rep per day
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
        'Starting enhanced upload process for date: ${uploadDate.toIso8601String()}',
      );

      // NEW: Check if unloading already exists for this sales rep on this date
      final existingUnloading = await _dbService.getUnloadingSummaryByDate(
        session.ownerId,
        session.businessId,
        session.employeeId,
        uploadDate,
      );

      if (existingUnloading != null) {
        result['errors'].add(
          'Unloading already completed for ${uploadDate.toLocal().toString().split(' ')[0]}. Only one unloading per day is allowed.',
        );
        return result;
      }

      // Step 1: Get today's loading data
      final loading = await LoadingService.getTodaysLoading(session);
      if (loading == null) {
        result['errors'].add('No loading data found for today');
        return result;
      }

      // Step 2: Get all bills for the day
      final bills = await _getBillsForDate(session, uploadDate);
      print('Found ${bills.length} bills to upload');

      if (bills.isEmpty) {
        result['errors'].add(
          'No bills found for today. Cannot create unloading without sales data.',
        );
        return result;
      }

      // Step 3: Generate enhanced unloading summary with bill numbers and detailed quantities
      final unloadingSummary = await _generateEnhancedUnloadingSummary(
        session: session,
        loading: loading,
        bills: bills,
        date: uploadDate,
      );

      // Step 4: Save unloading summary locally first (with one-per-day validation)
      try {
        await _dbService.saveEnhancedUnloadingSummary(unloadingSummary);
        print('Unloading summary saved locally with validation');
      } catch (e) {
        result['errors'].add('Failed to save unloading summary: $e');
        return result;
      }

      // Step 5: Upload unloading summary to Firebase
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

      // Step 6: Upload all bills to Firebase
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
        'totalCash': unloadingSummary.totalCashSales,
        'totalCredit': unloadingSummary.totalCreditSales,
        'totalCheque': unloadingSummary.totalChequeSales,
        'billNumbers': bills.map((bill) => bill.billNumber).toList(),
        'uploadDate': uploadDate.toLocal().toString().split(' ')[0],
        'salesRep': session.name,
      };

      // Step 7: Mark local data as uploaded
      await _markDataAsUploaded(session, uploadDate);

      print(
        'Enhanced upload completed successfully - One unloading per day enforced',
      );
      return result;
    } catch (e) {
      print('Error in enhanced upload process: $e');
      result['errors'].add('Upload failed: $e');
      return result;
    }
  }

  /// Generate enhanced unloading summary with bill numbers and detailed quantities
  static Future<UnloadingSummary> _generateEnhancedUnloadingSummary({
    required UserSession session,
    required Loading loading,
    required List<Bill> bills,
    required DateTime date,
  }) async {
    try {
      print(
        'Generating enhanced unloading summary with bill numbers and quantities...',
      );

      // Calculate totals from bills
      double totalSalesValue = 0.0;
      double totalCashSales = 0.0;
      double totalCreditSales = 0.0;
      double totalChequeSales = 0.0;
      int totalBillCount = bills.length;

      // Collect bill numbers and payment details
      final List<Map<String, dynamic>> billDetails = [];
      for (final bill in bills) {
        totalSalesValue += bill.totalAmount;

        // Add bill details
        billDetails.add({
          'billNumber': bill.billNumber,
          'billId': bill.id,
          'outletName': bill.outletName,
          'amount': bill.totalAmount,
          'paymentType': bill.paymentType,
          'createdAt': bill.createdAt.toIso8601String(),
        });

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

      // Calculate items sold by product code with detailed tracking
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
              'billNumbers': <String>[], // Track which bills sold this item
              'salesCount': 0, // Number of different sales
            };
          }
          itemsSold[item.productCode]!['quantitySold'] += item.quantity;
          itemsSold[item.productCode]!['totalValue'] += item.totalPrice;

          // Add bill number to track sales
          final billNumbers =
              itemsSold[item.productCode]!['billNumbers'] as List<String>;
          if (!billNumbers.contains(bill.billNumber)) {
            billNumbers.add(bill.billNumber);
            itemsSold[item.productCode]!['salesCount']++;
          }
        }
      }

      // Calculate detailed remaining stock from loading with enhanced tracking
      final Map<String, Map<String, dynamic>> remainingStock = {};
      for (final item in loading.items) {
        final soldData = itemsSold[item.productCode];
        final quantitySold = soldData?['quantitySold'] ?? 0;
        final salesValue = soldData?['totalValue'] ?? 0.0;

        remainingStock[item.productCode] = {
          'productCode': item.productCode,
          'productName': item.itemName,
          // Loading quantities
          'initialQuantity': item.bagsCount, // Original loaded quantity
          'initialValue': item.bagsCount * item.pricePerKg * item.bagSize,
          'initialWeight': item.bagsCount * item.bagSize,

          // Current remaining quantities
          'remainingQuantity':
              item.bagQuantity, // Current remaining after all sales
          'remainingValue': item.bagQuantity * item.pricePerKg * item.bagSize,
          'remainingWeight': item.bagQuantity * item.bagSize,

          // Sold quantities
          'soldQuantity': quantitySold,
          'soldValue': salesValue,
          'soldWeight': quantitySold * item.bagSize,

          // Validation - should match
          'calculatedRemaining': item.bagsCount - quantitySold,
          'quantityMatch': (item.bagsCount - quantitySold) == item.bagQuantity,

          // Unit details
          'pricePerKg': item.pricePerKg,
          'bagSize': item.bagSize,
          'unitPrice': item.pricePerKg * item.bagSize,

          // Sales analytics
          'salesPercentage':
              item.bagsCount > 0 ? (quantitySold / item.bagsCount) * 100 : 0.0,
          'salesCount': soldData?['salesCount'] ?? 0,
          'avgQuantityPerSale':
              soldData != null && soldData['salesCount'] > 0
                  ? quantitySold / soldData['salesCount']
                  : 0.0,
        };
      }

      // Create comprehensive unloading summary
      final enhancedSummary = UnloadingSummary(
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

        // Enhanced details
        notes: _generateUnloadingNotes(
          bills: bills,
          loading: loading,
          itemsSold: itemsSold,
          remainingStock: remainingStock,
        ),
        status: 'completed',
      );

      print(
        'Enhanced unloading summary generated with ${bills.length} bills and detailed quantities',
      );
      return enhancedSummary;
    } catch (e) {
      print('Error generating enhanced unloading summary: $e');
      rethrow;
    }
  }

  /// Generate comprehensive notes for unloading summary
  static String _generateUnloadingNotes({
    required List<Bill> bills,
    required Loading loading,
    required Map<String, Map<String, dynamic>> itemsSold,
    required Map<String, Map<String, dynamic>> remainingStock,
  }) {
    final notes = StringBuffer();

    // Basic summary
    notes.writeln('DAILY UNLOADING SUMMARY');
    notes.writeln('========================');
    notes.writeln('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}');
    notes.writeln('Loading ID: ${loading.loadingId}');
    notes.writeln('Route: ${loading.todayRoute?.name ?? 'Unknown'}');
    notes.writeln('');

    // Bill numbers
    notes.writeln('BILL NUMBERS (${bills.length} bills):');
    final billNumbers = bills.map((b) => b.billNumber).toList();
    billNumbers.sort(); // Sort bill numbers
    for (int i = 0; i < billNumbers.length; i += 5) {
      final endIndex =
          (i + 5 < billNumbers.length) ? i + 5 : billNumbers.length;
      notes.writeln(billNumbers.sublist(i, endIndex).join(', '));
    }
    notes.writeln('');

    // Sales summary by payment type
    notes.writeln('PAYMENT TYPE BREAKDOWN:');
    final cashBills =
        bills.where((b) => b.paymentType.toLowerCase() == 'cash').length;
    final creditBills =
        bills.where((b) => b.paymentType.toLowerCase() == 'credit').length;
    final chequeBills =
        bills.where((b) => b.paymentType.toLowerCase() == 'cheque').length;
    notes.writeln('Cash: $cashBills bills');
    notes.writeln('Credit: $creditBills bills');
    notes.writeln('Cheque: $chequeBills bills');
    notes.writeln('');

    // Item-wise summary
    notes.writeln('PRODUCT SALES SUMMARY:');
    itemsSold.forEach((productCode, data) {
      final remaining = remainingStock[productCode];
      notes.writeln('${data['productName']}:');
      notes.writeln(
        '  Sold: ${data['quantitySold']} bags (Rs.${data['totalValue'].toStringAsFixed(2)})',
      );
      if (remaining != null) {
        notes.writeln('  Remaining: ${remaining['remainingQuantity']} bags');
        notes.writeln(
          '  Sales %: ${remaining['salesPercentage'].toStringAsFixed(1)}%',
        );
      }
      notes.writeln(
        '  Bills: ${(data['billNumbers'] as List<String>).join(', ')}',
      );
      notes.writeln('');
    });

    return notes.toString();
  }

  /// Upload enhanced unloading summary to Firebase
  static Future<Map<String, dynamic>> _uploadUnloadingSummary({
    required UserSession session,
    required UnloadingSummary summary,
  }) async {
    try {
      print('Uploading enhanced unloading summary to Firebase...');

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

      // Add enhanced tracking data
      summaryData['uploadType'] = 'enhanced_with_bill_numbers';
      summaryData['dataVersion'] = '2.0';

      await unloadingRef.set(summaryData);

      print(
        'Enhanced unloading summary uploaded successfully: ${unloadingRef.id}',
      );

      return {'success': true, 'unloadingId': unloadingRef.id};
    } catch (e) {
      print('Error uploading enhanced unloading summary: $e');
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

        // Save bill to Firebase
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

  /// Save bill to Firebase with enhanced metadata
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
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Enhanced metadata
        'itemCount': billItems.length,
        'totalQuantity': billItems.fold(0, (sum, item) => sum + item.quantity),
        'uploadType': 'enhanced_unloading',
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
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Enhanced bill saved to Firebase successfully: ${bill.billNumber}');
    } catch (e) {
      print('Error saving enhanced bill to Firebase: $e');
      rethrow;
    }
  }

  /// Get bills for specific date from local database
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

  /// Get pending upload data with enhanced details
  static Future<Map<String, dynamic>> getPendingUploadData(
    UserSession session,
  ) async {
    try {
      // Get pending bills from local database
      final pendingBillsData = await _dbService.getPendingBills(
        session.ownerId,
        session.businessId,
      );

      final pendingBills =
          pendingBillsData.map((data) => Bill.fromSQLite(data)).toList();

      // Get today's loading
      final loading = await LoadingService.getTodaysLoading(session);

      // Calculate enhanced pending data
      double totalCash = 0.0;
      double totalCredit = 0.0;
      double totalCheque = 0.0;
      final billNumbers = <String>[];

      for (final bill in pendingBills) {
        billNumbers.add(bill.billNumber);
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
      }

      return {
        'hasPendingData': pendingBills.isNotEmpty,
        'pendingBillsCount': pendingBills.length,
        'hasLoading': loading != null,
        'loadingId': loading?.loadingId,
        'totalPendingValue': pendingBills.fold(
          0.0,
          (sum, bill) => sum + bill.totalAmount,
        ),
        'totalCash': totalCash,
        'totalCredit': totalCredit,
        'totalCheque': totalCheque,
        'billNumbers': billNumbers,
        'routeName': loading?.todayRoute?.name,
      };
    } catch (e) {
      print('Error getting enhanced pending upload data: $e');
      return {
        'hasPendingData': false,
        'pendingBillsCount': 0,
        'hasLoading': false,
        'totalPendingValue': 0.0,
        'totalCash': 0.0,
        'totalCredit': 0.0,
        'totalCheque': 0.0,
        'billNumbers': <String>[],
      };
    }
  }

  /// Validate data before upload with enhanced checks including one-per-day rule
  static Future<Map<String, dynamic>> validateBeforeUpload(
    UserSession session,
  ) async {
    try {
      final validation = <String, dynamic>{
        'isValid': true,
        'errors': <String>[],
        'warnings': <String>[],
      };

      final today = DateTime.now();

      // NEW: Check if unloading already exists for today
      final existingUnloading = await _dbService.getUnloadingSummaryByDate(
        session.ownerId,
        session.businessId,
        session.employeeId,
        today,
      );

      if (existingUnloading != null) {
        validation['isValid'] = false;
        validation['errors'].add(
          'Unloading already completed for ${today.toLocal().toString().split(' ')[0]}. Only one unloading per sales rep per day is allowed.',
        );
        return validation;
      }

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
        validation['isValid'] = false;
        validation['errors'].add(
          'No bills found to upload. Create at least one bill before unloading.',
        );
      } else {
        final billCount = pendingData['pendingBillsCount'] as int;
        validation['warnings'].add('Ready to upload $billCount bills');
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

      // Add helpful information
      if (validation['isValid']) {
        validation['warnings'].add(
          'All validations passed. Ready for unloading.',
        );
        validation['warnings'].add(
          'Route: ${loading.todayRoute?.name ?? 'Unknown'}',
        );
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

  /// Check if unloading already exists for a specific date
  static Future<bool> hasUnloadingForDate(
    UserSession session,
    DateTime date,
  ) async {
    try {
      final existingUnloading = await _dbService.getUnloadingSummaryByDate(
        session.ownerId,
        session.businessId,
        session.employeeId,
        date,
      );
      return existingUnloading != null;
    } catch (e) {
      print('Error checking existing unloading: $e');
      return false;
    }
  }

  /// Get unloading status for today
  static Future<Map<String, dynamic>> getTodaysUnloadingStatus(
    UserSession session,
  ) async {
    try {
      final today = DateTime.now();
      final existingUnloading = await _dbService.getUnloadingSummaryByDate(
        session.ownerId,
        session.businessId,
        session.employeeId,
        today,
      );

      if (existingUnloading != null) {
        return {
          'hasUnloading': true,
          'unloadingId': existingUnloading.id,
          'billCount': existingUnloading.totalBillCount,
          'totalValue': existingUnloading.totalSalesValue,
          'unloadingDate': existingUnloading.unloadingDate.toIso8601String(),
          'status': existingUnloading.status,
          'billNumbers': existingUnloading.billNumbers,
          'message':
              'Unloading completed for ${today.toLocal().toString().split(' ')[0]}',
        };
      } else {
        final pendingData = await getPendingUploadData(session);
        return {
          'hasUnloading': false,
          'pendingBills': pendingData['pendingBillsCount'],
          'pendingValue': pendingData['totalPendingValue'],
          'canUnload':
              pendingData['hasPendingData'] && pendingData['hasLoading'],
          'message':
              pendingData['hasPendingData']
                  ? 'Ready to create unloading with ${pendingData['pendingBillsCount']} bills'
                  : 'No bills available for unloading',
        };
      }
    } catch (e) {
      return {
        'hasUnloading': false,
        'error': e.toString(),
        'message': 'Error checking unloading status',
      };
    }
  }
}
