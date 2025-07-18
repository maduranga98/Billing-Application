// Add this helper function to your LoadingService or create a new utils file
// lib/utils/firestore_utils.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUtils {
  /// Safely converts Firestore data for local storage
  static Map<String, dynamic> cleanFirestoreData(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) continue;

      // Handle Firestore Timestamp
      if (value.toString().contains('Timestamp')) {
        try {
          final timestamp = value as Timestamp;
          cleaned[key] = timestamp.millisecondsSinceEpoch;
        } catch (e) {
          cleaned[key] = DateTime.now().millisecondsSinceEpoch;
        }
      }
      // Handle server timestamp placeholder
      else if (value is Map && value['_methodName'] == 'serverTimestamp') {
        cleaned[key] = DateTime.now().millisecondsSinceEpoch;
        print(
          'Warning: Unresolved server timestamp replaced with current time',
        );
      }
      // Handle DateTime
      else if (value is DateTime) {
        cleaned[key] = value.millisecondsSinceEpoch;
      }
      // Handle nested Maps
      else if (value is Map<String, dynamic>) {
        cleaned[key] = cleanFirestoreData(value);
      }
      // Handle Lists
      else if (value is List) {
        cleaned[key] =
            value.map((item) {
              if (item is Map<String, dynamic>) {
                return cleanFirestoreData(item);
              }
              return item;
            }).toList();
      }
      // Keep primitive types as-is
      else {
        cleaned[key] = value;
      }
    }

    return cleaned;
  }

  /// Convert timestamp back to DateTime
  static DateTime? timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (timestamp is String) {
      final parsed = int.tryParse(timestamp);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }

    return null;
  }
}
