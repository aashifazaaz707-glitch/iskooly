import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/pdf_print_service.dart';
import '../auth/sign_in_screen.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'academic_hub_dialog.dart';

class AdminShellScreen extends StatefulWidget {
  final SchoolModel school;
  const AdminShellScreen({super.key, required this.school});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late SchoolModel _activeSchool;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  int _pendingOfflineCount = 0;

  // Domain Data Lists
  List<StudentModel> _students = [];
  List<ClassModel> _classes = [];
  List<SectionModel> _sections = [];
  List<StaffModel> _staff = [];
  List<FeeCollectionModel> _fees = [];
  List<FeeInvoiceModel> _invoices = [];
  List<ExpenseModel> _expenses = [];
  List<GradingScaleModel> _gradingScales = [];
  List<WeightedMarkModel> _weightedMarks = [];

  // Filters & Searches
  String _studentSearch = '';
  String? _studentClassFilter;
  String? _studentSectionFilter;
  String _studentStatusFilter = 'All';
  String _studentGenderFilter = 'All';
  String _staffSearch = '';
  String _staffRoleFilter = 'All';
  String _staffStatusFilter = 'All';
  String _invoiceStatusFilter = 'All';

  // Attendance State
  DateTime _attendanceDate = DateTime.now();
  ClassModel? _attendanceClass;
  final Map<String, String> _attendanceMap = {}; // studentId -> 'Present' | 'Absent' | 'Late' | 'HalfDay'

  // Print Configuration
  int _idCardsPerPage = 8; // 4, 8, 10
  int _receiptsPerPage = 2; // 1, 2, 3

  @override
  void initState() {
    super.initState();
    _activeSchool = widget.school;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final schoolId = _activeSchool.id;

    final students = await SupabaseService.fetchStudents(schoolId);
    final classes = await SupabaseService.fetchClasses(schoolId);
    final sections = await SupabaseService.fetchSections(schoolId);
    final staff = await SupabaseService.fetchStaff(schoolId);
    final fees = await SupabaseService.fetchCashFeeCollections(schoolId);
    final invoices = await SupabaseService.fetchInvoices(schoolId);
    final expenses = await SupabaseService.fetchExpenses(schoolId);
    final grading = await SupabaseService.fetchGradingScales(schoolId);
    final marks = await SupabaseService.fetchWeightedMarks(schoolId);
    final pendingFees = await OfflineCacheService.getPendingFeesCount();
    final pendingAtt = await OfflineCacheService.getPendingAttendanceCount();

    // Default attendance class if not set
    ClassModel? defaultAttClass = _attendanceClass;
    if (defaultAttClass == null && classes.isNotEmpty) {
      defaultAttClass = classes.first;
    }

    // Initialize attendance map for default class students
    final Map<String, String> initialAtt = {};
    if (defaultAttClass != null) {
      final classStudents = students.where((s) => s.classId == defaultAttClass!.id || (s.className != null && s.className!.contains(defaultAttClass.name)));
      for (var s in classStudents) {
        initialAtt[s.id] = 'Present';
      }
    }

    setState(() {
      _students = students;
      _classes = classes;
      _sections = sections;
      _staff = staff;
      _fees = fees;
      _invoices = invoices;
      _expenses = expenses;
      _gradingScales = grading;
      _weightedMarks = marks;
      _pendingOfflineCount = pendingFees + pendingAtt;
      _attendanceClass = defaultAttClass;
      if (_attendanceMap.isEmpty) {
        _attendanceMap.addAll(initialAtt);
      }
      _isLoading = false;
    });
  }

