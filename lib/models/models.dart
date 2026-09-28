class SchoolModel {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final int maxStudents;
  final bool isActive;
  final DateTime? validUntil;
  final String currencySymbol;
  final String admissionPrefix;
  final String receiptPrefix;
  final String academicYear;
  final String tagline;
  final int feeDueDay;

  SchoolModel({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    required this.maxStudents,
    required this.isActive,
    this.validUntil,
    this.currencySymbol = '\$',
    this.admissionPrefix = 'SCH-2026-',
    this.receiptPrefix = 'REC-2026-',
    this.academicYear = '2026-2027',
    this.tagline = 'Excellence in Academic Mastery',
    this.feeDueDay = 10,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      logoUrl: json['logo_url'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      maxStudents: (json['max_students'] as num?)?.toInt() ?? 250,
      isActive: json['is_active'] as bool? ?? true,
      validUntil: json['valid_until'] != null ? DateTime.parse(json['valid_until']) : null,
      currencySymbol: json['currency_symbol'] as String? ?? '\$',
      admissionPrefix: json['admission_prefix'] as String? ?? 'SCH-2026-',
      receiptPrefix: json['receipt_prefix'] as String? ?? 'REC-2026-',
      academicYear: json['academic_year'] as String? ?? '2026-2027',
      tagline: json['tagline'] as String? ?? 'Excellence in Academic Mastery',
      feeDueDay: (json['fee_due_day'] as num?)?.toInt() ?? 10,
    );
  }
}


class StudentModel {
  final String id;
  final String schoolId;
  final String admissionNo;
  final String rollNo;
  final String fullName;
  final String? classId;
  final String? className;
  final String? section;
  final String? parentName;
  final String? parentPhone;
  final String? gender;
  final String? bloodGroup;
  final String status;

  final String? dob;
  final String? religion;
  final String? category;
  final String? address;
  final String? emergencyPhone;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final double feeDiscountPercent;
  final String? admissionDate;
  final String? previousSchool;

  StudentModel({
    required this.id,
    required this.schoolId,
    required this.admissionNo,
    required this.rollNo,
    required this.fullName,
    this.classId,
    this.className,
    this.section,
    this.parentName,
    this.parentPhone,
    this.gender,
    this.bloodGroup,
    this.status = 'active',
    this.dob,
    this.religion,
    this.category,
    this.address,
    this.emergencyPhone,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.feeDiscountPercent = 0.0,
    this.admissionDate,
    this.previousSchool,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    // Classes relational join or direct
    String? cName;
    String? cSec;
    if (json['classes'] is Map) {
      cName = json['classes']['name'] as String?;
      cSec = json['classes']['section'] as String?;
    }

    // Parents relational join or direct
    String? pName;
    String? pPhone;
    String? pAddr;
    if (json['parents'] is Map) {
      pName = json['parents']['full_name'] as String?;
      pPhone = json['parents']['phone_number'] as String?;
      pAddr = json['parents']['address'] as String?;
    }

    return StudentModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      admissionNo: json['admission_no'] as String,
      rollNo: json['roll_no'] as String,
      fullName: json['full_name'] as String,
      classId: json['class_id'] as String?,
      className: cName ?? json['class_name'] as String?,
      section: cSec ?? json['section'] as String?,
      parentName: pName ?? json['parent_name'] as String?,
      parentPhone: pPhone ?? json['parent_phone'] as String?,
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      status: json['status'] as String? ?? 'active',
      dob: json['dob'] as String?,
      religion: json['religion'] as String?,
      category: json['category'] as String? ?? 'General',
      address: json['address'] as String? ?? pAddr,
      emergencyPhone: json['emergency_phone'] as String?,
      fatherName: json['father_name'] as String? ?? pName,
      fatherPhone: json['father_phone'] as String? ?? pPhone,
      motherName: json['mother_name'] as String?,
      motherPhone: json['mother_phone'] as String?,
      feeDiscountPercent: (json['fee_discount_percent'] as num?)?.toDouble() ?? 0.0,
      admissionDate: json['admission_date'] as String?,
      previousSchool: json['previous_school'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'admission_no': admissionNo,
      'roll_no': rollNo,
      'full_name': fullName,
      'class_id': classId,
      'class_name': className,
      'section': section,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'gender': gender,
      'blood_group': bloodGroup,
      'status': status,
      'dob': dob,
      'religion': religion,
      'category': category,
      'address': address,
      'emergency_phone': emergencyPhone,
      'father_name': fatherName,
      'father_phone': fatherPhone,
      'mother_name': motherName,
      'mother_phone': motherPhone,
      'fee_discount_percent': feeDiscountPercent,
      'admission_date': admissionDate,
      'previous_school': previousSchool,
    };
  }

  StudentModel copyWith({
    String? id,
    String? schoolId,
    String? admissionNo,
    String? rollNo,
    String? fullName,
    String? classId,
    String? className,
    String? section,
    String? parentName,
    String? parentPhone,
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
  }) {
    return StudentModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      admissionNo: admissionNo ?? this.admissionNo,
      rollNo: rollNo ?? this.rollNo,
      fullName: fullName ?? this.fullName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      section: section ?? this.section,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      status: status ?? this.status,
      dob: dob ?? this.dob,
      religion: religion ?? this.religion,
      category: category ?? this.category,
      address: address ?? this.address,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      fatherName: fatherName ?? this.fatherName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      motherPhone: motherPhone ?? this.motherPhone,
      feeDiscountPercent: feeDiscountPercent ?? this.feeDiscountPercent,
      admissionDate: admissionDate ?? this.admissionDate,
      previousSchool: previousSchool ?? this.previousSchool,
    );
  }
}

class FeeCollectionModel {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final String studentClass;
  final String receiptNo;
  final double amountPaid;
  final double discountAmount;
  final String paymentMode; // 'cash'
  final DateTime paymentDate;
  final String? remarks;

  FeeCollectionModel({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.studentClass,
    required this.receiptNo,
    required this.amountPaid,
    this.discountAmount = 0.0,
    this.paymentMode = 'cash',
    required this.paymentDate,
    this.remarks,
  });

  factory FeeCollectionModel.fromJson(Map<String, dynamic> json) {
    return FeeCollectionModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['students'] != null ? json['students']['full_name'] as String : 'Student',
      studentRoll: json['students'] != null ? json['students']['roll_no'] as String : '',
      studentClass: json['students'] != null && json['students']['classes'] != null 
          ? '${json['students']['classes']['name']}-${json['students']['classes']['section']}'
          : '',
      receiptNo: json['receipt_no'] as String,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String? ?? 'cash',
      paymentDate: DateTime.parse(json['payment_date'] as String),
      remarks: json['remarks'] as String?,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String? parentPhone;
  final String status; // 'present', 'absent', 'late'
  final DateTime date;
  final bool whatsappSent;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    this.parentPhone,
    required this.status,
    required this.date,
    this.whatsappSent = false,
  });
}

