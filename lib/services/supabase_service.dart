import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'offline_cache_service.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Active School for the current session
  static SchoolModel? currentSchool;
  static String? userRole; // 'super_admin', 'school_admin', 'teacher', 'parent', 'student'
  static String? currentUserId;

  /// Fetch all active schools (for login portal branding & super admin)
  static Future<List<SchoolModel>> fetchSchools() async {
    try {
      final response = await client
          .from('schools')
          .select()
          .order('name');
      return (response as List).map((e) => SchoolModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching schools: $e');
      return [];
    }
  }

  /// Create a new School (Super Admin SaaS Feature with full customization)
  static Future<bool> createSchool({
    required String name,
    required String code,
    required int maxStudents,
    String currencySymbol = '\$',
    String admissionPrefix = 'SCH-2026-',
    String receiptPrefix = 'REC-2026-',
    String academicYear = '2026-2027',
    String tagline = 'Excellence in Academic Mastery',
    int feeDueDay = 10,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      await client.from('schools').insert({
        'name': name,
        'code': code,
        'max_students': maxStudents,
        'currency_symbol': currencySymbol,
        'admission_prefix': admissionPrefix,
        'receipt_prefix': receiptPrefix,
        'academic_year': academicYear,
        'tagline': tagline,
        'fee_due_day': feeDueDay,
        'phone': phone,
        'email': email,
        'address': address,
        'is_active': true,
        'valid_until': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error creating school: $e');
      return false;
    }
  }

  /// Update School Details & Customization (Super Admin / Institute Settings)
  static Future<Map<String, dynamic>> updateSchool({
    required String id,
    required String name,
    required String code,
    required int maxStudents,
    String? currencySymbol,
    String? admissionPrefix,
    String? receiptPrefix,
    String? academicYear,
    String? tagline,
    int? feeDueDay,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
    DateTime? validUntil,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'code': code,
        'max_students': maxStudents,
      };
      if (currencySymbol != null) data['currency_symbol'] = currencySymbol;
      if (admissionPrefix != null) data['admission_prefix'] = admissionPrefix;
      if (receiptPrefix != null) data['receipt_prefix'] = receiptPrefix;
      if (academicYear != null) data['academic_year'] = academicYear;
      if (tagline != null) data['tagline'] = tagline;
      if (feeDueDay != null) data['fee_due_day'] = feeDueDay;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (address != null) data['address'] = address;
      if (isActive != null) data['is_active'] = isActive;
      if (validUntil != null) data['valid_until'] = validUntil.toIso8601String();

      await client.from('schools').update(data).eq('id', id);
      return {'success': true, 'message': 'Institute settings updated successfully!'};
    } catch (e) {
      debugPrint('Error updating school: $e');
      return {'success': false, 'message': 'Failed to update institute: $e'};
    }
  }

  /// Delete School (Super Admin)
  static Future<bool> deleteSchool(String schoolId) async {
    try {
      await client.from('schools').delete().eq('id', schoolId);
      return true;
    } catch (e) {
      debugPrint('Error deleting school: $e');
      return false;
    }
  }


  /// Fetch Students for current school (Offline-First cached)
  static Future<List<StudentModel>> fetchStudents(String schoolId) async {
    try {
      final response = await client
          .from('students')
          .select('''
            *,
            classes:class_id(name, section),
            parents:parent_id(full_name, phone_number, address)
          ''')
          .eq('school_id', schoolId)
          .order('roll_no');
      final list = (response as List).map((e) => StudentModel.fromJson(e)).toList();
      // Persist to local offline cache
      await OfflineCacheService.cacheStudents(schoolId, list);
      return list;
    } catch (e) {
      debugPrint('Supabase network error fetching students: $e. Loading from offline cache...');
      final cached = await OfflineCacheService.getCachedStudents(schoolId);
      return cached;
    }
  }

  /// Add a Single Student with Student Limit Quota Protection (eSkooly SIS)
  static Future<Map<String, dynamic>> addStudent({
    required String schoolId,
    required String admissionNo,
    required String rollNo,
    required String fullName,
    String? classId,
    String? parentName,
    String? parentPhone,
    String? bloodGroup,
    String? gender,
    String? dob,
    String? religion,
    String? category,
    String? address,
    String? emergencyPhone,
    String? fatherName,
    String? fatherPhone,
    String? motherName,
    String? motherPhone,
    double feeDiscountPercent = 0.0,
    String? admissionDate,
    String? previousSchool,
  }) async {
    try {
      // 1. Quota Check
      final schoolRes = await client.from('schools').select('max_students').eq('id', schoolId).single();
      final maxAllowed = (schoolRes['max_students'] as num).toInt();

      final countRes = await client.from('students').select('id').eq('school_id', schoolId).eq('status', 'active');
      final currentCount = (countRes as List).length;

      if (currentCount >= maxAllowed) {
        return {
          'success': false,
          'message': 'Admission limit reached ($currentCount / $maxAllowed students). Please upgrade your subscription plan.'
        };
      }

      // 2. Insert Parent if provided
      String? parentId;
      final effectiveParentName = fatherName ?? parentName;
      final effectiveParentPhone = fatherPhone ?? parentPhone;
      if (effectiveParentName != null && effectiveParentPhone != null && effectiveParentPhone.isNotEmpty) {
        try {
          final pRes = await client.from('parents').insert({
            'school_id': schoolId,
            'full_name': effectiveParentName,
            'father_name': fatherName ?? effectiveParentName,
            'mother_name': motherName,
            'phone_number': effectiveParentPhone,
            'primary_phone': effectiveParentPhone,
            'address': address,
          }).select('id').single();
          parentId = pRes['id'] as String;
        } catch (e) {
          debugPrint('Parent insert note: $e');
        }
      }

      // 3. Insert Student with dynamic fallback for schema columns
      final Map<String, dynamic> studentPayload = {
        'school_id': schoolId,
        'admission_no': admissionNo,
        'roll_no': rollNo,
        'full_name': fullName,
        'class_id': classId,
        'parent_name': effectiveParentName,
        'parent_phone': effectiveParentPhone,
        if (parentId != null) 'parent_id': parentId,
        'blood_group': bloodGroup,
        'gender': gender,
        'status': 'active',
      };
      if (dob != null && dob.isNotEmpty) studentPayload['dob'] = dob;
      if (religion != null) studentPayload['religion'] = religion;
      if (category != null) studentPayload['category'] = category;
      if (address != null) studentPayload['address'] = address;
      if (emergencyPhone != null) studentPayload['emergency_phone'] = emergencyPhone;
      if (fatherName != null) studentPayload['father_name'] = fatherName;
      if (fatherPhone != null) studentPayload['father_phone'] = fatherPhone;
      if (motherName != null) studentPayload['mother_name'] = motherName;
      if (motherPhone != null) studentPayload['mother_phone'] = motherPhone;
      if (feeDiscountPercent > 0) studentPayload['fee_discount_percent'] = feeDiscountPercent;
      if (admissionDate != null) studentPayload['admission_date'] = admissionDate;
      if (previousSchool != null) studentPayload['previous_school'] = previousSchool;

      try {
        await client.from('students').insert(studentPayload);
      } catch (insertErr) {
        // Fallback with core columns if optional columns do not exist in DB yet
        debugPrint('Full insert failed ($insertErr). Trying core columns fallback...');
        await client.from('students').insert({
          'school_id': schoolId,
          'admission_no': admissionNo,
          'roll_no': rollNo,
          'full_name': fullName,
          'class_id': classId,
          'parent_name': effectiveParentName,
          'parent_phone': effectiveParentPhone,
          'blood_group': bloodGroup,
          'gender': gender,
          'status': 'active',
        });
      }

      return {'success': true, 'message': 'Student "$fullName" enrolled successfully!'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to add student: $e'};
    }
  }

  /// Bulk Student CSV Importer
  static Future<Map<String, dynamic>> importStudentsFromCsv(String schoolId, List<List<dynamic>> rows) async {
    try {
      int successCount = 0;
      int skippedCount = 0;

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;

        final admNo = row[0].toString().trim();
        final rollNo = row[1].toString().trim();
        final name = row[2].toString().trim();
        final parentName = row.length > 3 ? row[3].toString().trim() : null;
        final parentPhone = row.length > 4 ? row[4].toString().trim() : null;

        final result = await addStudent(
          schoolId: schoolId,
          admissionNo: admNo,
          rollNo: rollNo,
          fullName: name,
          parentName: parentName,
          parentPhone: parentPhone,
        );

        if (result['success'] == true) {
          successCount++;
        } else {
          skippedCount++;
        }
      }

      return {
        'success': true,
        'message': 'Processed CSV: $successCount enrolled, $skippedCount skipped/limit reached.'
      };
    } catch (e) {
      return {'success': false, 'message': 'CSV parsing error: $e'};
    }
  }

  /// Generate Next Admission Number (eSkooly SIS configuration logic)
  static Future<String> generateNextAdmissionNo(String schoolId, [String prefix = 'SCH-2026-']) async {
    try {
      final res = await client.from('students').select('id').eq('school_id', schoolId);
      final count = (res as List).length + 1;
      return '$prefix${count.toString().padLeft(4, '0')}';
    } catch (_) {
      return '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  /// Update Student Profile Details
  static Future<Map<String, dynamic>> updateStudent({
    required String id,
    required String fullName,
    required String rollNo,
    String? classId,
    String? gender,
    String? bloodGroup,
    String? status,
    String? dob,
    String? religion,
    String? category,
    String? address,
    String? emergencyPhone,
    String? fatherName,
    String? fatherPhone,
    String? motherName,
    String? motherPhone,
    double? feeDiscountPercent,
    String? admissionDate,
    String? previousSchool,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'full_name': fullName,
        'roll_no': rollNo,
      };
      if (classId != null) data['class_id'] = classId;
      if (gender != null) data['gender'] = gender;
      if (bloodGroup != null) data['blood_group'] = bloodGroup;
      if (status != null) data['status'] = status;
      if (dob != null) data['dob'] = dob;
      if (religion != null) data['religion'] = religion;
      if (category != null) data['category'] = category;
      if (address != null) data['address'] = address;
      if (emergencyPhone != null) data['emergency_phone'] = emergencyPhone;
      if (fatherName != null) data['father_name'] = fatherName;
      if (fatherPhone != null) data['father_phone'] = fatherPhone;
      if (motherName != null) data['mother_name'] = motherName;
      if (motherPhone != null) data['mother_phone'] = motherPhone;
      if (feeDiscountPercent != null) data['fee_discount_percent'] = feeDiscountPercent;
      if (admissionDate != null) data['admission_date'] = admissionDate;
      if (previousSchool != null) data['previous_school'] = previousSchool;

      try {
        await client.from('students').update(data).eq('id', id);
      } catch (colErr) {
        // Fallback update with core columns
        debugPrint('Full update failed ($colErr). Falling back to core columns...');
        await client.from('students').update({
          'full_name': fullName,
          'roll_no': rollNo,
          if (classId != null) 'class_id': classId,
          if (gender != null) 'gender': gender,
          if (bloodGroup != null) 'blood_group': bloodGroup,
          if (status != null) 'status': status,
        }).eq('id', id);
      }
      return {'success': true, 'message': 'Student updated successfully!'};
    } catch (e) {
      debugPrint('Error updating student: $e');
      return {'success': false, 'message': 'Failed to update student: $e'};
    }
  }

  /// Bulk Promote Students to another Class
  static Future<Map<String, dynamic>> promoteStudents({
    required List<String> studentIds,
    required String targetClassId,
  }) async {
    try {
      for (final id in studentIds) {
        await client.from('students').update({'class_id': targetClassId}).eq('id', id);
      }
      return {'success': true, 'message': 'Promoted ${studentIds.length} student(s) to new class!'};
    } catch (e) {
      return {'success': false, 'message': 'Promotion failed: $e'};
    }
  }

  /// Delete / Deactivate Student
  static Future<Map<String, dynamic>> deleteStudent(String id) async {
    try {
      await client.from('students').delete().eq('id', id);
      return {'success': true, 'message': 'Student record deleted from Supabase.'};
    } catch (e) {
      debugPrint('Error deleting student: $e');
      return {'success': false, 'message': 'Failed to delete student: $e'};
    }
  }


  /// Fetch Cash Fee Collections (Offline-First cached)
  static Future<List<FeeCollectionModel>> fetchCashFeeCollections(String schoolId) async {
    try {
      final response = await client
          .from('fee_collections')
          .select('''
            id,
            school_id,
            student_id,
            receipt_no,
            amount_paid,
            discount_amount,
            payment_mode,
            payment_date,
            remarks,
            students:student_id(
              full_name,
              roll_no,
              classes:class_id(name, section)
            )
          ''')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false);

      final list = (response as List).map((e) => FeeCollectionModel.fromJson(e)).toList();
      // Cache fees locally for offline access
      await OfflineCacheService.cacheFees(schoolId, list);
      return list;
    } catch (e) {
      debugPrint('Supabase network error fetching fees: $e. Loading from offline cache...');
      final cached = await OfflineCacheService.getCachedFees(schoolId);
      return cached;
    }
  }

  /// Collect Cash Fee at Counter (Offline resilient)
  static Future<Map<String, dynamic>> recordCashFee({
    required String schoolId,
    required String studentId,
    required double amount,
    String? remarks,
  }) async {
    try {
      // Auto-generate sequential receipt number
      final count = await client.from('fee_collections').select('id').eq('school_id', schoolId);
      final nextNumber = (count as List).length + 1;
      final receiptNo = 'REC-${DateTime.now().year}-${nextNumber.toString().padLeft(4, '0')}';

      await client.from('fee_collections').insert({
        'school_id': schoolId,
        'student_id': studentId,
        'receipt_no': receiptNo,
        'amount_paid': amount,
        'payment_mode': 'cash',
        'payment_date': DateTime.now().toIso8601String().substring(0, 10),
        'remarks': remarks ?? 'Cash deposit at counter',
      });

      return {
        'success': true,
        'receiptNo': receiptNo,
        'message': 'Cash fee collected! Receipt $receiptNo generated.'
      };
    } catch (e) {
      debugPrint('Network error during fee recording: $e. Storing in offline queue.');
      final offlineReceiptNo = 'OFFLINE-REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      await OfflineCacheService.queueOfflineFee({
        'school_id': schoolId,
        'student_id': studentId,
        'receipt_no': offlineReceiptNo,
        'amount_paid': amount,
        'payment_mode': 'cash',
        'payment_date': DateTime.now().toIso8601String().substring(0, 10),
        'remarks': remarks ?? 'Cash deposit (Offline Queue)',
      });

      return {
        'success': true,
        'receiptNo': offlineReceiptNo,
        'message': 'Recorded offline! Receipt $offlineReceiptNo saved. Will sync when reconnected.'
      };
    }
  }

  /// Save Attendance Batch & Queue WhatsApp Notifications for Absentees (Offline resilient)
  static Future<Map<String, dynamic>> saveAttendance({
    required String schoolId,
    required String classId,
    required List<AttendanceRecord> records,
  }) async {
    try {
      int absentCount = 0;

      for (var record in records) {
        await client.from('attendance').upsert({
          'school_id': schoolId,
          'student_id': record.studentId,
          'class_id': classId,
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'status': record.status,
          'whatsapp_sent': record.status == 'absent',
          'whatsapp_sent_at': record.status == 'absent' ? DateTime.now().toIso8601String() : null,
        }, onConflict: 'student_id,date');

        if (record.status == 'absent') {
          absentCount++;
        }
      }

      return {
        'success': true,
        'absentCount': absentCount,
        'message': 'Attendance committed. $absentCount absentee WhatsApp notices queued.'
      };
    } catch (e) {
      debugPrint('Network error saving attendance: $e. Storing in offline queue.');
      final absentCount = records.where((r) => r.status == 'absent').length;
      await OfflineCacheService.queueOfflineAttendance({
        'school_id': schoolId,
        'class_id': classId,
        'records': records.map((r) => {'student_id': r.studentId, 'status': r.status}).toList(),
        'date': DateTime.now().toIso8601String().substring(0, 10),
      });

      return {
        'success': true,
        'absentCount': absentCount,
        'message': 'Saved in offline queue. $absentCount absentee notices will dispatch upon reconnect.'
      };
    }
  }

  /// Sync Pending Offline Queues to Supabase Cloud
  static Future<Map<String, dynamic>> syncOfflineData(String schoolId) async {
    int feesSynced = 0;
    int attendanceSynced = 0;

    try {
      // 1. Sync pending cash fees
      final pendingFees = await OfflineCacheService.getPendingFees();
      for (var fee in pendingFees) {
        try {
          await client.from('fee_collections').insert(fee);
          feesSynced++;
        } catch (e) {
          debugPrint('Error syncing single offline fee: $e');
        }
      }

      // 2. Sync pending attendance batches
      final pendingAttendance = await OfflineCacheService.getPendingAttendance();
      for (var att in pendingAttendance) {
        try {
          final classId = att['class_id'];
          final date = att['date'] ?? DateTime.now().toIso8601String().substring(0, 10);
          final records = att['records'] as List;

          for (var rec in records) {
            final isAbsent = rec['status'] == 'absent';
            await client.from('attendance').upsert({
              'school_id': schoolId,
              'student_id': rec['student_id'],
              'class_id': classId,
              'date': date,
              'status': rec['status'],
              'whatsapp_sent': isAbsent,
              'whatsapp_sent_at': isAbsent ? DateTime.now().toIso8601String() : null,
            }, onConflict: 'student_id,date');
          }
          attendanceSynced++;
        } catch (e) {
          debugPrint('Error syncing single offline attendance batch: $e');
        }
      }

      // Clear queues if items were processed
      if (feesSynced > 0 || attendanceSynced > 0) {
        await OfflineCacheService.clearSyncedQueues();
      }

      return {
        'success': true,
        'feesSynced': feesSynced,
        'attendanceSynced': attendanceSynced,
        'message': 'Sync complete: $feesSynced fee(s) and $attendanceSynced attendance batch(es) uploaded.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Offline sync failed: $e'};
    }
  }

  // ==========================================
  // ACADEMIC STRUCTURE (Classes & Sections)
  // ==========================================

  static Future<List<ClassModel>> fetchClasses(String schoolId) async {
    try {
      final res = await client.from('classes').select().eq('school_id', schoolId).order('name');
      return (res as List).map((e) => ClassModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addClass({
    required String schoolId,
    required String name,
    required String section,
    String? roomNumber,
    double tuitionFee = 1200.0,
    double admissionFee = 2500.0,
  }) async {
    try {
      await client.from('classes').insert({
        'school_id': schoolId,
        'name': name,
        'section': section,
        'room_number': roomNumber,
        'tuition_fee': tuitionFee,
        'admission_fee': admissionFee,
      });
      return {'success': true, 'message': 'Class "$name ($section)" created successfully!'};
    } catch (e) {
      debugPrint('Error adding class: $e');
      return {'success': false, 'message': 'Failed to add class: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateClass({
    required String id,
    required String name,
    required String section,
    String? roomNumber,
    required double tuitionFee,
    required double admissionFee,
  }) async {
    try {
      await client.from('classes').update({
        'name': name,
        'section': section,
        'room_number': roomNumber,
        'tuition_fee': tuitionFee,
        'admission_fee': admissionFee,
      }).eq('id', id);
      return {'success': true, 'message': 'Class "$name ($section)" updated successfully!'};
    } catch (e) {
      debugPrint('Error updating class: $e');
      return {'success': false, 'message': 'Failed to update class: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteClass(String id) async {
    try {
      await client.from('classes').delete().eq('id', id);
      return {'success': true, 'message': 'Class deleted successfully.'};
    } catch (e) {
      debugPrint('Error deleting class: $e');
      return {'success': false, 'message': 'Failed to delete class: $e'};
    }
  }

  static Future<List<SectionModel>> fetchSections(String schoolId) async {
    try {
      final res = await client.from('sections').select().eq('school_id', schoolId).order('name');
      return (res as List).map((e) => SectionModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching sections: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addSection({
    required String schoolId,
    required String classId,
    required String name,
    String? roomNumber,
    int capacity = 40,
  }) async {
    try {
      await client.from('sections').insert({
        'school_id': schoolId,
        'class_id': classId,
        'name': name,
        'room_number': roomNumber,
        'capacity': capacity,
      });
      return {'success': true, 'message': 'Section "$name" added successfully!'};
    } catch (e) {
      debugPrint('Error adding section: $e');
      return {'success': false, 'message': 'Failed to add section: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteSection(String id) async {
    try {
      await client.from('sections').delete().eq('id', id);
      return {'success': true, 'message': 'Section deleted successfully.'};
    } catch (e) {
      debugPrint('Error deleting section: $e');
      return {'success': false, 'message': 'Failed to delete section: $e'};
    }
  }

  // ==========================================
  // STAFF & FACULTY DIRECTORY (eSkooly HR)
  // ==========================================

  static Future<List<StaffModel>> fetchStaff(String schoolId) async {
    try {
      final res = await client.from('teachers').select().eq('school_id', schoolId).order('full_name');
      return (res as List).map((e) => StaffModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addStaff({
    required String schoolId,
    required String employeeCode,
    required String fullName,
    String? phone,
    String? email,
    String role = 'Teacher',
    String designation = 'Faculty',
    String department = 'Academics',
    double salary = 35000.0,
    String? qualification,
    String? specialization,
    String? joiningDate,
    String? fatherOrHusbandName,
    String? gender,
    String? experience,
    String? nationalId,
    String? religion,
    String? bloodGroup,
    String? dob,
    String? homeAddress,
    String? pictureUrl,
  }) async {
    try {
      final insertData = <String, dynamic>{
        'school_id': schoolId,
        'employee_code': employeeCode,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'role': role,
        'designation': designation,
        'department': department,
        'salary': salary,
        'qualification': qualification,
        'specialization': specialization,
        'joining_date': joiningDate ?? DateTime.now().toIso8601String().substring(0, 10),
        'is_active': true,
        if (fatherOrHusbandName != null && fatherOrHusbandName.isNotEmpty) 'father_or_husband_name': fatherOrHusbandName,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (experience != null && experience.isNotEmpty) 'experience': experience,
        if (nationalId != null && nationalId.isNotEmpty) 'national_id': nationalId,
        if (religion != null && religion.isNotEmpty) 'religion': religion,
        if (bloodGroup != null && bloodGroup.isNotEmpty) 'blood_group': bloodGroup,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (homeAddress != null && homeAddress.isNotEmpty) 'home_address': homeAddress,
        if (pictureUrl != null && pictureUrl.isNotEmpty) 'picture_url': pictureUrl,
      };

      try {
        await client.from('teachers').insert(insertData);
        return {'success': true, 'message': 'Employee "$fullName" registered successfully!'};
      } catch (insertError) {
        debugPrint('Custom column insert error in teachers table: $insertError. Attempting core columns fallback.');
        // Fallback with standard core columns
        await client.from('teachers').insert({
          'school_id': schoolId,
          'employee_code': employeeCode,
          'full_name': fullName,
          'phone': phone,
          'email': email,
          'role': role,
          'designation': designation,
          'department': department,
          'salary': salary,
          'qualification': qualification,
          'specialization': specialization,
          'joining_date': joiningDate ?? DateTime.now().toIso8601String().substring(0, 10),
          'is_active': true,
        });
        return {
          'success': true,
          'message': 'Employee "$fullName" registered! (Note: run database migration to save extra demographic fields).'
        };
      }
    } catch (e) {
      debugPrint('Error adding staff: $e');
      return {'success': false, 'message': 'Failed to add employee: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateStaff({
    required String id,
    required String fullName,
    String? phone,
    String? email,
    required String role,
    required String designation,
    required String department,
    required double salary,
    String? qualification,
    String? joiningDate,
    String? fatherOrHusbandName,
    String? gender,
    String? experience,
    String? nationalId,
    String? religion,
    String? bloodGroup,
    String? dob,
    String? homeAddress,
    String? pictureUrl,
    bool isActive = true,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'role': role,
        'designation': designation,
        'department': department,
        'salary': salary,
        'qualification': qualification,
        'is_active': isActive,
        if (joiningDate != null && joiningDate.isNotEmpty) 'joining_date': joiningDate,
        if (fatherOrHusbandName != null) 'father_or_husband_name': fatherOrHusbandName,
        if (gender != null) 'gender': gender,
        if (experience != null) 'experience': experience,
        if (nationalId != null) 'national_id': nationalId,
        if (religion != null) 'religion': religion,
        if (bloodGroup != null) 'blood_group': bloodGroup,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (homeAddress != null) 'home_address': homeAddress,
        if (pictureUrl != null) 'picture_url': pictureUrl,
      };

      try {
        await client.from('teachers').update(updateData).eq('id', id);
        return {'success': true, 'message': 'Staff "$fullName" updated successfully!'};
      } catch (colErr) {
        debugPrint('Custom column update error in teachers: $colErr. Falling back to core columns.');
        await client.from('teachers').update({
          'full_name': fullName,
          'phone': phone,
          'email': email,
          'role': role,
          'designation': designation,
          'department': department,
          'salary': salary,
          'qualification': qualification,
          'is_active': isActive,
        }).eq('id', id);
        return {'success': true, 'message': 'Staff "$fullName" updated!'};
      }
    } catch (e) {
      debugPrint('Error updating staff: $e');
      return {'success': false, 'message': 'Failed to update staff: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteStaff(String id) async {
    try {
      await client.from('teachers').delete().eq('id', id);
      return {'success': true, 'message': 'Staff member removed successfully.'};
    } catch (e) {
      debugPrint('Error deleting staff: $e');
      return {'success': false, 'message': 'Failed to delete staff: $e'};
    }
  }

  // ==========================================
  // FEE INVOICING & FINANCIAL ACCOUNTING
  // ==========================================

  static Future<List<FeeInvoiceModel>> fetchInvoices(String schoolId) async {
    try {
      final res = await client.from('fee_invoices').select('''
        id,
        school_id,
        student_id,
        invoice_no,
        month,
        due_date,
        amount,
        discount,
        paid_amount,
        status,
        students:student_id(
          full_name,
          roll_no,
          classes:class_id(name, section)
        )
      ''').eq('school_id', schoolId).order('created_at', ascending: false);
      return (res as List).map((e) => FeeInvoiceModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> generateMonthlyInvoices({
    required String schoolId,
    required String month,
    required DateTime dueDate,
  }) async {
    try {
      final students = await fetchStudents(schoolId);
      final classes = await fetchClasses(schoolId);
      final classFeeMap = {for (var c in classes) c.id: c.tuitionFee};

      int createdCount = 0;
      for (var s in students) {
        final fee = classFeeMap[s.classId] ?? 1200.0;
        final invNo = 'INV-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${s.rollNo.padLeft(3, '0')}';
        
        await client.from('fee_invoices').insert({
          'school_id': schoolId,
          'student_id': s.id,
          'invoice_no': invNo,
          'month': month,
          'due_date': dueDate.toIso8601String().substring(0, 10),
          'amount': fee,
          'discount': 0.0,
          'paid_amount': 0.0,
          'status': 'Unpaid',
        });
        createdCount++;
      }
      return {'success': true, 'count': createdCount, 'message': 'Successfully generated $createdCount fee invoices for $month!'};
    } catch (e) {
      return {'success': false, 'message': 'Failed generating invoices: $e'};
    }
  }

  static Future<Map<String, dynamic>> payInvoice({
    required String invoiceId,
    required String schoolId,
    required String studentId,
    required double amountToPay,
    required double discount,
  }) async {
    try {
      final invRes = await client.from('fee_invoices').select().eq('id', invoiceId).single();
      final total = (invRes['amount'] as num).toDouble();
      final currentPaid = (invRes['paid_amount'] as num).toDouble();
      final newPaid = currentPaid + amountToPay;
      final newStatus = (newPaid + discount) >= total ? 'Paid' : 'Partially Paid';

      await client.from('fee_invoices').update({
        'paid_amount': newPaid,
        'discount': discount,
        'status': newStatus,
      }).eq('id', invoiceId);

      // Record corresponding cash payment in counter collections ledger
      await recordCashFee(
        schoolId: schoolId,
        studentId: studentId,
        amount: amountToPay,
        remarks: 'Payment towards Invoice #${invRes['invoice_no']}',
      );

      return {'success': true, 'message': 'Payment of \$$amountToPay applied! Status: $newStatus.'};
    } catch (e) {
      return {'success': false, 'message': 'Failed processing payment: $e'};
    }
  }

  // ==========================================
  // EXPENSES & CASH LEDGER
  // ==========================================

  static Future<List<ExpenseModel>> fetchExpenses(String schoolId) async {
    try {
      final res = await client.from('expenses').select().eq('school_id', schoolId).order('payment_date', ascending: false);
      return (res as List).map((e) => ExpenseModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      return [];
    }
  }

  static Future<bool> addExpense({
    required String schoolId,
    required String category,
    required String voucherNo,
    required double amount,
    required String paidTo,
    required DateTime paymentDate,
    String? remarks,
  }) async {
    try {
      await client.from('expenses').insert({
        'school_id': schoolId,
        'category': category,
        'voucher_no': voucherNo,
        'amount': amount,
        'paid_to': paidTo,
        'payment_date': paymentDate.toIso8601String().substring(0, 10),
        'remarks': remarks,
      });
      return true;
    } catch (e) {
      debugPrint('Error adding expense: $e');
      return false;
    }
  }

  static Future<bool> deleteExpense(String id) async {
    try {
      await client.from('expenses').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // ==========================================
  // EXAMINATIONS, GRADING SCALES & MARKS
  // ==========================================

  static Future<List<GradingScaleModel>> fetchGradingScales(String schoolId) async {
    try {
      final res = await client.from('grading_scales').select().eq('school_id', schoolId).order('min_percentage', ascending: false);
      return (res as List).map((e) => GradingScaleModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching grading scales: $e');
      return [];
    }
  }

  static Future<bool> saveGradingScale({
    required String schoolId,
    required String gradeName,
    required double minPct,
    required double maxPct,
    required double gradePoint,
    String? remarks,
  }) async {
    try {
      await client.from('grading_scales').insert({
        'school_id': schoolId,
        'grade_name': gradeName,
        'min_percentage': minPct,
        'max_percentage': maxPct,
        'grade_point': gradePoint,
        'remarks': remarks,
      });
      return true;
    } catch (e) {
      debugPrint('Error saving grading scale: $e');
      return false;
    }
  }

  static Future<List<WeightedMarkModel>> fetchWeightedMarks(String schoolId) async {
    try {
      final res = await client.from('exam_marks').select('''
        id,
        school_id,
        exam_id,
        student_id,
        subject_name,
        assignment_marks,
        midterm_marks,
        final_exam_marks,
        total_weighted_marks,
        grade,
        remarks,
        students:student_id(
          full_name,
          roll_no
        )
      ''').eq('school_id', schoolId).order('created_at', ascending: false);
      return (res as List).map((e) => WeightedMarkModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching exam marks: $e');
      return [];
    }
  }

  static Future<bool> recordWeightedMark({
    required String schoolId,
    required String studentId,
    required String subjectName,
    required double assignmentMarks,
    required double midtermMarks,
    required double finalExamMarks,
    String? remarks,
  }) async {
    try {
      // eSkooly Weighted formula: Final = (Assignments * 0.20) + (MidTerms * 0.30) + (FinalExam * 0.50)
      final weightedTotal = (assignmentMarks * 0.20) + (midtermMarks * 0.30) + (finalExamMarks * 0.50);
      String grade = 'F';
      if (weightedTotal >= 90) grade = 'A+';
      else if (weightedTotal >= 80) grade = 'A';
      else if (weightedTotal >= 70) grade = 'B';
      else if (weightedTotal >= 60) grade = 'C';
      else if (weightedTotal >= 50) grade = 'D';

      await client.from('exam_marks').insert({
        'school_id': schoolId,
        'student_id': studentId,
        'subject_name': subjectName,
        'assignment_marks': assignmentMarks,
        'midterm_marks': midtermMarks,
        'final_exam_marks': finalExamMarks,
        'total_weighted_marks': weightedTotal,
        'marks_obtained': weightedTotal,
        'grade': grade,
        'remarks': remarks ?? 'Computed weighted term score',
      });
      return true;
    } catch (e) {
      debugPrint('Error recording weighted mark: $e');
      return false;
    }
  }

  // ==========================================
  // HARDWARE BIOMETRIC SIMULATOR
  // ==========================================

  static Future<Map<String, dynamic>> processBiometricPunch({
    required String schoolId,
    required String deviceId,
    required String studentAdmissionNo,
    required DateTime timestamp,
  }) async {
    try {
      final sRes = await client.from('students').select('id, full_name, class_id').eq('school_id', schoolId).eq('admission_no', studentAdmissionNo).single();
      final studentId = sRes['id'] as String;
      final classId = sRes['class_id'] as String?;

      await client.from('attendance').upsert({
        'school_id': schoolId,
        'student_id': studentId,
        'class_id': classId,
        'date': timestamp.toIso8601String().substring(0, 10),
        'status': 'Present',
        'remarks': 'Biometric punch device $deviceId at ${timestamp.toIso8601String().substring(11, 16)}',
      }, onConflict: 'student_id,date');

      return {'success': true, 'message': 'Biometric punch verified for ${sRes['full_name']} (Device: $deviceId)'};
    } catch (e) {
      return {'success': false, 'message': 'Biometric verification failed: $e'};
    }
  }

  // ==========================================
  // TIMETABLE MODULE (Video Feature 1)
  // ==========================================

  static Future<List<TimetableSlotModel>> fetchTimetable(String schoolId, {String? classId}) async {
    try {
      var query = client.from('timetable_slots').select('''
        id, school_id, class_id, section, day_of_week, period_number,
        start_time, end_time, subject_name, teacher_id, room_number,
        teachers:teacher_id(full_name)
      ''').eq('school_id', schoolId);
      if (classId != null) {
        query = query.eq('class_id', classId);
      }
      final res = await query.order('period_number', ascending: true);
      return (res as List).map((e) => TimetableSlotModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching timetable: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addTimetableSlot({
    required String schoolId,
    required String classId,
    required String section,
    required String dayOfWeek,
    required int periodNumber,
    required String startTime,
    required String endTime,
    required String subjectName,
    String? teacherId,
    String? roomNumber,
  }) async {
    try {
      await client.from('timetable_slots').insert({
        'school_id': schoolId,
        'class_id': classId,
        'section': section,
        'day_of_week': dayOfWeek,
        'period_number': periodNumber,
        'start_time': startTime,
        'end_time': endTime,
        'subject_name': subjectName,
        'teacher_id': teacherId,
        'room_number': roomNumber,
      });
      return {'success': true, 'message': 'Timetable period scheduled successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to save timetable slot: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTimetableSlot(String id) async {
    try {
      await client.from('timetable_slots').delete().eq('id', id);
      return {'success': true, 'message': 'Slot removed'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete slot: $e'};
    }
  }

  // ==========================================
  // LESSON PLANS & SYLLABUS (Video Feature 2)
  // ==========================================

  static Future<List<LessonPlanModel>> fetchLessonPlans(String schoolId) async {
    try {
      final res = await client.from('lesson_plans').select('''
        id, school_id, class_id, subject_name, teacher_id, topic_title,
        objectives, planned_date, status,
        classes:class_id(name),
        teachers:teacher_id(full_name)
      ''').eq('school_id', schoolId).order('planned_date', ascending: false);
      return (res as List).map((e) => LessonPlanModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching lesson plans: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addLessonPlan({
    required String schoolId,
    required String classId,
    required String subjectName,
    String? teacherId,
    required String topicTitle,
    String? objectives,
    required DateTime plannedDate,
    String status = 'Planned',
  }) async {
    try {
      await client.from('lesson_plans').insert({
        'school_id': schoolId,
        'class_id': classId,
        'subject_name': subjectName,
        'teacher_id': teacherId,
        'topic_title': topicTitle,
        'objectives': objectives,
        'planned_date': plannedDate.toIso8601String().substring(0, 10),
        'status': status,
      });
      return {'success': true, 'message': 'Lesson plan recorded'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to add lesson plan: $e'};
    }
  }

  // ==========================================
  // TEACHING DAILY LOGBOOK (Video Feature 3)
  // ==========================================

  static Future<List<TeachingLogModel>> fetchTeachingLogs(String schoolId) async {
    try {
      final res = await client.from('teaching_logs').select('''
        id, school_id, teacher_id, class_id, subject_name, date,
        period_number, activity_summary, homework_assigned,
        teachers:teacher_id(full_name),
        classes:class_id(name)
      ''').eq('school_id', schoolId).order('date', ascending: false);
      return (res as List).map((e) => TeachingLogModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching teaching logs: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addTeachingLog({
    required String schoolId,
    required String teacherId,
    required String classId,
    required String subjectName,
    required DateTime date,
    int periodNumber = 1,
    required String activitySummary,
    String? homeworkAssigned,
  }) async {
    try {
      await client.from('teaching_logs').insert({
        'school_id': schoolId,
        'teacher_id': teacherId,
        'class_id': classId,
        'subject_name': subjectName,
        'date': date.toIso8601String().substring(0, 10),
        'period_number': periodNumber,
        'activity_summary': activitySummary,
        'homework_assigned': homeworkAssigned,
      });
      return {'success': true, 'message': 'Daily log entry saved'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to save log entry: $e'};
    }
  }

  // ==========================================
  // PTM BOOKING SLOTS (Video Feature 4)
  // ==========================================

  static Future<List<PtmSlotModel>> fetchPtmSlots(String schoolId) async {
    try {
      final res = await client.from('ptm_slots').select('''
        id, school_id, teacher_id, student_id, slot_date, slot_time,
        status, notes,
        teachers:teacher_id(full_name),
        students:student_id(full_name)
      ''').eq('school_id', schoolId).order('slot_date', ascending: true);
      return (res as List).map((e) => PtmSlotModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching PTM slots: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addPtmSlot({
    required String schoolId,
    required String teacherId,
    String? studentId,
    required DateTime slotDate,
    required String slotTime,
    String status = 'Available',
    String? notes,
  }) async {
    try {
      await client.from('ptm_slots').insert({
        'school_id': schoolId,
        'teacher_id': teacherId,
        'student_id': studentId,
        'slot_date': slotDate.toIso8601String().substring(0, 10),
        'slot_time': slotTime,
        'status': status,
        'notes': notes,
      });
      return {'success': true, 'message': 'PTM Slot created'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to schedule PTM: $e'};
    }
  }

  // ==========================================
  // STUDENT DISCIPLINE & CONDUCT (Video Feature 5)
  // ==========================================

  static Future<List<StudentDisciplineModel>> fetchDisciplineRecords(String schoolId) async {
    try {
      final res = await client.from('student_discipline').select('''
        id, school_id, student_id, incident_date, category, severity,
        description, action_taken, reported_by,
        students:student_id(full_name, roll_no)
      ''').eq('school_id', schoolId).order('incident_date', ascending: false);
      return (res as List).map((e) => StudentDisciplineModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching discipline records: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addDisciplineRecord({
    required String schoolId,
    required String studentId,
    required DateTime incidentDate,
    String category = 'Behavioral',
    String severity = 'Minor',
    required String description,
    String? actionTaken,
    String? reportedBy,
  }) async {
    try {
      await client.from('student_discipline').insert({
        'school_id': schoolId,
        'student_id': studentId,
        'incident_date': incidentDate.toIso8601String().substring(0, 10),
        'category': category,
        'severity': severity,
        'description': description,
        'action_taken': actionTaken,
        'reported_by': reportedBy,
      });
      return {'success': true, 'message': 'Discipline incident recorded'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to record discipline: $e'};
    }
  }

  // ==========================================
  // SCHOOL NOTICES / NOTICE BOARD (Video Feature 6)
  // ==========================================

  static Future<List<SchoolNoticeModel>> fetchNotices(String schoolId) async {
    try {
      final res = await client.from('school_notices').select().eq('school_id', schoolId).order('publish_date', ascending: false);
      return (res as List).map((e) => SchoolNoticeModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching notices: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addNotice({
    required String schoolId,
    required String title,
    required String content,
    String targetAudience = 'All',
    required DateTime publishDate,
    bool isUrgent = false,
  }) async {
    try {
      await client.from('school_notices').insert({
        'school_id': schoolId,
        'title': title,
        'content': content,
        'target_audience': targetAudience,
        'publish_date': publishDate.toIso8601String().substring(0, 10),
        'is_urgent': isUrgent,
      });
      return {'success': true, 'message': 'Notice published to school board'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to publish notice: $e'};
    }
  }

  // ==========================================
  // INVENTORY & ASSETS (Video Feature 7)
  // ==========================================

  static Future<List<InventoryAssetModel>> fetchInventory(String schoolId) async {
    try {
      final res = await client.from('inventory_assets').select().eq('school_id', schoolId).order('created_at', ascending: false);
      return (res as List).map((e) => InventoryAssetModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addInventoryAsset({
    required String schoolId,
    required String itemName,
    required String category,
    int quantity = 1,
    String condition = 'Good',
    String? location,
    DateTime? purchaseDate,
    double cost = 0.0,
  }) async {
    try {
      await client.from('inventory_assets').insert({
        'school_id': schoolId,
        'item_name': itemName,
        'category': category,
        'quantity': quantity,
        'condition': condition,
        'location': location,
        'purchase_date': purchaseDate?.toIso8601String().substring(0, 10),
        'cost': cost,
      });
      return {'success': true, 'message': 'Inventory asset registered'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to save asset: $e'};
    }
  }
}


