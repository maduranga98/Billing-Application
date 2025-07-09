// lib/utils/timestamp_parser.dart - Complete Firebase Timestamp Handler
import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampParser {
  /// Safely parse various timestamp formats from Firebase
  static DateTime parseTimestamp(dynamic value, {String? context}) {
    if (value == null) return DateTime.now();

    // Handle Firestore Timestamp
    if (value is Timestamp) {
      return value.toDate();
    }

    // Handle DateTime
    if (value is DateTime) {
      return value;
    }

    // Handle milliseconds since epoch (int)
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    // Handle Map objects (both server timestamps and Firestore timestamps)
    if (value is Map<String, dynamic>) {
      // Handle unresolved server timestamp: {_methodName: "serverTimestamp"}
      if (value.containsKey('_methodName') &&
          value['_methodName'] == 'serverTimestamp') {
        final contextInfo = context != null ? ' in $context' : '';
        print(
          'Warning: Unresolved server timestamp detected$contextInfo: $value',
        );
        return DateTime.now();
      }

      // Handle Firestore timestamp object: {seconds: xxx, nanoseconds: xxx}
      if (value.containsKey('seconds') && value.containsKey('nanoseconds')) {
        try {
          final seconds = value['seconds'] as int;
          final nanoseconds = value['nanoseconds'] as int;

          // Convert to milliseconds and create DateTime
          final milliseconds = (seconds * 1000) + (nanoseconds ~/ 1000000);
          return DateTime.fromMillisecondsSinceEpoch(milliseconds);
        } catch (e) {
          final contextInfo = context != null ? ' in $context' : '';
          print(
            'Error parsing Firestore timestamp object$contextInfo: $value, error: $e',
          );
          return DateTime.now();
        }
      }

      // Unknown map format
      final contextInfo = context != null ? ' in $context' : '';
      print('Unknown timestamp map format$contextInfo: $value');
      return DateTime.now();
    }

    // Handle ISO string format
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        final contextInfo = context != null ? ' in $context' : '';
        print('Error parsing timestamp string$contextInfo: $value');
        return DateTime.now();
      }
    }

    // Fallback to current time
    final contextInfo = context != null ? ' in $context' : '';
    print(
      'Unknown timestamp format$contextInfo: $value (${value.runtimeType})',
    );
    return DateTime.now();
  }
}