class SubjectMarks {
  final String subject;
  final double maxMarks;
  final double passingMarks;
  double marksObtained;

  SubjectMarks({
    required this.subject,
    this.maxMarks = 100.0,
    this.passingMarks = 35.0,
    required this.marksObtained,
  });

  String get grade {
    final pct = (marksObtained / maxMarks) * 100;
    if (pct >= 91) return 'A1';
    if (pct >= 81) return 'A2';
    if (pct >= 71) return 'B1';
    if (pct >= 61) return 'B2';
    if (pct >= 51) return 'C1';
    if (pct >= 41) return 'C2';
    if (pct >= 33) return 'D';
    return 'E';
  }

  String get remarks {
    final pct = (marksObtained / maxMarks) * 100;
    if (pct >= 90) return 'Outstanding';
    if (pct >= 75) return 'Distinction';
    if (pct >= 60) return 'First Class';
    if (pct >= 35) return 'Passed';
    return 'Needs Improvement';
  }
}

class StudentReportCard {
  final StudentModel student;
  final String examName;
  final String academicYear;
  final List<SubjectMarks> subjects;
  final int totalWorkingDays;
  final int daysPresent;
  final String teacherRemarks;

  StudentReportCard({
    required this.student,
    required this.examName,
    this.academicYear = '2026-2027',
    required this.subjects,
    this.totalWorkingDays = 120,
    this.daysPresent = 116,
    this.teacherRemarks = 'Demonstrates strong conceptual grasp and active class participation.',
  });

  double get totalMarksObtained => subjects.fold(0.0, (sum, s) => sum + s.marksObtained);
  double get totalMaxMarks => subjects.fold(0.0, (sum, s) => sum + s.maxMarks);
  double get percentage => totalMaxMarks > 0 ? (totalMarksObtained / totalMaxMarks) * 100 : 0.0;
  double get attendancePercentage => totalWorkingDays > 0 ? (daysPresent / totalWorkingDays) * 100 : 0.0;