  Future<void> _handleManualSync() async {
    setState(() => _isLoading = true);
    final res = await SupabaseService.syncOfflineData(_activeSchool.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'Sync completed'),
        backgroundColor: res['success'] == true ? AppTheme.success : AppTheme.danger,
      ),
    );
    await _loadAllData();
  }

  // =====================================================================
  // NOTIFICATION & MODAL FEEDBACK HELPERS
  // =====================================================================

  void _showFeedback(String message, {bool isSuccess = true, String? errorDetail}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                errorDetail != null && errorDetail.isNotEmpty
                    ? '$message: $errorDetail'
                    : message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isSuccess ? 3 : 5),
      ),
    );
  }

  Future<void> _confirmDelete({
    required String title,
    required String message,
    required Future<Map<String, dynamic>> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await onConfirm();
      _showFeedback(res['message'] ?? (res['success'] == true ? 'Deleted successfully' : 'Failed to delete'), isSuccess: res['success'] == true);
      if (res['success'] == true) {
        _loadAllData();
      }
    }
  }

  // =====================================================================
  // 1. DIALOGS FOR CLASSES & ACADEMIC SETUP
  // =====================================================================

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final sectionCtrl = TextEditingController(text: 'A');
    final roomCtrl = TextEditingController(text: 'Room 101');
    final tuitionCtrl = TextEditingController(text: '1200.00');
    final admissionCtrl = TextEditingController(text: '2500.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Academic Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Class Name (e.g. Grade 10, Nursery)')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: sectionCtrl, decoration: const InputDecoration(labelText: 'Section (e.g. A, B)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room Number'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: tuitionCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Tuition Fee (${_activeSchool.currencySymbol})'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: admissionCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Admission Fee (${_activeSchool.currencySymbol})'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final tFee = double.tryParse(tuitionCtrl.text) ?? 1200.0;
              final aFee = double.tryParse(admissionCtrl.text) ?? 2500.0;
              final res = await SupabaseService.addClass(
                schoolId: _activeSchool.id,
                name: nameCtrl.text.trim(),
                section: sectionCtrl.text.trim(),
                roomNumber: roomCtrl.text.trim(),
                tuitionFee: tFee,
                admissionFee: aFee,
              );
              _showFeedback(res['message'] ?? (res['success'] == true ? 'Class created successfully!' : 'Failed to create class'), isSuccess: res['success'] == true);
              if (res['success'] == true) {
                _loadAllData();
              }
            },
            child: const Text('Create Class'),
          ),
        ],
      ),
    );
  }

  void _showEditClassDialog(ClassModel c) {
    final nameCtrl = TextEditingController(text: c.name);
    final sectionCtrl = TextEditingController(text: c.section);
    final roomCtrl = TextEditingController(text: c.roomNumber ?? '');
    final tuitionCtrl = TextEditingController(text: c.tuitionFee.toStringAsFixed(2));
    final admissionCtrl = TextEditingController(text: c.admissionFee.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Class: ${c.name} (${c.section})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Class Name')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: sectionCtrl, decoration: const InputDecoration(labelText: 'Section (e.g. A, B)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room Number'))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: tuitionCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Tuition Fee (${_activeSchool.currencySymbol})'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: admissionCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Admission Fee (${_activeSchool.currencySymbol})'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final tFee = double.tryParse(tuitionCtrl.text) ?? c.tuitionFee;
              final aFee = double.tryParse(admissionCtrl.text) ?? c.admissionFee;
              final res = await SupabaseService.updateClass(
                id: c.id,
                name: nameCtrl.text.trim(),
                section: sectionCtrl.text.trim(),
                roomNumber: roomCtrl.text.trim(),
                tuitionFee: tFee,
                admissionFee: aFee,
              );
              _showFeedback(res['message'] ?? (res['success'] == true ? 'Class updated successfully!' : 'Failed to update class'), isSuccess: res['success'] == true);
              if (res['success'] == true) {
                _loadAllData();
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showAddSectionDialog(String classId) {
    final nameCtrl = TextEditingController(text: 'Section B');
    final roomCtrl = TextEditingController(text: 'Room 202');
    final capCtrl = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section to Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Section Name')),
            const SizedBox(height: 10),
            TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Assigned Room Number')),
            const SizedBox(height: 10),
            TextField(controller: capCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Student Capacity')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.addSection(
                schoolId: _activeSchool.id,
                classId: classId,
                name: nameCtrl.text.trim(),
                roomNumber: roomCtrl.text.trim(),
                capacity: int.tryParse(capCtrl.text) ?? 40,
              );
              _showFeedback(res['message'] ?? (res['success'] == true ? 'Section added successfully!' : 'Failed to add section'), isSuccess: res['success'] == true);
              if (res['success'] == true) {
                _loadAllData();
              }
            },
            child: const Text('Add Section'),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // 2. DIALOGS & MODALS FOR STUDENT INFORMATION SYSTEM (SIS - eSkooly Style)
  // =====================================================================

  void _showEnrollStudentDialog() async {
    final autoAdm = await SupabaseService.generateNextAdmissionNo(_activeSchool.id, _activeSchool.admissionPrefix);
    final admCtrl = TextEditingController(text: autoAdm);
    final rollCtrl = TextEditingController(text: '${_students.length + 1}');
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final fatherPhoneCtrl = TextEditingController();
    final motherCtrl = TextEditingController();
    final motherPhoneCtrl = TextEditingController();
    final emergencyPhoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final prevSchoolCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');

    String? selectedClassId = _classes.isNotEmpty ? _classes.first.id : null;
    String gender = 'Male';
    String bloodGroup = 'O+';
    String religion = 'Islam';
    String category = 'General';
    DateTime? dob = DateTime(2014, 1, 1);
    DateTime admissionDate = DateTime.now();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.person_add, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Admit New Student (eSkooly SIS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: ACADEMIC DETAILS ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Icon(Icons.school, size: 16, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('1. Academic & Enrollment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: admCtrl,
                          decoration: const InputDecoration(labelText: 'Admission No. *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: rollCtrl,
                          decoration: const InputDecoration(labelText: 'Roll Number *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Assigned Class *'),
                          items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.section}) - ${_activeSchool.currencySymbol}${c.tuitionFee}/mo'))).toList(),
                          onChanged: (val) => setDState(() => selectedClassId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 2: STUDENT DEMOGRAPHICS ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Icon(Icons.badge, size: 16, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('2. Student Demographics & Identity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Student Full Name *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(labelText: 'Gender'),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setDState(() => gender = val ?? 'Male'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: bloodGroup,
                          decoration: const InputDecoration(labelText: 'Blood Group'),
                          items: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (val) => setDState(() => bloodGroup = val ?? 'O+'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dob ?? DateTime(2014, 1, 1),
                              firstDate: DateTime(1995),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setDState(() => dob = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth',
                              suffixIcon: Icon(Icons.calendar_today, size: 16),
                            ),
                            child: Text(
                              dob != null ? DateFormat('dd MMM yyyy').format(dob!) : 'Select Date',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: religion,
                          decoration: const InputDecoration(labelText: 'Religion'),
                          items: const ['Islam', 'Christianity', 'Hinduism', 'Sikhism', 'Other']
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) => setDState(() => religion = val ?? 'Islam'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: const ['General', 'OBC', 'SC', 'ST', 'Scholarship', 'Special Needs']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) => setDState(() => category = val ?? 'General'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 3: PARENT & CONTACT INFORMATION ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Icon(Icons.family_restroom, size: 16, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('3. Parent & Guardian Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fatherCtrl,
                          decoration: const InputDecoration(labelText: "Father's / Guardian's Name"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: fatherPhoneCtrl,
                          decoration: const InputDecoration(labelText: "Father's Mobile (SMS/WhatsApp)"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: motherCtrl,
                          decoration: const InputDecoration(labelText: "Mother's Name"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emergencyPhoneCtrl,
                          decoration: const InputDecoration(labelText: 'Emergency Contact Phone'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Residential Home Address'),
                  ),
                  const SizedBox(height: 16),

                  // --- SECTION 4: FINANCIAL CONCESSION & PREVIOUS SCHOOL ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Icon(Icons.discount, size: 16, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('4. Fee Discount & Previous Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fee Concession / Discount (%)',
                            suffixText: '%',
                            helperText: 'e.g. 10 for 10% off monthly tuition',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: prevSchoolCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Previous School Attended (if any)',
                            helperText: 'For transfer certificates and records',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                if (admCtrl.text.isEmpty || rollCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                  _showFeedback('Please fill all mandatory fields (Name, Admission No, Roll No).', isSuccess: false);
                  return;
                }
                Navigator.pop(ctx);
                final res = await SupabaseService.addStudent(
                  schoolId: _activeSchool.id,
                  admissionNo: admCtrl.text.trim(),
                  rollNo: rollCtrl.text.trim(),
                  fullName: nameCtrl.text.trim(),
                  classId: selectedClassId,
                  parentName: fatherCtrl.text.trim().isNotEmpty ? fatherCtrl.text.trim() : motherCtrl.text.trim(),
                  parentPhone: fatherPhoneCtrl.text.trim(),
                  bloodGroup: bloodGroup,
                  gender: gender,
                  dob: dob != null ? DateFormat('yyyy-MM-dd').format(dob!) : null,
                  religion: religion,
                  category: category,
                  address: addressCtrl.text.trim(),
                  emergencyPhone: emergencyPhoneCtrl.text.trim(),
                  fatherName: fatherCtrl.text.trim(),
                  fatherPhone: fatherPhoneCtrl.text.trim(),
                  motherName: motherCtrl.text.trim(),
                  motherPhone: motherPhoneCtrl.text.trim(),
                  feeDiscountPercent: double.tryParse(discountCtrl.text) ?? 0.0,
                  admissionDate: DateFormat('yyyy-MM-dd').format(admissionDate),
                  previousSchool: prevSchoolCtrl.text.trim(),
                );
                _showFeedback(res['message'] ?? (res['success'] == true ? 'Admission completed!' : 'Failed to admit student'), isSuccess: res['success'] == true);
                if (res['success'] == true) {
                  _loadAllData();
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete Admission'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(StudentModel student) {
    final nameCtrl = TextEditingController(text: student.fullName);
    final rollCtrl = TextEditingController(text: student.rollNo);
    final admCtrl = TextEditingController(text: student.admissionNo);
    final fatherCtrl = TextEditingController(text: student.fatherName ?? student.parentName ?? '');
    final fatherPhoneCtrl = TextEditingController(text: student.fatherPhone ?? student.parentPhone ?? '');
    final motherCtrl = TextEditingController(text: student.motherName ?? '');
    final motherPhoneCtrl = TextEditingController(text: student.motherPhone ?? '');
    final emergencyPhoneCtrl = TextEditingController(text: student.emergencyPhone ?? '');
    final addressCtrl = TextEditingController(text: student.address ?? '');
    final prevSchoolCtrl = TextEditingController(text: student.previousSchool ?? '');
    final discountCtrl = TextEditingController(text: student.feeDiscountPercent.toStringAsFixed(0));

    String? selectedClassId = student.classId ?? (_classes.isNotEmpty ? _classes.first.id : null);
    String status = student.status;
    String gender = student.gender ?? 'Male';
    String bloodGroup = student.bloodGroup ?? 'O+';
    String religion = student.religion ?? 'Islam';
    String category = student.category ?? 'General';
    DateTime? dob;
    if (student.dob != null && student.dob!.isNotEmpty) {
      try {
        dob = DateTime.parse(student.dob!);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Edit Student: ${student.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: admCtrl, readOnly: true, decoration: const InputDecoration(labelText: 'Admission No (Locked)')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: rollCtrl, decoration: const InputDecoration(labelText: 'Roll Number *')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active Enrolled')),
                            DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                            DropdownMenuItem(value: 'graduated', child: Text('Graduated')),
                          ],
                          onChanged: (val) => setDState(() => status = val ?? 'active'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Class'),
                          items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.section})'))).toList(),
                          onChanged: (val) => setDState(() => selectedClassId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(labelText: 'Gender'),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setDState(() => gender = val ?? 'Male'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: bloodGroup,
                          decoration: const InputDecoration(labelText: 'Blood Group'),
                          items: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (val) => setDState(() => bloodGroup = val ?? 'O+'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: const ['General', 'OBC', 'SC', 'ST', 'Scholarship', 'Special Needs']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) => setDState(() => category = val ?? 'General'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: fatherCtrl, decoration: const InputDecoration(labelText: "Father's Name")),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: fatherPhoneCtrl, decoration: const InputDecoration(labelText: "Father's Phone")),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: motherCtrl, decoration: const InputDecoration(labelText: "Mother's Name")),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(controller: emergencyPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Residential Address')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fee Discount %', suffixText: '%'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(controller: prevSchoolCtrl, decoration: const InputDecoration(labelText: 'Previous School')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await SupabaseService.updateStudent(
                  id: student.id,
                  fullName: nameCtrl.text.trim(),
                  rollNo: rollCtrl.text.trim(),
                  classId: selectedClassId,
                  status: status,
                  gender: gender,
                  bloodGroup: bloodGroup,
                  religion: religion,
                  category: category,
                  dob: dob != null ? DateFormat('yyyy-MM-dd').format(dob) : null,
                  address: addressCtrl.text.trim(),
                  emergencyPhone: emergencyPhoneCtrl.text.trim(),
                  fatherName: fatherCtrl.text.trim(),
                  fatherPhone: fatherPhoneCtrl.text.trim(),
                  motherName: motherCtrl.text.trim(),
                  motherPhone: motherPhoneCtrl.text.trim(),
                  feeDiscountPercent: double.tryParse(discountCtrl.text) ?? 0.0,
                  previousSchool: prevSchoolCtrl.text.trim(),
                );
                _showFeedback(res['message'] ?? (res['success'] == true ? 'Student updated successfully!' : 'Failed to update student'), isSuccess: res['success'] == true);
                if (res['success'] == true) {
                  _loadAllData();
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentProfileModal(StudentModel student) {
    final studentInvoices = _invoices.where((inv) => inv.studentId == student.id).toList();
    final studentMarks = _weightedMarks.where((m) => m.studentId == student.id).toList();
    final totalFeeDues = studentInvoices.fold<double>(0.0, (sum, inv) => sum + inv.remainingBalance);

    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 4,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 800,
            height: 560,
            child: Column(
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          student.fullName.isNotEmpty ? student.fullName.substring(0, 1).toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Adm: ${student.admissionNo} • Roll: ${student.rollNo} • Class: ${student.className ?? 'Unassigned'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: student.status == 'active' ? AppTheme.success : AppTheme.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(student.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                        icon: const Icon(Icons.badge, size: 16),
                        label: const Text('ID Card'),
                        onPressed: () => _printSingleStudentIdCard(student),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                        icon: const Icon(Icons.event_seat, size: 16),
                        label: const Text('Admit Card'),
                        onPressed: () => _printSingleStudentAdmitCard(student),
                      ),
                    ],
                  ),
                ),
                // Tabs
                const TabBar(
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  tabs: [
                    Tab(icon: Icon(Icons.person, size: 18), text: 'Demographics'),
                    Tab(icon: Icon(Icons.family_restroom, size: 18), text: 'Parents / Guardian'),
                    Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Fee Ledger & Dues'),
                    Tab(icon: Icon(Icons.grade, size: 18), text: 'Exams & Marks'),
                  ],
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Demographics
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: ListView(
                          children: [
                            _buildInfoTile('Gender', student.gender ?? 'Not Specified'),
                            _buildInfoTile('Date of Birth', student.dob ?? 'Not Recorded'),
                            _buildInfoTile('Blood Group', student.bloodGroup ?? 'Not Recorded'),
                            _buildInfoTile('Category / Caste', student.category ?? 'General'),
                            _buildInfoTile('Religion', student.religion ?? 'Not Specified'),
                            _buildInfoTile('Admission Date', student.admissionDate ?? 'Registered'),
                            _buildInfoTile('Previous School', student.previousSchool ?? 'None'),
                            _buildInfoTile('Residential Address', student.address ?? 'Not Recorded'),
                          ],
                        ),
                      ),
                      // Tab 2: Parents
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: ListView(
                          children: [
                            _buildInfoTile("Father's Name", student.fatherName ?? student.parentName ?? 'Not Specified'),
                            _buildInfoTile("Father's Phone", student.fatherPhone ?? student.parentPhone ?? 'No Contact Phone'),
                            _buildInfoTile("Mother's Name", student.motherName ?? 'Not Specified'),
                            _buildInfoTile("Mother's Phone", student.motherPhone ?? 'No Contact Phone'),
                            _buildInfoTile('Emergency Contact Phone', student.emergencyPhone ?? 'No Emergency Phone'),
                          ],
                        ),
                      ),
                      // Tab 3: Fee Ledger
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Fee Discount / Concession:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    Text('${student.feeDiscountPercent.toStringAsFixed(0)}% Tuition Concession', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Outstanding Balance:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    Text('${_activeSchool.currencySymbol}${totalFeeDues.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: totalFeeDues > 0 ? AppTheme.danger : AppTheme.success)),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showCollectCashFeeDialog(student);
                                  },
                                  icon: const Icon(Icons.payments, size: 16),
                                  label: const Text('Collect Cash Fee'),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Expanded(
                              child: studentInvoices.isEmpty
                                  ? const Center(child: Text('No fee invoices issued for this student yet.'))
                                  : ListView.builder(
                                      itemCount: studentInvoices.length,
                                      itemBuilder: (context, i) {
                                        final inv = studentInvoices[i];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            title: Text('${inv.invoiceNo} (${inv.month})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Text('Due: ${inv.dueDate} • Paid: ${_activeSchool.currencySymbol}${inv.paidAmount} / ${_activeSchool.currencySymbol}${inv.amount}'),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: inv.status == 'Paid' ? AppTheme.successLight : AppTheme.dangerLight,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(inv.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inv.status == 'Paid' ? AppTheme.success : AppTheme.danger)),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      // Tab 4: Exams & Marks
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: studentMarks.isEmpty
                            ? const Center(child: Text('No exam marks recorded yet for this student.'))
                            : ListView.builder(
                                itemCount: studentMarks.length,
                                itemBuilder: (context, i) {
                                  final m = studentMarks[i];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(m.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Score: ${m.totalWeightedMarks.toStringAsFixed(1)}% • Grade: ${m.grade}'),
                                      trailing: Text('Grade: ${m.grade}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close Profile')),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditStudentDialog(student);
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showCollectCashFeeDialog([StudentModel? preselectedStudent]) {
    if (_students.isEmpty) {
      _showFeedback('No students registered in the system to collect fees from.', isSuccess: false);
      return;
    }
    StudentModel currentStudent = preselectedStudent ?? _students.first;

    final classModel = _classes.firstWhere(
      (c) => c.id == currentStudent.classId,
      orElse: () => _classes.isNotEmpty ? _classes.first : ClassModel(id: '', schoolId: '', name: 'Class', section: 'A', tuitionFee: 1200.0, admissionFee: 0.0),
    );

    double defaultFee = classModel.tuitionFee;
    if (currentStudent.feeDiscountPercent > 0) {
      defaultFee = defaultFee * (1 - (currentStudent.feeDiscountPercent / 100.0));
    }

    final amountCtrl = TextEditingController(text: defaultFee.toStringAsFixed(2));
    final remarksCtrl = TextEditingController(text: 'Counter Tuition Fee Deposit');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.point_of_sale, color: AppTheme.success, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Cash Fee Counter (Instant Receipt)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: currentStudent.id,
                  decoration: const InputDecoration(labelText: 'Select Student *'),
                  items: _students.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.fullName} (${s.admissionNo} - ${s.className ?? ''})'))).toList(),
                  onChanged: (val) {
                    final sel = _students.firstWhere((s) => s.id == val);
                    setDState(() {
                      currentStudent = sel;
                      final cm = _classes.firstWhere(
                        (c) => c.id == sel.classId,
                        orElse: () => _classes.first,
                      );
                      double f = cm.tuitionFee;
                      if (sel.feeDiscountPercent > 0) {
                        f = f * (1 - (sel.feeDiscountPercent / 100.0));
                      }
                      amountCtrl.text = f.toStringAsFixed(2);
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Class Tuition: ${_activeSchool.currencySymbol}${classModel.tuitionFee}', style: const TextStyle(fontSize: 12)),
                      Text('Concession: ${currentStudent.feeDiscountPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cash Amount Paid (${_activeSchool.currencySymbol}) *',
                    prefixText: _activeSchool.currencySymbol,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks / Payment Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt <= 0) {
                  _showFeedback('Please enter a valid amount greater than 0.', isSuccess: false);
                  return;
                }
                Navigator.pop(ctx);
                final res = await SupabaseService.recordCashFee(
                  schoolId: _activeSchool.id,
                  studentId: currentStudent.id,
                  amount: amt,
                  remarks: remarksCtrl.text.trim(),
                );

                _showFeedback(res['message'] ?? 'Fee collected successfully!', isSuccess: res['success'] == true);
                if (res['success'] == true) {
                  _loadAllData();
                  // Instant Receipt Print
                  final dummyFee = FeeCollectionModel(
                    id: res['id'] ?? 'fee_${DateTime.now().millisecondsSinceEpoch}',
                    schoolId: _activeSchool.id,
                    studentId: currentStudent.id,
                    studentName: currentStudent.fullName,
                    studentRoll: currentStudent.rollNo,
                    studentClass: currentStudent.className ?? '',
                    receiptNo: res['receiptNo'] ?? 'REC-${DateTime.now().year}-0001',
                    amountPaid: amt,
                    paymentMode: 'cash',
                    paymentDate: DateTime.now(),
                    remarks: remarksCtrl.text.trim(),
                  );
                  Printing.layoutPdf(
                    onLayout: (fmt) => PdfPrintService.generateFeeReceiptA4(
                      school: _activeSchool,
                      fee: dummyFee,
                      receiptsPerPage: _receiptsPerPage,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Collect Cash & Print Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkPromotionDialog() {
    if (_classes.length < 2) {
      _showFeedback('At least 2 classes are required to promote students between sessions.', isSuccess: false);
      return;
    }

    String sourceClassId = _classes.first.id;
    String targetClassId = _classes.length > 1 ? _classes[1].id : _classes.first.id;
    final Set<String> selectedStudentIds = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final eligibleStudents = _students.where((s) => s.classId == sourceClassId).toList();
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.upgrade, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('eSkooly Bulk Student Promotion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select source class and destination target class to promote students to the next session:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: sourceClassId,
                          decoration: const InputDecoration(labelText: 'From Current Class'),
                          items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.section})'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDState(() {
                                sourceClassId = val;
                                selectedStudentIds.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: targetClassId,
                          decoration: const InputDecoration(labelText: 'Promote To Class'),
                          items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.section})'))).toList(),
                          onChanged: (val) {
                            if (val != null) setDState(() => targetClassId = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Eligible Students (${eligibleStudents.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      TextButton.icon(
                        icon: Icon(selectedStudentIds.length == eligibleStudents.length ? Icons.deselect : Icons.select_all, size: 16),
                        label: Text(selectedStudentIds.length == eligibleStudents.length ? 'Deselect All' : 'Select All'),
                        onPressed: () {
                          setDState(() {
                            if (selectedStudentIds.length == eligibleStudents.length) {
                              selectedStudentIds.clear();
                            } else {
                              selectedStudentIds.addAll(eligibleStudents.map((s) => s.id));
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 10),
                  Expanded(
                    child: eligibleStudents.isEmpty
                        ? const Center(child: Text('No students currently assigned to this source class.'))
                        : ListView.builder(
                            itemCount: eligibleStudents.length,
                            itemBuilder: (context, i) {
                              final s = eligibleStudents[i];
                              final isSelected = selectedStudentIds.contains(s.id);
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Roll: ${s.rollNo} • Adm: ${s.admissionNo}'),
                                onChanged: (checked) {
                                  setDState(() {
                                    if (checked == true) {
                                      selectedStudentIds.add(s.id);
                                    } else {
                                      selectedStudentIds.remove(s.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: selectedStudentIds.isEmpty || sourceClassId == targetClassId
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final res = await SupabaseService.promoteStudents(
                          studentIds: selectedStudentIds.toList(),
                          targetClassId: targetClassId,
                        );
                        _showFeedback(res['message'] ?? 'Students promoted!', isSuccess: res['success'] == true);
                        if (res['success'] == true) {
                          _loadAllData();
                        }
                      },
                icon: const Icon(Icons.school, size: 18),
                label: Text('Promote ${selectedStudentIds.length} Students'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _printSingleStudentIdCard(StudentModel student) {
    Printing.layoutPdf(
      onLayout: (fmt) => PdfPrintService.generateIdCardsA4(
        school: _activeSchool,
        students: [student],
        cardsPerPage: 4,
      ),
    );
  }

  void _printSingleStudentAdmitCard(StudentModel student) {
    Printing.layoutPdf(
      onLayout: (fmt) => PdfPrintService.generateAdmitCardA4(
        school: _activeSchool,
        student: student,
        examName: 'Annual Examinations ${_activeSchool.academicYear}',
        roomNumber: 'Hall A',
        deskNumber: 'DESK-${student.rollNo}',
      ),
    );
  }

  // =====================================================================
  // 3. DIALOGS & ACTIONS FOR STAFF & FACULTY (eSkooly HR)
  // =====================================================================

  void _printSingleStaffIdCard(StaffModel staff) {
    Printing.layoutPdf(
      name: 'Staff_ID_${staff.employeeCode}',
      onLayout: (fmt) => PdfPrintService.generateStaffIdCardsA4(
        school: _activeSchool,
        staff: [staff],
        cardsPerPage: 4,
      ),
    );
  }

  void _printAllStaffIdCards() {
    if (_staff.isEmpty) {
      _showFeedback('No staff members registered to print ID cards.', isSuccess: false);
      return;
    }
    Printing.layoutPdf(
      name: 'All_Staff_ID_Cards',
      onLayout: (fmt) => PdfPrintService.generateStaffIdCardsA4(
        school: _activeSchool,
        staff: _staff,
        cardsPerPage: _idCardsPerPage,
      ),
    );
  }

  void _printStaffJobLetter(StaffModel staff) {
    Printing.layoutPdf(
      name: 'Job_Letter_${staff.employeeCode}',
      onLayout: (fmt) => PdfPrintService.generateJobLetterA4(
        school: _activeSchool,
        staff: staff,
      ),
    );
  }

  /// eSkooly 2-Step "Add New Employee / Teacher" Dialog
  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'EMP-${DateTime.now().year}-${(_staff.length + 1).toString().padLeft(3, '0')}');
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final designationCtrl = TextEditingController(text: 'Faculty');
    final deptCtrl = TextEditingController(text: 'Academics');
    final salaryCtrl = TextEditingController(text: '35000.00');
    final educationCtrl = TextEditingController(text: 'M.Sc / B.Ed');
    final experienceCtrl = TextEditingController(text: '3 Years');
    final fatherHusbandCtrl = TextEditingController();
    final nationalIdCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final pictureCtrl = TextEditingController();

    String role = 'Teacher';
    String gender = 'Male';
    String religion = 'Islam';
    String bloodGroup = 'O+';
    DateTime joiningDate = DateTime.now();
    DateTime? dob = DateTime(1992, 1, 1);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.person_add_alt_1, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Add New Employee / Teacher (eSkooly HR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Required', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Optional', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: BASIC INFORMATION ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 9, backgroundColor: AppTheme.primary, child: Text('1', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'EMPLOYEE NAME *',
                            hintText: 'Name of Employee',
                            prefixIcon: Icon(Icons.person, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'MOBILE NO FOR SMS/WHATSAPP',
                            hintText: 'e.g. +44xxxxxxxxxx',
                            prefixIcon: Icon(Icons.phone_android, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'EMPLOYEE ROLE *'),
                          items: const [
                            DropdownMenuItem(value: 'Principal', child: Text('Principal')),
                            DropdownMenuItem(value: 'Vice Principal', child: Text('Vice Principal')),
                            DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                            DropdownMenuItem(value: 'Accountant', child: Text('Accountant')),
                            DropdownMenuItem(value: 'Librarian', child: Text('Librarian')),
                            DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'Coordinator', child: Text('Coordinator')),
                            DropdownMenuItem(value: 'Staff', child: Text('Support Staff')),
                          ],
                          onChanged: (val) => setDState(() => role = val ?? 'Teacher'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'EMPLOYEE CODE *', hintText: 'EMP-2026-001'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: joiningDate,
                              firstDate: DateTime(1980),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setDState(() => joiningDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'DATE OF JOINING *', suffixIcon: Icon(Icons.calendar_today, size: 16)),
                            child: Text(DateFormat('MM/dd/yyyy').format(joiningDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: salaryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'MONTHLY SALARY *',
                            prefixText: '${_activeSchool.currencySymbol} ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: designationCtrl,
                          decoration: const InputDecoration(labelText: 'DESIGNATION', hintText: 'e.g. Senior Faculty / Math Head'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: deptCtrl,
                          decoration: const InputDecoration(labelText: 'DEPARTMENT', hintText: 'e.g. Science / Academics / Admin'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: pictureCtrl,
                          decoration: const InputDecoration(
                            labelText: 'PICTURE URL (OPTIONAL)',
                            hintText: 'https://... or empty for initials',
                            prefixIcon: Icon(Icons.image, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- SECTION 2: OTHER INFORMATION ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.surfaceSubtle, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 9, backgroundColor: AppTheme.textSecondary, child: Text('2', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Text('Other Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: fatherHusbandCtrl,
                          decoration: const InputDecoration(labelText: 'FATHER / HUSBAND NAME', hintText: 'Father / Husband Name'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(labelText: 'GENDER'),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setDState(() => gender = val ?? 'Male'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: experienceCtrl,
                          decoration: const InputDecoration(labelText: 'EXPERIENCE', hintText: 'e.g. 5 Years'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nationalIdCtrl,
                          decoration: const InputDecoration(labelText: 'NATIONAL ID', hintText: 'CNIC / Aadhaar / SSN'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: religion,
                          decoration: const InputDecoration(labelText: 'RELIGION'),
                          items: const [
                            DropdownMenuItem(value: 'Islam', child: Text('Islam')),
                            DropdownMenuItem(value: 'Christianity', child: Text('Christianity')),
                            DropdownMenuItem(value: 'Hinduism', child: Text('Hinduism')),
                            DropdownMenuItem(value: 'Sikhism', child: Text('Sikhism')),
                            DropdownMenuItem(value: 'Buddhism', child: Text('Buddhism')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setDState(() => religion = val ?? 'Islam'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'EMAIL ADDRESS', hintText: 'employee@school.edu'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: educationCtrl,
                          decoration: const InputDecoration(labelText: 'EDUCATION', hintText: 'e.g. M.Sc Mathematics, B.Ed'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: bloodGroup,
                          decoration: const InputDecoration(labelText: 'BLOOD GROUP'),
                          items: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (val) => setDState(() => bloodGroup = val ?? 'O+'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: dob ?? DateTime(1992, 1, 1),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                            );
                            if (d != null) setDState(() => dob = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'DATE OF BIRTH', suffixIcon: Icon(Icons.cake, size: 16)),
                            child: Text(dob != null ? DateFormat('MM/dd/yyyy').format(dob!) : 'mm/dd/yyyy'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'HOME ADDRESS', hintText: 'Current residential address'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Submit / Save Employee'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  _showFeedback('Employee name is required.', isSuccess: false);
                  return;
                }
                if (codeCtrl.text.trim().isEmpty) {
                  _showFeedback('Employee code is required.', isSuccess: false);
                  return;
                }
                Navigator.pop(ctx);
                final sal = double.tryParse(salaryCtrl.text.trim()) ?? 35000.0;
                final res = await SupabaseService.addStaff(
                  schoolId: _activeSchool.id,
                  employeeCode: codeCtrl.text.trim(),
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  role: role,
                  designation: designationCtrl.text.trim().isEmpty ? 'Faculty' : designationCtrl.text.trim(),
                  department: deptCtrl.text.trim().isEmpty ? 'Academics' : deptCtrl.text.trim(),
                  salary: sal,
                  qualification: educationCtrl.text.trim().isEmpty ? null : educationCtrl.text.trim(),
                  joiningDate: DateFormat('yyyy-MM-dd').format(joiningDate),
                  fatherOrHusbandName: fatherHusbandCtrl.text.trim().isEmpty ? null : fatherHusbandCtrl.text.trim(),
                  gender: gender,
                  experience: experienceCtrl.text.trim().isEmpty ? null : experienceCtrl.text.trim(),
                  nationalId: nationalIdCtrl.text.trim().isEmpty ? null : nationalIdCtrl.text.trim(),
                  religion: religion,
                  bloodGroup: bloodGroup,
                  dob: dob != null ? DateFormat('yyyy-MM-dd').format(dob!) : null,
                  homeAddress: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  pictureUrl: pictureCtrl.text.trim().isEmpty ? null : pictureCtrl.text.trim(),
                );
                _showFeedback(res['message'] ?? 'Employee added successfully', isSuccess: res['success'] == true);
                _loadAllData();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// eSkooly Edit Employee Dialog
  void _showEditStaffDialog(StaffModel staff) {
    final nameCtrl = TextEditingController(text: staff.fullName);
    final phoneCtrl = TextEditingController(text: staff.phone ?? '');
    final emailCtrl = TextEditingController(text: staff.email ?? '');
    final designationCtrl = TextEditingController(text: staff.designation);
    final deptCtrl = TextEditingController(text: staff.department);
    final salaryCtrl = TextEditingController(text: staff.salary.toStringAsFixed(2));
    final educationCtrl = TextEditingController(text: staff.qualification ?? '');
    final experienceCtrl = TextEditingController(text: staff.experience ?? '');
    final fatherHusbandCtrl = TextEditingController(text: staff.fatherOrHusbandName ?? '');
    final nationalIdCtrl = TextEditingController(text: staff.nationalId ?? '');
    final addressCtrl = TextEditingController(text: staff.homeAddress ?? '');
    final pictureCtrl = TextEditingController(text: staff.pictureUrl ?? '');

    String role = staff.role;
    String gender = staff.gender ?? 'Male';
    String religion = staff.religion ?? 'Islam';
    String bloodGroup = staff.bloodGroup ?? 'O+';
    DateTime joiningDate = staff.joiningDate ?? DateTime.now();
    DateTime? dob = staff.dob;
    bool isActive = staff.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Edit Employee: ${staff.fullName} (${staff.employeeCode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Row(
                children: [
                  const Text('Active Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Switch(
                    value: isActive,
                    onChanged: (val) => setDState(() => isActive = val),
                    activeColor: AppTheme.success,
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: BASIC INFORMATION ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 9, backgroundColor: AppTheme.primary, child: Text('1', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'EMPLOYEE NAME *', prefixIcon: Icon(Icons.person, size: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'MOBILE NO FOR SMS/WHATSAPP', prefixIcon: Icon(Icons.phone_android, size: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'EMPLOYEE ROLE *'),
                          items: const [
                            DropdownMenuItem(value: 'Principal', child: Text('Principal')),
                            DropdownMenuItem(value: 'Vice Principal', child: Text('Vice Principal')),
                            DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                            DropdownMenuItem(value: 'Accountant', child: Text('Accountant')),
                            DropdownMenuItem(value: 'Librarian', child: Text('Librarian')),
                            DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'Coordinator', child: Text('Coordinator')),
                            DropdownMenuItem(value: 'Staff', child: Text('Support Staff')),
                          ],
                          onChanged: (val) => setDState(() => role = val ?? 'Teacher'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: joiningDate,
                              firstDate: DateTime(1980),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setDState(() => joiningDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'DATE OF JOINING', suffixIcon: Icon(Icons.calendar_today, size: 16)),
                            child: Text(DateFormat('MM/dd/yyyy').format(joiningDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: salaryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'MONTHLY SALARY *',
                            prefixText: '${_activeSchool.currencySymbol} ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: pictureCtrl,
                          decoration: const InputDecoration(labelText: 'PICTURE URL', prefixIcon: Icon(Icons.image, size: 18)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: designationCtrl,
                          decoration: const InputDecoration(labelText: 'DESIGNATION'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: deptCtrl,
                          decoration: const InputDecoration(labelText: 'DEPARTMENT'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- SECTION 2: OTHER INFORMATION ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.surfaceSubtle, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 9, backgroundColor: AppTheme.textSecondary, child: Text('2', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Text('Other Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: fatherHusbandCtrl,
                          decoration: const InputDecoration(labelText: 'FATHER / HUSBAND NAME'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: ['Male', 'Female', 'Other'].contains(gender) ? gender : 'Male',
                          decoration: const InputDecoration(labelText: 'GENDER'),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setDState(() => gender = val ?? 'Male'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: experienceCtrl,
                          decoration: const InputDecoration(labelText: 'EXPERIENCE'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nationalIdCtrl,
                          decoration: const InputDecoration(labelText: 'NATIONAL ID'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: ['Islam', 'Christianity', 'Hinduism', 'Sikhism', 'Buddhism', 'Other'].contains(religion) ? religion : 'Islam',
                          decoration: const InputDecoration(labelText: 'RELIGION'),
                          items: const [
                            DropdownMenuItem(value: 'Islam', child: Text('Islam')),
                            DropdownMenuItem(value: 'Christianity', child: Text('Christianity')),
                            DropdownMenuItem(value: 'Hinduism', child: Text('Hinduism')),
                            DropdownMenuItem(value: 'Sikhism', child: Text('Sikhism')),
                            DropdownMenuItem(value: 'Buddhism', child: Text('Buddhism')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) => setDState(() => religion = val ?? 'Islam'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'EMAIL ADDRESS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: educationCtrl,
                          decoration: const InputDecoration(labelText: 'EDUCATION'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].contains(bloodGroup) ? bloodGroup : 'O+',
                          decoration: const InputDecoration(labelText: 'BLOOD GROUP'),
                          items: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                              .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                              .toList(),
                          onChanged: (val) => setDState(() => bloodGroup = val ?? 'O+'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: dob ?? DateTime(1992, 1, 1),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                            );
                            if (d != null) setDState(() => dob = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'DATE OF BIRTH', suffixIcon: Icon(Icons.cake, size: 16)),
                            child: Text(dob != null ? DateFormat('MM/dd/yyyy').format(dob!) : 'mm/dd/yyyy'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'HOME ADDRESS'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Update Employee'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final sal = double.tryParse(salaryCtrl.text.trim()) ?? staff.salary;
                final res = await SupabaseService.updateStaff(
                  id: staff.id,
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  role: role,
                  designation: designationCtrl.text.trim(),
                  department: deptCtrl.text.trim(),
                  salary: sal,
                  qualification: educationCtrl.text.trim().isEmpty ? null : educationCtrl.text.trim(),
                  joiningDate: DateFormat('yyyy-MM-dd').format(joiningDate),
                  fatherOrHusbandName: fatherHusbandCtrl.text.trim().isEmpty ? null : fatherHusbandCtrl.text.trim(),
                  gender: gender,
                  experience: experienceCtrl.text.trim().isEmpty ? null : experienceCtrl.text.trim(),
                  nationalId: nationalIdCtrl.text.trim().isEmpty ? null : nationalIdCtrl.text.trim(),
                  religion: religion,
                  bloodGroup: bloodGroup,
                  dob: dob != null ? DateFormat('yyyy-MM-dd').format(dob!) : null,
                  homeAddress: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  pictureUrl: pictureCtrl.text.trim().isEmpty ? null : pictureCtrl.text.trim(),
                  isActive: isActive,
                );
                _showFeedback(res['message'] ?? 'Employee updated successfully', isSuccess: res['success'] == true);
                _loadAllData();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 360° Staff Profile Modal with direct ID Card & Job Letter print hooks
  void _showStaffProfileModal(StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white24,
                      child: Text(
                        staff.fullName.isNotEmpty ? staff.fullName.substring(0, 1).toUpperCase() : 'E',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(staff.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                                child: Text(staff.role, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text('Code: ${staff.employeeCode}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: staff.isActive ? AppTheme.success.withOpacity(0.3) : AppTheme.danger.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  staff.isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(color: staff.isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${staff.designation} • ${staff.department}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Actions Toolbar
              Container(
                color: AppTheme.surfaceSubtle,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: const Text('Print Staff ID Card'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _printSingleStaffIdCard(staff);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Print Job Letter'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _printStaffJobLetter(staff);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditStaffDialog(staff);
                      },
                    ),
                  ],
                ),
              ),

              // Two Column Info Grid
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: Employment Details
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.work_outline, size: 16, color: AppTheme.primary),
                                SizedBox(width: 6),
                                Text('Employment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                              ],
                            ),
                            const Divider(height: 16),
                            _buildInfoTile('Role', staff.role),
                            _buildInfoTile('Designation', staff.designation),
                            _buildInfoTile('Department', staff.department),
                            _buildInfoTile('Monthly Salary', '${_activeSchool.currencySymbol}${staff.salary.toStringAsFixed(2)}'),
                            _buildInfoTile('Joining Date', staff.joiningDate != null ? DateFormat('dd MMM yyyy').format(staff.joiningDate!) : 'N/A'),
                            _buildInfoTile('Education', staff.qualification ?? 'N/A'),
                            _buildInfoTile('Experience', staff.experience ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Column 2: Personal & Contact
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_pin_outlined, size: 16, color: AppTheme.primary),
                                SizedBox(width: 6),
                                Text('Personal & Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                              ],
                            ),
                            const Divider(height: 16),
                            _buildInfoTile('Father/Husband', staff.fatherOrHusbandName ?? 'N/A'),
                            _buildInfoTile('Gender', staff.gender ?? 'N/A'),
                            _buildInfoTile('National ID', staff.nationalId ?? 'N/A'),
                            _buildInfoTile('Religion', staff.religion ?? 'N/A'),
                            _buildInfoTile('Blood Group', staff.bloodGroup ?? 'N/A'),
                            _buildInfoTile('Date of Birth', staff.dob != null ? DateFormat('dd MMM yyyy').format(staff.dob!) : 'N/A'),
                            _buildInfoTile('Phone/WhatsApp', staff.phone ?? 'N/A'),
                            _buildInfoTile('Email Address', staff.email ?? 'N/A'),
                            _buildInfoTile('Address', staff.homeAddress ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // =====================================================================
  // 4. DIALOGS FOR INVOICING & FINANCIAL ACCOUNTING
  // =====================================================================

  void _showGenerateInvoicesDialog() {
    final now = DateTime.now();
    final monthCtrl = TextEditingController(text: DateFormat('MMMM yyyy').format(now));
    DateTime dueDate = DateTime(now.year, now.month, _activeSchool.feeDueDay);
    if (dueDate.isBefore(now)) {
      dueDate = dueDate.add(const Duration(days: 30));
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Generate Monthly Fee Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This automated eSkooly billing engine creates invoice records for all active students using their class tuition fee asset pricing.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(controller: monthCtrl, decoration: const InputDecoration(labelText: 'Billing Cycle Month')),
            const SizedBox(height: 12),
            Text('Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate)} (Day ${_activeSchool.feeDueDay})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await SupabaseService.generateMonthlyInvoices(
                schoolId: _activeSchool.id,
                month: monthCtrl.text.trim(),
                dueDate: dueDate,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res['message']), backgroundColor: res['success'] ? AppTheme.success : AppTheme.danger),
              );
              _loadAllData();
            },
            icon: const Icon(Icons.flash_on, size: 18),
            label: const Text('Run Billing Engine'),
          ),
        ],
      ),
    );
  }

  void _showPayInvoiceDialog(FeeInvoiceModel invoice) {
    final payAmountCtrl = TextEditingController(text: invoice.remainingBalance.toStringAsFixed(2));
    final discountCtrl = TextEditingController(text: '0.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Settle Invoice: ${invoice.invoiceNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${invoice.studentName} (${invoice.className})', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Total Fee: ${_activeSchool.currencySymbol}${invoice.amount} • Due: ${_activeSchool.currencySymbol}${invoice.remainingBalance}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const Divider(height: 24),
            TextField(
              controller: payAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Cash Amount Paid (${_activeSchool.currencySymbol})'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Waiver / Discount (${_activeSchool.currencySymbol})'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final amt = double.tryParse(payAmountCtrl.text) ?? 0.0;
              final disc = double.tryParse(discountCtrl.text) ?? 0.0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.payInvoice(
                invoiceId: invoice.id,
                schoolId: _activeSchool.id,
                studentId: invoice.studentId,
                amountToPay: amt,
                discount: disc,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res['message']), backgroundColor: res['success'] ? AppTheme.success : AppTheme.danger),
              );
              _loadAllData();
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Collect Cash & Print Receipt'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final catCtrl = TextEditingController(text: 'Utilities');
    final voucherCtrl = TextEditingController(text: 'VOUCH-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final amountCtrl = TextEditingController();
    final paidToCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Log School Operating Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: catCtrl.text,
                decoration: const InputDecoration(labelText: 'Expense Category *'),
                items: const ['Salaries', 'Utilities', 'Maintenance', 'Rent', 'Supplies', 'Printing', 'Other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setDState(() => catCtrl.text = val ?? 'Utilities'),
              ),
              const SizedBox(height: 10),
              TextField(controller: voucherCtrl, decoration: const InputDecoration(labelText: 'Voucher Number')),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount Paid (${_activeSchool.currencySymbol}) *')),
              const SizedBox(height: 10),
              TextField(controller: paidToCtrl, decoration: const InputDecoration(labelText: 'Paid To (Vendor / Person) *')),
              const SizedBox(height: 10),
              TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks / Purpose')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt <= 0 || paidToCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                await SupabaseService.addExpense(
                  schoolId: _activeSchool.id,
                  category: catCtrl.text,
                  voucherNo: voucherCtrl.text.trim(),
                  amount: amt,
                  paidTo: paidToCtrl.text.trim(),
                  paymentDate: DateTime.now(),
                  remarks: remarksCtrl.text.trim(),
                );
                _loadAllData();
              },
              child: const Text('Save Expense Voucher'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // 5. DIALOGS FOR EXAMINATIONS & WEIGHTED MARKS
  // =====================================================================

  void _showAddWeightedMarkDialog() {
    StudentModel? selectedStudent = _students.isNotEmpty ? _students.first : null;
    final subjectCtrl = TextEditingController(text: 'Mathematics');
    final assignCtrl = TextEditingController(text: '85.0');
    final midCtrl = TextEditingController(text: '80.0');
    final finalCtrl = TextEditingController(text: '90.0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final a = double.tryParse(assignCtrl.text) ?? 0.0;
          final m = double.tryParse(midCtrl.text) ?? 0.0;
          final f = double.tryParse(finalCtrl.text) ?? 0.0;
          final computed = (a * 0.20) + (m * 0.30) + (f * 0.50);

          return AlertDialog(
            title: const Text('Enter Weighted Exam Marks (eSkooly Engine)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Formula: Final = (Assignments × 20%) + (MidTerms × 30%) + (FinalExam × 50%)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<StudentModel>(
                    initialValue: selectedStudent,
                    decoration: const InputDecoration(labelText: 'Select Student'),
                    items: _students.map((s) => DropdownMenuItem(value: s, child: Text('${s.fullName} (Roll: ${s.rollNo})'))).toList(),
                    onChanged: (val) => setDState(() => selectedStudent = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject Name')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: assignCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Assignments (20%)'),
                          onChanged: (_) => setDState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: midCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'MidTerms (30%)'),
                          onChanged: (_) => setDState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: finalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Final Exam (50%)'),
                          onChanged: (_) => setDState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Computed Total Weighted Mark:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text('${computed.toStringAsFixed(2)} / 100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedStudent == null || subjectCtrl.text.isEmpty) return;
                  Navigator.pop(ctx);
                  await SupabaseService.recordWeightedMark(
                    schoolId: _activeSchool.id,
                    studentId: selectedStudent!.id,
                    subjectName: subjectCtrl.text.trim(),
                    assignmentMarks: a,
                    midtermMarks: m,
                    finalExamMarks: f,
                  );
                  _loadAllData();
                },
                child: const Text('Save Marks & Calculate Grade'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =====================================================================
  // 6. BIOMETRIC HARDWARE HOOK SIMULATOR
  // =====================================================================

  void _showBiometricSimulatorDialog() {
    final admCtrl = TextEditingController(text: _students.isNotEmpty ? _students.first.admissionNo : '');
    final deviceCtrl = TextEditingController(text: 'BIO-GATE-01');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.fingerprint, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Biometric Hardware Punch Receiver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simulate automated physical device webhook payload (POST /api/v1/attendance/biometric).', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            TextField(controller: deviceCtrl, decoration: const InputDecoration(labelText: 'Device Hardware Identifier')),
            const SizedBox(height: 10),
            TextField(controller: admCtrl, decoration: const InputDecoration(labelText: 'Student Admission Number punched')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (admCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.processBiometricPunch(
                schoolId: _activeSchool.id,
                deviceId: deviceCtrl.text.trim(),
                studentAdmissionNo: admCtrl.text.trim(),
                timestamp: DateTime.now(),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['message']),
                  backgroundColor: res['success'] ? AppTheme.success : AppTheme.danger,
                ),
              );
              _loadAllData();
            },
            icon: const Icon(Icons.fingerprint, size: 18),
            label: const Text('Simulate Hardware Punch'),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // MAIN SCAFFOLD & UI BUILD
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_activeSchool.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  '${_activeSchool.tagline} • Code: ${_activeSchool.code} • Currency: ${_activeSchool.currencySymbol}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Student Quota Telemetry Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Quota: ${_students.length} / ${_activeSchool.maxStudents} Students',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Offline Status & Sync Trigger
          InkWell(
            onTap: _handleManualSync,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _pendingOfflineCount > 0 ? Colors.amber.shade100 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _pendingOfflineCount > 0 ? Colors.amber.shade800 : Colors.green.shade600,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pendingOfflineCount > 0 ? Icons.sync_problem : Icons.cloud_done,
                    size: 15,
                    color: _pendingOfflineCount > 0 ? Colors.amber.shade900 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _pendingOfflineCount > 0 ? 'Sync ($_pendingOfflineCount)' : 'Offline Ready',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _pendingOfflineCount > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadAllData,
            tooltip: 'Refresh All School Records',
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Navigation Sidebar with 9 complete sections
                NavigationRail(
                  selectedIndex: _selectedTabIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Overview')),
                    NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: Text('Classes')),
                    NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Students')),
                    NavigationRailDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: Text('Staff/HR')),
                    NavigationRailDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg), label: Text('Attendance')),
                    NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Finances')),
                    NavigationRailDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: Text('Exams')),
                    NavigationRailDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: Text('Print Hub')),
                    NavigationRailDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: Text('Settings')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // Main Workspace Area
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildOverviewTab(),
                      _buildClassesTab(),
                      _buildStudentsTab(),
                      _buildStaffTab(),
                      _buildAttendanceTab(),
                      _buildFinancesTab(),
                      _buildExamsTab(),
                      _buildPrintHubTab(),
                      _buildSettingsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // =====================================================================
  // TAB 0: OVERVIEW & LIVE COMMAND CENTER
  // =====================================================================

  Widget _buildOverviewTab() {
    final totalFeeCollected = _fees.fold<double>(0.0, (sum, f) => sum + f.amountPaid);
    final totalExpenses = _expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final netCashInHand = totalFeeCollected - totalExpenses;
    final overdueCount = _invoices.where((i) => i.status == 'Unpaid' || i.status == 'Overdue').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome to ${_activeSchool.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Live ERP Command Center & Real-Time Institutional Telemetry', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showEnrollStudentDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('New Admission'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                    onPressed: _showGenerateInvoicesDialog,
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Generate Invoices'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4 Live KPIs from eSkooly PRD
          Row(
            children: [
              _buildMetricCard(
                'Active Enrolled Students',
                '${_students.length} / ${_activeSchool.maxStudents}',
                Icons.people,
                AppTheme.primary,
                subtitle: '${((_students.length / _activeSchool.maxStudents) * 100).toStringAsFixed(1)}% Quota Capacity',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Active Staff & Faculty',
                '${_staff.length} Members',
                Icons.badge,
                Colors.teal,
                subtitle: '${_staff.where((s) => s.role == 'Teacher').length} Teaching Staff',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Gross Cash Revenue',
                '${_activeSchool.currencySymbol}${totalFeeCollected.toStringAsFixed(2)}',
                Icons.payments,
                AppTheme.success,
                subtitle: '${_fees.length} Total Receipts',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Overdue / Unpaid Invoices',
                '$overdueCount Invoices',
                Icons.warning_amber_rounded,
                AppTheme.danger,
                subtitle: 'Requires follow-up',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cash Flow Balance Bar
          Card(
            color: AppTheme.surfaceSubtle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      const Text('Double-Entry Cash-in-Drawer Ledger:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: [
                      Text('Gross Receipts: ${_activeSchool.currencySymbol}${totalFeeCollected.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text('  —  ', style: TextStyle(color: AppTheme.textSecondary)),
                      Text('Expenses: ${_activeSchool.currencySymbol}${totalExpenses.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text('  =  ', style: TextStyle(color: AppTheme.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: netCashInHand >= 0 ? AppTheme.successLight : AppTheme.dangerLight, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'Net Cash in Hand: ${_activeSchool.currencySymbol}${netCashInHand.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: netCashInHand >= 0 ? AppTheme.success : AppTheme.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Shortcuts & Recent Transactions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Counter Cash Receipts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _fees.isEmpty
                            ? const Padding(padding: EdgeInsets.all(20), child: Text('No fee payments recorded yet.'))
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _fees.take(5).length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final f = _fees[i];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.successLight,
                                      child: const Icon(Icons.attach_money, color: AppTheme.success, size: 18),
                                    ),
                                    title: Text(f.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    subtitle: Text('${f.receiptNo} • ${DateFormat('yyyy-MM-dd').format(f.paymentDate)}', style: const TextStyle(fontSize: 11)),
                                    trailing: Text(
                                      '${_activeSchool.currencySymbol}${f.amountPaid.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 14),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick ERP Action Hub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildActionTile(Icons.person_add, 'Admit Student', 'Auto-assign roll and admission numbers', _showEnrollStudentDialog),
                        _buildActionTile(Icons.calendar_month, 'Academic & Operations Hub', 'Timetables, Lesson Plans, Logs, PTM, Notices, Assets', () {
                          showDialog(
                            context: context,
                            builder: (_) => AcademicHubDialog(
                              school: _activeSchool,
                              classes: _classes,
                              staff: _staff,
                              students: _students,
                            ),
                          );
                        }),
                        _buildActionTile(Icons.receipt_long, 'Generate Invoices', 'Monthly automated fee billing', _showGenerateInvoicesDialog),
                        _buildActionTile(Icons.money_off, 'Log School Expense', 'Salaries, utilities, maintenance', _showAddExpenseDialog),
                        _buildActionTile(Icons.fingerprint, 'Biometric Punch', 'Hardware device simulator', _showBiometricSimulatorDialog),
                        _buildActionTile(Icons.print, 'Print Hub', 'Bulk ID cards, receipts, reports', () => setState(() => _selectedTabIndex = 7)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB 1: ACADEMIC STRUCTURE (Classes & Sections)
  // ================================================  // =====================================================================
  // TAB 1: ACADEMIC SETUP & CLASSES (eSkooly Class Management)
  // =====================================================================

  Widget _buildClassesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Academic Classes & Structure', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Define classes, assign sections, set room numbers, capacity limits, and baseline fees', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddClassDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Class'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _classes.isEmpty
                ? const Center(child: Text('No classes created yet. Click "Add Class" to start.'))
                : ListView.builder(
                    itemCount: _classes.length,
                    itemBuilder: (context, idx) {
                      final c = _classes[idx];
                      final classStudents = _students.where((s) => s.classId == c.id || (s.className != null && s.className!.contains(c.name))).toList();
                      final classSections = _sections.where((sec) => sec.classId == c.id).toList();
                      final int totalCapacity = classSections.fold<int>(0, (sum, sec) => sum + sec.capacity);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.class_, color: AppTheme.primary, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${c.name} (Default Section ${c.section})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text('Room: ${c.roomNumber ?? 'Unassigned'} • Enrolled: ${classStudents.length} Students ${totalCapacity > 0 ? '• Total Cap: $totalCapacity' : ''}',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(12)),
                                        child: Text(
                                          'Tuition: ${_activeSchool.currencySymbol}${c.tuitionFee.toStringAsFixed(2)} / mo',
                                          style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (c.admissionFee > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                          child: Text(
                                            'Adm Fee: ${_activeSchool.currencySymbol}${c.admissionFee.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Class & Fees',
                                        onPressed: () => _showEditClassDialog(c),
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('Add Section', style: TextStyle(fontSize: 11)),
                                        onPressed: () => _showAddSectionDialog(c.id),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                        tooltip: 'Delete Class',
                                        onPressed: () => _confirmDelete(
                                          title: 'Delete Class: ${c.name}',
                                          message: 'Are you sure you want to delete class ${c.name}? This will unassign all students in this class.',
                                          onConfirm: () => SupabaseService.deleteClass(c.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (classSections.isNotEmpty) ...[
                                const Divider(height: 20),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: classSections.map((sec) {
                                    return Chip(
                                      avatar: const Icon(Icons.meeting_room, size: 14),
                                      label: Text('${sec.name} (${sec.roomNumber ?? 'Room'}, Cap: ${sec.capacity})'),
                                      deleteIcon: const Icon(Icons.close, size: 14),
                                      onDeleted: () => _confirmDelete(
                                        title: 'Delete Section: ${sec.name}',
                                        message: 'Are you sure you want to delete section ${sec.name} from ${c.name}?',
                                        onConfirm: () => SupabaseService.deleteSection(sec.id),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB 2: STUDENT INFORMATION SYSTEM (SIS & Admissions - eSkooly 360)
  // =====================================================================

  Widget _buildStudentsTab() {
    final filtered = _students.where((s) {
      if (_studentClassFilter != null && _studentClassFilter!.isNotEmpty) {
        if (s.classId != _studentClassFilter && s.className != _studentClassFilter) return false;
      }
      if (_studentSectionFilter != null && _studentSectionFilter!.isNotEmpty) {
        if (s.section != _studentSectionFilter && (s.className == null || !s.className!.contains(_studentSectionFilter!))) return false;
      }
      if (_studentStatusFilter != 'All' && s.status != _studentStatusFilter) {
        return false;
      }
      if (_studentGenderFilter != 'All' && s.gender != _studentGenderFilter) {
        return false;
      }
      if (_studentSearch.isNotEmpty) {
        final q = _studentSearch.toLowerCase();
        final matchName = s.fullName.toLowerCase().contains(q);
        final matchRoll = s.rollNo.toLowerCase().contains(q);
        final matchAdm = s.admissionNo.toLowerCase().contains(q);
        final matchPhone = (s.parentPhone ?? '').contains(q) || (s.fatherPhone ?? '').contains(q);
        return matchName || matchRoll || matchAdm || matchPhone;
      }
      return true;
    }).toList();

    final activeCount = _students.where((s) => s.status == 'active').length;
    final discountCount = _students.where((s) => s.feeDiscountPercent > 0).length;
    final maleCount = _students.where((s) => s.gender == 'Male').length;
    final femaleCount = _students.where((s) => s.gender == 'Female').length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Student Information System (eSkooly SIS)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('360° student records, profile cards, admit cards, fee counters, and class promotion', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showCollectCashFeeDialog,
                    icon: const Icon(Icons.point_of_sale, size: 16),
                    label: const Text('Cash Counter'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showBulkPromotionDialog,
                    icon: const Icon(Icons.upgrade, size: 16),
                    label: const Text('Bulk Promote'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showEnrollStudentDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Admit Student'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Metric Cards Row
          Row(
            children: [
              _buildKpiCard('Total Enrolled', '${_students.length}', Icons.groups, AppTheme.primary),
              const SizedBox(width: 12),
              _buildKpiCard('Active Students', '$activeCount', Icons.check_circle_outline, AppTheme.success),
              const SizedBox(width: 12),
              _buildKpiCard('Fee Concessions', '$discountCount', Icons.discount_outlined, Colors.purple),
              const SizedBox(width: 12),
              _buildKpiCard('Gender Ratio', '$maleCount M / $femaleCount F', Icons.wc, Colors.orange),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Bar
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by student name, roll, adm no, or parent mobile...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      onChanged: (val) => setState(() => _studentSearch = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _studentClassFilter,
                      decoration: InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Classes')),
                        ..._classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.section})'))),
                      ],
                      onChanged: (val) => setState(() => _studentClassFilter = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _studentSectionFilter,
                      decoration: InputDecoration(
                        labelText: 'Section',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Sections')),
                        ..._sections.map((sec) => DropdownMenuItem(value: sec.name, child: Text(sec.name))),
                      ],
                      onChanged: (val) => setState(() => _studentSectionFilter = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _studentStatusFilter,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'active', child: Text('Active Enrolled')),
                        DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                        DropdownMenuItem(value: 'graduated', child: Text('Graduated')),
                      ],
                      onChanged: (val) => setState(() => _studentStatusFilter = val ?? 'All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _studentGenderFilter,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Genders')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _studentGenderFilter = val ?? 'All'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Students Data Table
          Expanded(
            child: Card(
              child: filtered.isEmpty
                  ? const Center(child: Text('No students found matching your criteria.'))
                  : SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 18,
                          columns: const [
                            DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Adm. No', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Roll', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Class & Section', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Parent / Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Concession', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: Text(
                                          s.fullName.isNotEmpty ? s.fullName.substring(0, 1).toUpperCase() : 'S',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(s.category ?? 'General', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(s.admissionNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                                  ),
                                ),
                                DataCell(Text(s.rollNo, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(s.className ?? 'Unassigned')),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(s.fatherName ?? s.parentName ?? 'Guardian', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                      Text(s.fatherPhone ?? s.parentPhone ?? 'No Phone', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  s.feeDiscountPercent > 0
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text('${s.feeDiscountPercent.toStringAsFixed(0)}% Off',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                                        )
                                      : const Text('Standard', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: s.status == 'active' ? AppTheme.successLight : AppTheme.dangerLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      s.status.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: s.status == 'active' ? AppTheme.success : AppTheme.danger),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.primary),
                                        tooltip: '360° Student Profile & Ledger',
                                        onPressed: () => _showStudentProfileModal(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        tooltip: 'Edit Profile',
                                        onPressed: () => _showEditStudentDialog(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.point_of_sale, size: 16, color: AppTheme.success),
                                        tooltip: 'Collect Fee at Counter',
                                        onPressed: () => _showCollectCashFeeDialog(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.badge_outlined, size: 16, color: Colors.indigo),
                                        tooltip: 'Print Student ID Card',
                                        onPressed: () => _printSingleStudentIdCard(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.event_seat_outlined, size: 16, color: Colors.purple),
                                        tooltip: 'Print Exam Admit Card',
                                        onPressed: () => _printSingleStudentAdmitCard(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                                        tooltip: 'Delete Student Record',
                                        onPressed: () => _confirmDelete(
                                          title: 'Delete Student: ${s.fullName}',
                                          message: 'Are you sure you want to permanently delete student ${s.fullName} (${s.admissionNo})? This cannot be undone.',
                                          onConfirm: () => SupabaseService.deleteStudent(s.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // TAB 3: STAFF & HR DIRECTORY
  // =====================================================================

  Widget _buildStaffTab() {
    final filtered = _staff.where((st) {
      if (_staffRoleFilter != 'All' && st.role.toLowerCase() != _staffRoleFilter.toLowerCase()) return false;
      if (_staffStatusFilter == 'Active' && !st.isActive) return false;
      if (_staffStatusFilter == 'Inactive' && st.isActive) return false;
      if (_staffSearch.isNotEmpty) {
        final q = _staffSearch.toLowerCase();
        final matchesName = st.fullName.toLowerCase().contains(q);
        final matchesCode = st.employeeCode.toLowerCase().contains(q);
        final matchesNatId = (st.nationalId ?? '').toLowerCase().contains(q);
        final matchesPhone = (st.phone ?? '').toLowerCase().contains(q);
        final matchesRole = st.role.toLowerCase().contains(q);
        if (!matchesName && !matchesCode && !matchesNatId && !matchesPhone && !matchesRole) return false;
      }
      return true;
    }).toList();

    final int facultyCount = _staff.where((s) => s.role.toLowerCase() == 'teacher' || s.role.toLowerCase() == 'faculty').length;
    final int nonTeachingCount = _staff.length - facultyCount;
    final double totalPayroll = _staff.where((s) => s.isActive).fold(0.0, (sum, s) => sum + s.salary);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Staff & Faculty Management (eSkooly HR)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Manage Teaching Faculty, Administrative Staff, Monthly Salaries, ID Cards & Official Letters', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('Print All Staff ID Cards'),
                    onPressed: _printAllStaffIdCards,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddStaffDialog,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add New Employee'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Summary Cards
          Row(
            children: [
              _buildMetricCard(
                'Total Employees',
                '${_staff.length}',
                Icons.badge,
                AppTheme.primary,
                subtitle: '${_staff.where((s) => s.isActive).length} Active',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Teaching Faculty',
                '$facultyCount',
                Icons.school,
                Colors.teal,
                subtitle: 'Teachers & Instructors',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Non-Teaching / Support',
                '$nonTeachingCount',
                Icons.engineering,
                Colors.orange,
                subtitle: 'Admin, Bursar, Library',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Monthly Payroll',
                '${_activeSchool.currencySymbol}${NumberFormat('#,##0').format(totalPayroll)}',
                Icons.account_balance_wallet,
                AppTheme.success,
                subtitle: 'Active Staff Compensation',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filters Bar
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Search Box
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search by employee name, code, phone, national ID...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _staffSearch = val),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Role Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Teacher', 'Principal', 'Accountant', 'Librarian', 'Admin', 'Staff'].map((r) {
                        final isSel = _staffRoleFilter == r;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(r, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            onSelected: (val) => setState(() => _staffRoleFilter = r),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status Filter Chips
                  Row(
                    children: ['All', 'Active', 'Inactive'].map((st) {
                      final isSel = _staffStatusFilter == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(st, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          onSelected: (val) => setState(() => _staffStatusFilter = st),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Staff Data Table
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No employees match the current filters.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Reset All Filters'),
                            onPressed: () {
                              setState(() {
                                _staffSearch = '';
                                _staffRoleFilter = 'All';
                                _staffStatusFilter = 'All';
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: DataTable(
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Emp. Code', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Designation & Dept', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Experience / Edu', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('National ID', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Salary', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((st) {
                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _showStaffProfileModal(st),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.primaryLight,
                                        child: Text(
                                          st.fullName.isNotEmpty ? st.fullName.substring(0, 1).toUpperCase() : 'E',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          if (st.gender != null)
                                            Text(st.gender!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text(st.employeeCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.surfaceSubtle, borderRadius: BorderRadius.circular(6)),
                                  child: Text(st.role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(st.designation, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                    Text(st.department, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(st.experience ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    if (st.qualification != null)
                                      Text(st.qualification!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(Text(st.nationalId ?? 'N/A', style: const TextStyle(fontSize: 11))),
                              DataCell(
                                Text(
                                  '${_activeSchool.currencySymbol}${NumberFormat('#,##0.00').format(st.salary)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(st.phone ?? 'N/A', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                    if (st.email != null)
                                      Text(st.email!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: st.isActive ? AppTheme.success.withOpacity(0.15) : AppTheme.danger.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    st.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: st.isActive ? AppTheme.success : AppTheme.danger,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 17, color: AppTheme.primary),
                                      tooltip: 'View 360° Profile',
                                      onPressed: () => _showStaffProfileModal(st),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 17, color: AppTheme.textSecondary),
                                      tooltip: 'Edit Employee',
                                      onPressed: () => _showEditStaffDialog(st),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.badge_outlined, size: 17, color: Colors.blueAccent),
                                      tooltip: 'Print Staff ID Card',
                                      onPressed: () => _printSingleStaffIdCard(st),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.description_outlined, size: 17, color: Colors.indigo),
                                      tooltip: 'Print Job Letter',
                                      onPressed: () => _printStaffJobLetter(st),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.danger),
                                      tooltip: 'Delete Employee',
                                      onPressed: () {
                                        _confirmDelete(
                                          title: 'Delete Employee',
                                          message: 'Are you sure you want to remove "${st.fullName}" (${st.employeeCode})? This action cannot be undone.',
                                          onConfirm: () => SupabaseService.deleteStaff(st.id),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB 4: SMART ATTENDANCE (4-State Interactive Grid & Biometric Hook)
  // =====================================================================

  Widget _buildAttendanceTab() {
    final classStudents = _attendanceClass == null
        ? _students
        : _students.where((s) => s.classId == _attendanceClass!.id || (s.className != null && s.className!.contains(_attendanceClass!.name))).toList();

    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    int halfDayCount = 0;

    for (var s in classStudents) {
      final st = _attendanceMap[s.id] ?? 'Present';
      if (st == 'Present') presentCount++;
      if (st == 'Absent') absentCount++;
      if (st == 'Late') lateCount++;
      if (st == 'HalfDay') halfDayCount++;
    }

    final total = classStudents.length;
    final attPct = total > 0 ? ((presentCount + lateCount) / total) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Smart Attendance Grid & Absentee Alert Engine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('4-State Toggle Matrix (Present ➔ Absent ➔ Late ➔ HalfDay) with auto WhatsApp absentee alerts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showBiometricSimulatorDialog,
                    icon: const Icon(Icons.fingerprint, size: 16),
                    label: const Text('Biometric Punch Simulator'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    onPressed: () {
                      for (var s in classStudents) {
                        _attendanceMap[s.id] = 'Present';
                      }
                      setState(() {});
                    },
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark All Present'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter Bar & Date Picker (strictly <= CURRENT_DATE)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Class Picker
                  Expanded(
                    child: DropdownButtonFormField<ClassModel>(
                      initialValue: _attendanceClass,
                      decoration: const InputDecoration(labelText: 'Academic Class'),
                      items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (${c.section})'))).toList(),
                      onChanged: (c) {
                        setState(() {
                          _attendanceClass = c;
                          if (c != null) {
                            final cSt = _students.where((s) => s.classId == c.id || (s.className != null && s.className!.contains(c.name)));
                            for (var s in cSt) {
                              _attendanceMap.putIfAbsent(s.id, () => 'Present');
                            }
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Date Picker Button (strictly past/today validation)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _attendanceDate,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now(), // strictly blocks future dates
                      );
                      if (picked != null) {
                        setState(() => _attendanceDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('Date: ${DateFormat('yyyy-MM-dd').format(_attendanceDate)}'),
                  ),
                  const SizedBox(width: 16),
                  // Telemetry Counters
                  _buildAttPill('Present', presentCount, Colors.green),
                  const SizedBox(width: 6),
                  _buildAttPill('Absent', absentCount, Colors.red),
                  const SizedBox(width: 6),
                  _buildAttPill('Late', lateCount, Colors.orange),
                  const SizedBox(width: 6),
                  _buildAttPill('HalfDay', halfDayCount, Colors.blue),
                  const SizedBox(width: 12),
                  Text('${attPct.toStringAsFixed(0)}% Turnout', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Interactive 4-State Table
          Expanded(
            child: Card(
              child: classStudents.isEmpty
                  ? const Center(child: Text('No students enrolled in this class.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: classStudents.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final s = classStudents[idx];
                        final currentStatus = _attendanceMap[s.id] ?? 'Present';

                        Color badgeColor = Colors.green;
                        if (currentStatus == 'Absent') badgeColor = Colors.red;
                        if (currentStatus == 'Late') badgeColor = Colors.orange;
                        if (currentStatus == 'HalfDay') badgeColor = Colors.blue;

                        return ListTile(
                          title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Roll: ${s.rollNo} • Adm: ${s.admissionNo} • Parent: ${s.parentPhone ?? 'No Phone'}', style: const TextStyle(fontSize: 11)),
                          trailing: InkWell(
                            onTap: () {
                              // Cycle state: Present -> Absent -> Late -> HalfDay -> Present
                              String next = 'Present';
                              if (currentStatus == 'Present') {
                                next = 'Absent';
                              } else if (currentStatus == 'Absent') {
                                next = 'Late';
                              } else if (currentStatus == 'Late') {
                                next = 'HalfDay';
                              } else if (currentStatus == 'HalfDay') {
                                next = 'Present';
                              }

                              setState(() => _attendanceMap[s.id] = next);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: badgeColor, width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 4, backgroundColor: badgeColor),
                                  const SizedBox(width: 6),
                                  Text(currentStatus, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: badgeColor)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.sync, size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Save Batch Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  if (_attendanceClass == null) return;
                  final records = classStudents.map((s) {
                    return AttendanceRecord(
                      id: '',
                      studentId: s.id,
                      studentName: s.fullName,
                      rollNo: s.rollNo,
                      parentPhone: s.parentPhone,
                      status: _attendanceMap[s.id] ?? 'Present',
                      date: _attendanceDate,
                    );
                  }).toList();

                  final res = await SupabaseService.saveAttendance(
                    schoolId: _activeSchool.id,
                    classId: _attendanceClass!.id,
                    records: records,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']),
                      backgroundColor: res['success'] ? AppTheme.success : AppTheme.danger,
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_upload, size: 18),
                label: const Text('Commit Attendance & Dispatch Absentee Alerts'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttPill(String label, int count, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text('$label: $count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
    );
  }

  // =====================================================================
  // TAB 5: FINANCES & DOUBLE-ENTRY INVOICING / CASH LEDGER
  // =====================================================================

  Widget _buildFinancesTab() {
    final filteredInvoices = _invoices.where((inv) {
      if (_invoiceStatusFilter != 'All' && inv.status != _invoiceStatusFilter) return false;
      return true;
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Fee & Financial Accounting (Double-Entry Ledger)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Manage monthly student fee invoicing, counter cash collection receipts, and institutional operating expenses', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showGenerateInvoicesDialog,
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Generate Invoices'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: _showAddExpenseDialog,
                      icon: const Icon(Icons.money_off, size: 16),
                      label: const Text('Log Expense'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.receipt), text: 'Student Invoicing & Counter Cash Collections'),
                Tab(icon: Icon(Icons.account_balance), text: 'Operating Expense Tracker & Ledger'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  // Sub-tab 1: Invoices
                  Column(
                    children: [
                      Row(
                        children: ['All', 'Unpaid', 'Partially Paid', 'Paid'].map((st) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(st),
                              selected: _invoiceStatusFilter == st,
                              onSelected: (_) => setState(() => _invoiceStatusFilter = st),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Card(
                          child: filteredInvoices.isEmpty
                              ? const Center(child: Text('No invoices recorded. Click "Generate Invoices" to create billing.'))
                              : SingleChildScrollView(
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Invoice No', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: filteredInvoices.map((inv) {
                                      final isPaid = inv.status == 'Paid';
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          DataCell(Text(inv.studentName)),
                                          DataCell(Text(inv.month)),
                                          DataCell(Text('${_activeSchool.currencySymbol}${inv.amount.toStringAsFixed(2)}')),
                                          DataCell(Text('${_activeSchool.currencySymbol}${inv.paidAmount.toStringAsFixed(2)}')),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isPaid ? AppTheme.successLight : (inv.status == 'Partially Paid' ? Colors.orange.shade100 : AppTheme.dangerLight),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(inv.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? AppTheme.success : (inv.status == 'Partially Paid' ? Colors.orange.shade800 : AppTheme.danger))),
                                            ),
                                          ),
                                          DataCell(
                                            isPaid
                                                ? const Text('Settled', style: TextStyle(color: Colors.grey, fontSize: 12))
                                                : ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme.success,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    ),
                                                    onPressed: () => _showPayInvoiceDialog(inv),
                                                    child: const Text('Collect Cash', style: TextStyle(fontSize: 11)),
                                                  ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  // Sub-tab 2: Expenses
                  Card(
                    child: _expenses.isEmpty
                        ? const Center(child: Text('No operating expenses logged.'))
                        : SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Voucher No', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Paid To', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Delete', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _expenses.map((exp) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(exp.voucherNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(exp.category)),
                                    DataCell(Text(exp.paidTo)),
                                    DataCell(Text('${_activeSchool.currencySymbol}${exp.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger))),
                                    DataCell(Text(DateFormat('yyyy-MM-dd').format(exp.paymentDate))),
                                    DataCell(Text(exp.remarks ?? '', style: const TextStyle(fontSize: 11))),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                                        onPressed: () async {
                                          await SupabaseService.deleteExpense(exp.id);
                                          _loadAllData();
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // TAB 6: EXAMINATIONS & WEIGHTED MARKS ENGINE
  // =====================================================================

  Widget _buildExamsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Academic & Examination Engine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Custom grading scales, multi-component weighted tracking: Final = (Assignments×0.2) + (MidTerms×0.3) + (FinalExam×0.5)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddWeightedMarkDialog,
                icon: const Icon(Icons.add_chart, size: 18),
                label: const Text('Enter Student Marks'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grading Scale Ribbon
          Card(
            color: AppTheme.surfaceSubtle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.grade, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Active Grading Configuration: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ..._gradingScales.map((gs) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text('${gs.gradeName}: ${gs.minPercentage.toStringAsFixed(0)}-${gs.maxPercentage.toStringAsFixed(0)}% (GPA ${gs.gradePoint})'),
                        backgroundColor: Colors.white,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _weightedMarks.isEmpty
                  ? const Center(child: Text('No examination marks recorded yet. Click "Enter Student Marks".'))
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Assignments (20%)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('MidTerm (30%)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Final Exam (50%)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Final Weighted Mark', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Assigned Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _weightedMarks.map((wm) {
                          return DataRow(
                            cells: [
                              DataCell(Text(wm.studentName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(wm.subjectName)),
                              DataCell(Text('${wm.assignmentMarks.toStringAsFixed(1)} / 100')),
                              DataCell(Text('${wm.midtermMarks.toStringAsFixed(1)} / 100')),
                              DataCell(Text('${wm.finalExamMarks.toStringAsFixed(1)} / 100')),
                              DataCell(Text('${wm.totalWeightedMarks.toStringAsFixed(2)} / 100', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                                  child: Text(wm.grade, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB 7: CONFIGURABLE A4 PRINT HUB
  // =====================================================================

  Widget _buildPrintHubTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Document & A4 Bulk Print Hub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Configure A4 page layouts, tear-off receipts, anti-cheating admit cards, and student ID cards', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.badge, color: AppTheme.primary, size: 28),
                        const SizedBox(height: 10),
                        const Text('Student ID Cards Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Text('Configurable 4, 8, or 10 cards per A4 page with QR codes & school branding', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: _idCardsPerPage,
                          decoration: const InputDecoration(labelText: 'Layout per A4 Sheet'),
                          items: const [
                            DropdownMenuItem(value: 4, child: Text('4 Cards per A4 Sheet (Large)')),
                            DropdownMenuItem(value: 8, child: Text('8 Cards per A4 Sheet (Standard Recommended)')),
                            DropdownMenuItem(value: 10, child: Text('10 Cards per A4 Sheet (Economy)')),
                          ],
                          onChanged: (val) => setState(() => _idCardsPerPage = val ?? 8),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_students.isEmpty) return;
                            Printing.layoutPdf(
                              onLayout: (fmt) => PdfPrintService.generateIdCardsA4(
                                school: _activeSchool,
                                students: _students,
                                cardsPerPage: _idCardsPerPage,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Generate Bulk ID Cards PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.receipt, color: AppTheme.success, size: 28),
                        const SizedBox(height: 10),
                        const Text('Cash Fee Receipts Generator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Text('Bulk A4 prints with dotted tear-off cutting guides and sequential receipts', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: _receiptsPerPage,
                          decoration: const InputDecoration(labelText: 'Receipts per A4 Sheet'),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 Receipt per A4 (Full Detailed)')),
                            DropdownMenuItem(value: 2, child: Text('2 Receipts per A4 (Standard Split)')),
                            DropdownMenuItem(value: 3, child: Text('3 Receipts per A4 (Economy Tear-Off)')),
                          ],
                          onChanged: (val) => setState(() => _receiptsPerPage = val ?? 2),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_fees.isEmpty) return;
                            Printing.layoutPdf(
                              onLayout: (fmt) => PdfPrintService.generateFeeReceiptA4(
                                school: _activeSchool,
                                fee: _fees.first,
                                receiptsPerPage: _receiptsPerPage,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Generate Bulk Fee Receipts PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event_seat, color: Colors.purple, size: 28),
                        const SizedBox(height: 10),
                        const Text('Admit Cards (Anti-Cheating Seating)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Text('Includes hall ticket barcode, randomized seat allocations and verified student portraits', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_students.isEmpty) return;
                            Printing.layoutPdf(
                              onLayout: (fmt) => PdfPrintService.generateAdmitCardA4(
                                school: _activeSchool,
                                student: _students.first,
                                examName: 'Term Examinations 2026',
                                roomNumber: 'Hall A (Room 102)',
                                deskNumber: 'DESK-0${_students.first.rollNo}',
                              ),
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Generate Admit Cards PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assessment, color: Colors.orange, size: 28),
                        const SizedBox(height: 10),
                        const Text('Holistic Progress Report Cards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Text('Comprehensive report cards with academic marks, grading key, and attendance telemetry', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_students.isEmpty) return;
                            final dummyCard = StudentReportCard(
                              student: _students.first,
                              examName: 'Mid-Term Examinations 2026',
                              academicYear: _activeSchool.academicYear,
                              subjects: [
                                SubjectMarks(subject: 'Mathematics', marksObtained: 92),
                                SubjectMarks(subject: 'Science & Physics', marksObtained: 88),
                                SubjectMarks(subject: 'English Literature', marksObtained: 84),
                                SubjectMarks(subject: 'Social Studies', marksObtained: 79),
                              ],
                            );
                            Printing.layoutPdf(
                              onLayout: (fmt) => PdfPrintService.generateReportCardA4(
                                school: _activeSchool,
                                reportCard: dummyCard,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Generate Sample Report Card PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB 8: INSTITUTE SETTINGS & BRANDING CUSTOMIZATION
  // =====================================================================

  Widget _buildSettingsTab() {
    final nameCtrl = TextEditingController(text: _activeSchool.name);
    final codeCtrl = TextEditingController(text: _activeSchool.code);
    final taglineCtrl = TextEditingController(text: _activeSchool.tagline);
    final currencyCtrl = TextEditingController(text: _activeSchool.currencySymbol);
    final admPrefixCtrl = TextEditingController(text: _activeSchool.admissionPrefix);
    final recPrefixCtrl = TextEditingController(text: _activeSchool.receiptPrefix);
    final sessionCtrl = TextEditingController(text: _activeSchool.academicYear);
    final feeDueCtrl = TextEditingController(text: _activeSchool.feeDueDay.toString());
    final phoneCtrl = TextEditingController(text: _activeSchool.phone ?? '');
    final emailCtrl = TextEditingController(text: _activeSchool.email ?? '');
    final addressCtrl = TextEditingController(text: _activeSchool.address ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Institute Settings & Branding Customization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Customize institution identifiers, currency symbols, prefixes, and academic sessions', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final feeDue = int.tryParse(feeDueCtrl.text) ?? _activeSchool.feeDueDay;
                  final res = await SupabaseService.updateSchool(
                    id: _activeSchool.id,
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim(),
                    maxStudents: _activeSchool.maxStudents,
                    currencySymbol: currencyCtrl.text.trim(),
                    admissionPrefix: admPrefixCtrl.text.trim(),
                    receiptPrefix: recPrefixCtrl.text.trim(),
                    academicYear: sessionCtrl.text.trim(),
                    tagline: taglineCtrl.text.trim(),
                    feeDueDay: feeDue,
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                  );
                  _showFeedback(res['message'] ?? (res['success'] == true ? 'Settings saved successfully!' : 'Failed to save settings'), isSuccess: res['success'] == true);
                  if (res['success'] == true) {
                    final refreshedSchools = await SupabaseService.fetchSchools();
                    final updated = refreshedSchools.firstWhere((s) => s.id == _activeSchool.id);
                    setState(() => _activeSchool = updated);
                  }
                },
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Settings'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('General Branding', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(flex: 2, child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Institution Name'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'School Code'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Motto / Tagline')),
                  const SizedBox(height: 20),
                  const Text('Financial & Billing Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: currencyCtrl, decoration: const InputDecoration(labelText: 'Currency Symbol (\$, ₹, ₨, £, €)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: feeDueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Fee Due Day (e.g. 10)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: admPrefixCtrl, decoration: const InputDecoration(labelText: 'Admission No. Prefix'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: recPrefixCtrl, decoration: const InputDecoration(labelText: 'Fee Receipt Prefix'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: sessionCtrl, decoration: const InputDecoration(labelText: 'Academic Session Year'))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Official Contacts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Admin Email'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Campus Physical Address')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // HELPER WIDGETS
  // =====================================================================

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      onTap: onTap,
    );
  }
}
