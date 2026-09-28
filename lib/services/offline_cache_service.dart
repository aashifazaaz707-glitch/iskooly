import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class OfflineCacheService {
  static const String _studentsCacheKey = 'iskool_cached_students_';
  static const String _feesCacheKey = 'iskool_cached_fees_';
  static const String _pendingAttendanceKey = 'iskool_pending_attendance';
  static const String _pendingFeesKey = 'iskool_pending_fees';

  /// Save students to local offline cache
  static Future<void> cacheStudents(String schoolId, List<StudentModel> students) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = students.map((s) => s.toJson()).toList();
      await prefs.setString('$_studentsCacheKey$schoolId', jsonEncode(data));
    } catch (e) {
      debugPrint('Error caching students locally: $e');
    }
  }

  /// Retrieve cached students when offline
  static Future<List<StudentModel>> getCachedStudents(String schoolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_studentsCacheKey$schoolId');
      if (raw == null || raw.isEmpty) return [];
      final List list = jsonDecode(raw);
      return list.map((e) => StudentModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Error reading cached students: $e');
      return [];
    }
  }

  /// Cache cash fee receipts locally
  static Future<void> cacheFees(String schoolId, List<FeeCollectionModel> fees) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = fees.map((f) => {
        'id': f.id,
        'school_id': f.schoolId,
        'student_id': f.studentId,
        'students': {
          'full_name': f.studentName,
          'roll_no': f.studentRoll,
          'classes': {'name': f.studentClass, 'section': ''},
        },
        'receipt_no': f.receiptNo,
        'amount_paid': f.amountPaid,
        'discount_amount': f.discountAmount,
        'payment_mode': f.paymentMode,
        'payment_date': f.paymentDate.toIso8601String().substring(0, 10),
        'remarks': f.remarks,
      }).toList();
      await prefs.setString('$_feesCacheKey$schoolId', jsonEncode(data));
    } catch (e) {
      debugPrint('Error caching fees locally: $e');
    }
  }

  /// Retrieve cached fee collections when offline
  static Future<List<FeeCollectionModel>> getCachedFees(String schoolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_feesCacheKey$schoolId');
      if (raw == null || raw.isEmpty) return [];
      final List list = jsonDecode(raw);
      return list.map((e) => FeeCollectionModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Error reading cached fees: $e');
      return [];
    }
  }

  /// Queue offline cash fee payment for later cloud sync
  static Future<void> queueOfflineFee(Map<String, dynamic> feeData) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_pendingFeesKey) ?? [];
    list.add(jsonEncode(feeData));
    await prefs.setStringList(_pendingFeesKey, list);
  }

  /// Get pending offline fees count
  static Future<int> getPendingFeesCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingFeesKey) ?? []).length;
  }

  /// Get pending offline fee records for sync
  static Future<List<Map<String, dynamic>>> getPendingFees() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingFeesKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  /// Queue offline attendance roll call for later cloud sync
  static Future<void> queueOfflineAttendance(Map<String, dynamic> attendanceData) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_pendingAttendanceKey) ?? [];
    list.add(jsonEncode(attendanceData));
    await prefs.setStringList(_pendingAttendanceKey, list);
  }

  /// Get pending offline attendance count
  static Future<int> getPendingAttendanceCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingAttendanceKey) ?? []).length;
  }

  /// Get pending offline attendance records for sync
  static Future<List<Map<String, dynamic>>> getPendingAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingAttendanceKey) ?? [];
    return list.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
  }

  /// Clear pending queues after successful synchronization
  static Future<void> clearSyncedQueues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingFeesKey);
    await prefs.remove(_pendingAttendanceKey);
  }
}