  String get overallGrade {
    if (percentage >= 91) return 'A1';
    if (percentage >= 81) return 'A2';
    if (percentage >= 71) return 'B1';
    if (percentage >= 61) return 'B2';
    if (percentage >= 51) return 'C1';
    if (percentage >= 41) return 'C2';
    if (percentage >= 33) return 'D';
    return 'E';
  }

  String get resultStatus => percentage >= 35 ? 'PROMOTED / PASSED' : 'NEEDS IMPROVEMENT';
}

class ClassModel {
  final String id;
  final String schoolId;
  final String name;
  final String section;
  final String? roomNumber;
  final double tuitionFee;
  final double admissionFee;

  ClassModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.section = 'A',
    this.roomNumber,
    this.tuitionFee = 1200.0,
    this.admissionFee = 2500.0,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      name: json['name'] as String,
      section: json['section'] as String? ?? 'A',
      roomNumber: json['room_number'] as String?,
      tuitionFee: (json['tuition_fee'] as num?)?.toDouble() ?? 1200.0,
      admissionFee: (json['admission_fee'] as num?)?.toDouble() ?? 2500.0,
    );
  }
}

class SectionModel {
  final String id;
  final String schoolId;
  final String classId;
  final String name;
  final String? roomNumber;
  final int capacity;

  SectionModel({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.name,
    this.roomNumber,
    this.capacity = 40,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      name: json['name'] as String,
      roomNumber: json['room_number'] as String?,
      capacity: (json['capacity'] as num?)?.toInt() ?? 40,
    );
  }
}

class StaffModel {
  final String id;
  final String schoolId;
  final String employeeCode;
  final String fullName;
  final String? phone;
  final String? email;
  final String role; // 'Principal', 'Teacher', 'Accountant', 'Librarian', 'Admin', 'Staff'
  final String designation;
  final String department;
  final double salary;
  final String? qualification; // Education (e.g. M.Sc / B.Ed)
  final String? specialization;
  final DateTime? joiningDate;
  final bool isActive;

  // eSkooly Employee custom fields
  final String? fatherOrHusbandName;
  final String? gender;
  final String? experience;
  final String? nationalId;
  final String? religion;
  final String? bloodGroup;
  final DateTime? dob;
  final String? homeAddress;
  final String? pictureUrl;

  StaffModel({
    required this.id,
    required this.schoolId,
    required this.employeeCode,
    required this.fullName,
    this.phone,
    this.email,
    this.role = 'Teacher',
    this.designation = 'Senior Faculty',
    this.department = 'Academics',
    this.salary = 35000.0,
    this.qualification,
    this.specialization,
    this.joiningDate,
    this.isActive = true,
    this.fatherOrHusbandName,
    this.gender,
    this.experience,
    this.nationalId,
    this.religion,
    this.bloodGroup,
    this.dob,
    this.homeAddress,
    this.pictureUrl,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? 'EMP-000',
      fullName: json['full_name'] as String? ?? 'Staff Member',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'Teacher',
      designation: json['designation'] as String? ?? 'Faculty',
      department: json['department'] as String? ?? 'Academics',
      salary: (json['salary'] as num?)?.toDouble() ?? 35000.0,
      qualification: json['qualification'] as String? ?? json['education'] as String?,
      specialization: json['specialization'] as String?,
      joiningDate: json['joining_date'] != null ? DateTime.tryParse(json['joining_date'].toString()) : null,
      isActive: json['is_active'] as bool? ?? true,
      fatherOrHusbandName: json['father_or_husband_name'] as String?,
      gender: json['gender'] as String?,
      experience: json['experience'] as String?,
      nationalId: json['national_id'] as String?,
      religion: json['religion'] as String?,
      bloodGroup: json['blood_group'] as String?,
      dob: json['dob'] != null ? DateTime.tryParse(json['dob'].toString()) : null,
      homeAddress: json['home_address'] as String? ?? json['address'] as String?,
      pictureUrl: json['picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'joining_date': joiningDate?.toIso8601String().substring(0, 10),
      'is_active': isActive,
      'father_or_husband_name': fatherOrHusbandName,
      'gender': gender,
      'experience': experience,
      'national_id': nationalId,
      'religion': religion,
      'blood_group': bloodGroup,
      'dob': dob?.toIso8601String().substring(0, 10),
      'home_address': homeAddress,
      'picture_url': pictureUrl,
    };
  }

  StaffModel copyWith({
    String? id,
    String? schoolId,
    String? employeeCode,
    String? fullName,
    String? phone,
    String? email,
    String? role,
    String? designation,
    String? department,
    double? salary,
    String? qualification,
    String? specialization,
    DateTime? joiningDate,
    bool? isActive,
    String? fatherOrHusbandName,
    String? gender,
    String? experience,
    String? nationalId,
    String? religion,
    String? bloodGroup,
    DateTime? dob,
    String? homeAddress,
    String? pictureUrl,
  }) {
    return StaffModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      salary: salary ?? this.salary,
      qualification: qualification ?? this.qualification,
      specialization: specialization ?? this.specialization,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      fatherOrHusbandName: fatherOrHusbandName ?? this.fatherOrHusbandName,
      gender: gender ?? this.gender,
      experience: experience ?? this.experience,
      nationalId: nationalId ?? this.nationalId,
      religion: religion ?? this.religion,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dob: dob ?? this.dob,
      homeAddress: homeAddress ?? this.homeAddress,
      pictureUrl: pictureUrl ?? this.pictureUrl,
    );
  }
}

