// lib/utils/timestamp_parser.dart
// Complete fix for all timestamp formats including Firestore format

import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampParser {
  /// Parse various timestamp formats to DateTime
  static DateTime parseTimestamp(dynamic timestamp, {String? context}) {
    try {
      if (timestamp == null) {
        print(
          'Warning: Null timestamp received${context != null ? ' in $context' : ''}',
        );
        return DateTime.now();
      }

      // Handle Firestore Timestamp
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      }

      // Handle DateTime
      if (timestamp is DateTime) {
        return timestamp;
      }

      // Handle server timestamp placeholder
      if (timestamp is Map && timestamp['_methodName'] == 'serverTimestamp') {
        print(
          'Warning: Unresolved server timestamp detected${context != null ? ' in $context' : ''}: $timestamp',
        );
        return DateTime.now();
      }

      // FIXED: Handle Firestore timestamp format {seconds: ..., nanoseconds: ...}
      if (timestamp is Map && timestamp.containsKey('seconds')) {
        try {
          final seconds = timestamp['seconds'] as int;
          final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
          // Convert to milliseconds: seconds * 1000 + nanoseconds / 1,000,000
          final milliseconds = seconds * 1000 + (nanoseconds ~/ 1000000);
          return DateTime.fromMillisecondsSinceEpoch(milliseconds);
        } catch (e) {
          print('Error parsing Firestore timestamp format: $e');
          return DateTime.now();
        }
      }

      // Handle milliseconds since epoch (int)
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }

      // Handle string representation of milliseconds
      if (timestamp is String) {
        final parsed = int.tryParse(timestamp);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsed);
        }

        // Try parsing as ISO string
        try {
          return DateTime.parse(timestamp);
        } catch (e) {
          print('Error parsing timestamp string: $timestamp');
          return DateTime.now();
        }
      }

      print(
        'Warning: Unknown timestamp format${context != null ? ' in $context' : ''}: $timestamp (${timestamp.runtimeType})',
      );
      return DateTime.now();
    } catch (e) {
      print(
        'Error parsing timestamp${context != null ? ' in $context' : ''}: $e',
      );
      return DateTime.now();
    }
  }

  /// Convert DateTime to milliseconds for storage
  static int toMilliseconds(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch;
  }

  /// Convert timestamp to milliseconds for safe JSON serialization
  static int timestampToMilliseconds(dynamic timestamp) {
    final dateTime = parseTimestamp(timestamp);
    return dateTime.millisecondsSinceEpoch;
  }

  /// ADDED: Convert any object to serializable format
  static dynamic makeSerializable(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is Map && value['_methodName'] == 'serverTimestamp') {
      return DateTime.now().millisecondsSinceEpoch;
    }

    if (value is Map && value.containsKey('seconds')) {
      try {
        final seconds = value['seconds'] as int;
        final nanoseconds = value['nanoseconds'] as int? ?? 0;
        final milliseconds = seconds * 1000 + (nanoseconds ~/ 1000000);
        return milliseconds;
      } catch (e) {
        return DateTime.now().millisecondsSinceEpoch;
      }
    }

    if (value is Map) {
      final Map<String, dynamic> serialized = {};
      for (final entry in value.entries) {
        serialized[entry.key.toString()] = makeSerializable(entry.value);
      }
      return serialized;
    }

    if (value is List) {
      return value.map((item) => makeSerializable(item)).toList();
    }

    return value;
  }
}
