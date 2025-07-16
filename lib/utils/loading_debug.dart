// lib/utils/loading_debug.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_session.dart';

class LoadingDebugger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> debugLoadingData(UserSession session) async {
    print('=== LOADING DEBUG START ===');
    print('Session EmployeeId: ${session.employeeId}');
    print('Session OwnerId: ${session.ownerId}');
    print('Session BusinessId: ${session.businessId}');

    try {
      // Check if the collection exists
      final collectionRef = _firestore
          .collection('owners')
          .doc(session.ownerId)
          .collection('businesses')
          .doc(session.businessId)
          .collection('loadings');

      print(
        'Collection path: owners/${session.ownerId}/businesses/${session.businessId}/loadings',
      );

      // Get all documents in loadings collection
      final allDocs = await collectionRef.get();
      print('Total documents in loadings collection: ${allDocs.docs.length}');

      if (allDocs.docs.isNotEmpty) {
        print('\nAll loadings in collection:');
        for (var doc in allDocs.docs) {
          final data = doc.data();
          print('Document ID: ${doc.id}');
          print('  salesRepId: ${data['salesRepId']}');
          print('  status: ${data['status']}');
          print('  routeId: ${data['routeId']}');
          print('  createdAt: ${data['createdAt']}');
          print('  itemCount: ${data['itemCount']}');
          print('  ---');
        }
      }

      // Check for documents with matching salesRepId
      final salesRepQuery =
          await collectionRef
              .where('salesRepId', isEqualTo: session.employeeId)
              .get();

      print(
        '\nDocuments matching salesRepId "${session.employeeId}": ${salesRepQuery.docs.length}',
      );

      if (salesRepQuery.docs.isNotEmpty) {
        for (var doc in salesRepQuery.docs) {
          final data = doc.data();
          print('Matching Document ID: ${doc.id}');
          print('  status: ${data['status']}');
          print('  routeId: ${data['routeId']}');
          print('  items count: ${(data['items'] as List?)?.length ?? 0}');

          if (data['items'] != null) {
            final items = data['items'] as List;
            print(
              '  First item example: ${items.isNotEmpty ? items[0] : 'No items'}',
            );
          }
        }
      }

      // Check for prepared status
      final preparedQuery =
          await collectionRef
              .where('salesRepId', isEqualTo: session.employeeId)
              .where('status', isEqualTo: 'prepared')
              .get();

      print('\nPrepared documents for this rep: ${preparedQuery.docs.length}');

      if (preparedQuery.docs.isNotEmpty) {
        final doc = preparedQuery.docs.first;
        final data = doc.data();
        print('Prepared Document ID: ${doc.id}');
        print('Full data structure:');
        print(data);

        // Check route information
        if (data['routeId'] != null && data['routeId'].toString().isNotEmpty) {
          await debugRouteData(session, data['routeId']);
        }
      }
    } catch (e) {
      print('ERROR during debug: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    print('=== LOADING DEBUG END ===');
  }

  static Future<void> debugRouteData(
    UserSession session,
    String routeId,
  ) async {
    print('\n=== ROUTE DEBUG START ===');
    print('Route ID: $routeId');

    try {
      final routeDoc =
          await _firestore
              .collection('owners')
              .doc(session.ownerId)
              .collection('businesses')
              .doc(session.businessId)
              .collection('routes')
              .doc(routeId)
              .get();

      if (routeDoc.exists) {
        final data = routeDoc.data() as Map<String, dynamic>;
        print('Route found:');
        print('  name: ${data['name']}');
        print('  areas: ${data['areas']}');
        print('  status: ${data['status']}');
        print('Full route data: $data');
      } else {
        print('Route document not found!');
      }
    } catch (e) {
      print('ERROR getting route data: $e');
    }

    print('=== ROUTE DEBUG END ===');
  }

  static Future<void> testFirebaseConnection() async {
    print('=== FIREBASE CONNECTION TEST ===');

    try {
      // Test basic Firebase connection
      print('Firebase connection: OK');

      // Test authentication status
      print('Firebase initialized: ${FirebaseFirestore.instance != null}');
    } catch (e) {
      print('Firebase connection ERROR: $e');
    }

    print('=== CONNECTION TEST END ===');
  }
}