class FeeInvoiceModel {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final String className;
  final String invoiceNo;
  final String month;
  final DateTime dueDate;
  final double amount;
  final double discount;
  final double paidAmount;
  final String status; // 'Paid', 'Unpaid', 'Partially Paid', 'Overdue'

  FeeInvoiceModel({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.className,
    required this.invoiceNo,
    required this.month,
    required this.dueDate,
    required this.amount,
    this.discount = 0.0,
    this.paidAmount = 0.0,
    required this.status,
  });

  double get netPayable => (amount - discount);
  double get remainingBalance => (netPayable - paidAmount) > 0 ? (netPayable - paidAmount) : 0.0;

  factory FeeInvoiceModel.fromJson(Map<String, dynamic> json) {
    return FeeInvoiceModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      studentId: json['student_id'] as String,
      studentName: json['students'] != null ? json['students']['full_name'] as String : 'Student',
      studentRoll: json['students'] != null ? json['students']['roll_no'] as String : '',
      className: json['students'] != null && json['students']['classes'] != null
          ? json['students']['classes']['name'] as String
          : 'Class',
      invoiceNo: json['invoice_no'] as String,
      month: json['month'] as String? ?? 'Current Month',
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Unpaid',
    );
  }
}

class ExpenseModel {
  final String id;
  final String schoolId;
  final String category; // 'Salaries', 'Utilities', 'Maintenance', 'Supplies', 'Other'
  final String voucherNo;
  final double amount;
  final String paidTo;
  final DateTime paymentDate;
  final String? remarks;

  ExpenseModel({
    required this.id,
    required this.schoolId,
    required this.category,
    required this.voucherNo,
    required this.amount,
    required this.paidTo,
    required this.paymentDate,
    this.remarks,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      category: json['category'] as String,
      voucherNo: json['voucher_no'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidTo: json['paid_to'] as String,
      paymentDate: DateTime.tryParse(json['payment_date']?.toString() ?? '') ?? DateTime.now(),
      remarks: json['remarks'] as String?,
    );
  }
}

class GradingScaleModel {
  final String id;
  final String schoolId;
  final String gradeName;
  final double minPercentage;
  final double maxPercentage;
  final double gradePoint;
  final String? remarks;

  GradingScaleModel({
    required this.id,
    required this.schoolId,
    required this.gradeName,
    required this.minPercentage,
    required this.maxPercentage,
    required this.gradePoint,
    this.remarks,
  });

  factory GradingScaleModel.fromJson(Map<String, dynamic> json) {
    return GradingScaleModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      gradeName: json['grade_name'] as String,
      minPercentage: (json['min_percentage'] as num).toDouble(),
      maxPercentage: (json['max_percentage'] as num).toDouble(),
      gradePoint: (json['grade_point'] as num).toDouble(),
      remarks: json['remarks'] as String?,
    );
  }
}

class WeightedMarkModel {
  final String id;
  final String schoolId;
  final String? examId;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final String subjectName;
  final double assignmentMarks;
  final double midtermMarks;
  final double finalExamMarks;
  final double totalWeightedMarks;
  final String grade;
  final String? remarks;

  WeightedMarkModel({
    required this.id,
    required this.schoolId,
    this.examId,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.subjectName,
    required this.assignmentMarks,
    required this.midtermMarks,
    required this.finalExamMarks,
    required this.totalWeightedMarks,
    required this.grade,
    this.remarks,
  });

  factory WeightedMarkModel.fromJson(Map<String, dynamic> json) {
    return WeightedMarkModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      examId: json['exam_id'] as String?,
      studentId: json['student_id'] as String,
      studentName: json['students'] != null ? json['students']['full_name'] as String : 'Student',
      studentRoll: json['students'] != null ? json['students']['roll_no'] as String : '',
      subjectName: json['subject_name'] as String? ?? 'General',
      assignmentMarks: (json['assignment_marks'] as num?)?.toDouble() ?? 0.0,
      midtermMarks: (json['midterm_marks'] as num?)?.toDouble() ?? 0.0,
      finalExamMarks: (json['final_exam_marks'] as num?)?.toDouble() ?? 0.0,
      totalWeightedMarks: (json['total_weighted_marks'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] as String? ?? 'F',
      remarks: json['remarks'] as String?,
    );
  }
}

class TimetableSlotModel {
  final String id;
  final String schoolId;
  final String classId;
  final String section;
  final String dayOfWeek;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String subjectName;
  final String? teacherId;
  final String? teacherName;
  final String? roomNumber;

  TimetableSlotModel({
    required this.id,
    required this.schoolId,
    required this.classId,
    this.section = 'A',
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    this.teacherId,
    this.teacherName,
    this.roomNumber,
  });

  factory TimetableSlotModel.fromJson(Map<String, dynamic> json) {
    return TimetableSlotModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      section: json['section'] as String? ?? 'A',
      dayOfWeek: json['day_of_week'] as String? ?? 'Monday',
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 1,
      startTime: json['start_time'] as String? ?? '08:00',
      endTime: json['end_time'] as String? ?? '08:45',
      subjectName: json['subject_name'] as String? ?? 'Mathematics',
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teachers'] != null ? json['teachers']['full_name'] as String? : null,
      roomNumber: json['room_number'] as String? ?? 'Room 101',
    );
  }
}

class LessonPlanModel {
  final String id;
  final String schoolId;
  final String classId;
  final String? className;
  final String subjectName;
  final String? teacherId;
  final String? teacherName;
  final String topicTitle;
  final String? objectives;
  final DateTime plannedDate;
  final String status; // 'Planned', 'In Progress', 'Completed'

  LessonPlanModel({
    required this.id,
    required this.schoolId,
    required this.classId,
    this.className,
    required this.subjectName,
    this.teacherId,
    this.teacherName,
    required this.topicTitle,
    this.objectives,
    required this.plannedDate,
    this.status = 'Planned',
  });

  factory LessonPlanModel.fromJson(Map<String, dynamic> json) {
    return LessonPlanModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      className: json['classes'] != null ? json['classes']['name'] as String? : null,
      subjectName: json['subject_name'] as String? ?? 'General',
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teachers'] != null ? json['teachers']['full_name'] as String? : null,
      topicTitle: json['topic_title'] as String? ?? '',
      objectives: json['objectives'] as String?,
      plannedDate: DateTime.tryParse(json['planned_date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'Planned',
    );
  }
}

class TeachingLogModel {
  final String id;
  final String schoolId;
  final String teacherId;
  final String? teacherName;
  final String classId;
  final String? className;
  final String subjectName;
  final DateTime date;
  final int periodNumber;
  final String activitySummary;
  final String? homeworkAssigned;

  TeachingLogModel({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    this.teacherName,
    required this.classId,
    this.className,
    required this.subjectName,
    required this.date,
    this.periodNumber = 1,
    required this.activitySummary,
    this.homeworkAssigned,
  });

  factory TeachingLogModel.fromJson(Map<String, dynamic> json) {
    return TeachingLogModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teachers'] != null ? json['teachers']['full_name'] as String? : null,
      classId: json['class_id'] as String? ?? '',
      className: json['classes'] != null ? json['classes']['name'] as String? : null,
      subjectName: json['subject_name'] as String? ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      periodNumber: (json['period_number'] as num?)?.toInt() ?? 1,
      activitySummary: json['activity_summary'] as String? ?? '',
      homeworkAssigned: json['homework_assigned'] as String?,
    );
  }
}

class PtmSlotModel {
  final String id;
  final String schoolId;
  final String teacherId;
  final String? teacherName;
  final String? studentId;
  final String? studentName;
  final DateTime slotDate;
  final String slotTime;
  final String status; // 'Available', 'Booked', 'Completed'
  final String? notes;

  PtmSlotModel({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    this.teacherName,
    this.studentId,
    this.studentName,
    required this.slotDate,
    required this.slotTime,
    this.status = 'Available',
    this.notes,
  });

  factory PtmSlotModel.fromJson(Map<String, dynamic> json) {
    return PtmSlotModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teachers'] != null ? json['teachers']['full_name'] as String? : null,
      studentId: json['student_id'] as String?,
      studentName: json['students'] != null ? json['students']['full_name'] as String? : null,
      slotDate: DateTime.tryParse(json['slot_date']?.toString() ?? '') ?? DateTime.now(),
      slotTime: json['slot_time'] as String? ?? '10:00 AM',
      status: json['status'] as String? ?? 'Available',
      notes: json['notes'] as String?,
    );
  }
}

class StudentDisciplineModel {
  final String id;
  final String schoolId;
  final String studentId;
  final String? studentName;
  final String? rollNo;
  final DateTime incidentDate;
  final String category; // 'Behavioral', 'Academic', 'Merit/Award', 'Attendance'
  final String severity; // 'Minor', 'Moderate', 'Major', 'Commendation'
  final String description;
  final String? actionTaken;
  final String? reportedBy;

  StudentDisciplineModel({
    required this.id,
    required this.schoolId,
    required this.studentId,
    this.studentName,
    this.rollNo,
    required this.incidentDate,
    this.category = 'Behavioral',
    this.severity = 'Minor',
    required this.description,
    this.actionTaken,
    this.reportedBy,
  });

  factory StudentDisciplineModel.fromJson(Map<String, dynamic> json) {
    return StudentDisciplineModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['students'] != null ? json['students']['full_name'] as String? : null,
      rollNo: json['students'] != null ? json['students']['roll_no'] as String? : null,
      incidentDate: DateTime.tryParse(json['incident_date']?.toString() ?? '') ?? DateTime.now(),
      category: json['category'] as String? ?? 'Behavioral',
      severity: json['severity'] as String? ?? 'Minor',
      description: json['description'] as String? ?? '',
      actionTaken: json['action_taken'] as String?,
      reportedBy: json['reported_by'] as String?,
    );
  }
}

class SchoolNoticeModel {
  final String id;
  final String schoolId;
  final String title;
  final String content;
  final String targetAudience; // 'All', 'Teachers', 'Parents', 'Students'
  final DateTime publishDate;
  final bool isUrgent;

  SchoolNoticeModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.content,
    this.targetAudience = 'All',
    required this.publishDate,
    this.isUrgent = false,
  });

  factory SchoolNoticeModel.fromJson(Map<String, dynamic> json) {
    return SchoolNoticeModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      targetAudience: json['target_audience'] as String? ?? 'All',
      publishDate: DateTime.tryParse(json['publish_date']?.toString() ?? '') ?? DateTime.now(),
      isUrgent: json['is_urgent'] as bool? ?? false,
    );
  }
}

class InventoryAssetModel {
  final String id;
  final String schoolId;
  final String itemName;
  final String category; // 'IT Hardware', 'Lab Equipment', 'Furniture', 'Sports', 'Library'
  final int quantity;
  final String condition; // 'New', 'Good', 'Needs Repair', 'Discarded'
  final String? location;
  final DateTime? purchaseDate;
  final double cost;

  InventoryAssetModel({
    required this.id,
    required this.schoolId,
    required this.itemName,
    required this.category,
    this.quantity = 1,
    this.condition = 'Good',
    this.location,
    this.purchaseDate,
    this.cost = 0.0,
  });

  factory InventoryAssetModel.fromJson(Map<String, dynamic> json) {
    return InventoryAssetModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      category: json['category'] as String? ?? 'IT Hardware',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      condition: json['condition'] as String? ?? 'Good',
      location: json['location'] as String?,
      purchaseDate: json['purchase_date'] != null ? DateTime.tryParse(json['purchase_date'].toString()) : null,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

