import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../auth/sign_in_screen.dart';
import '../school_admin/academic_hub_dialog.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final SchoolModel school;
  const TeacherAttendanceScreen({super.key, required this.school});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  List<StudentModel> _students = [];
  final Map<String, String> _attendanceMap = {}; // studentId -> 'present', 'absent', 'late'
  bool _isLoading = true;
  String _selectedClass = 'Grade 10-A';
  bool _scannerActive = false;

  @override
  void initState() {
    super.initState();
    _loadClassStudents();
  }

  Future<void> _loadClassStudents() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.fetchStudents(widget.school.id);
    setState(() {
      _students = list;
      for (var s in list) {
        _attendanceMap[s.id] = 'present';
      }
      // Demo: set one to absent
      if (list.length > 2) {
        _attendanceMap[list[2].id] = 'absent';
      }
      _isLoading = false;
    });
  }

  void _toggleStatus(String id) {
    setState(() {
      final current = _attendanceMap[id] ?? 'present';
      if (current == 'present') {
        _attendanceMap[id] = 'absent';
      } else if (current == 'absent') {
        _attendanceMap[id] = 'late';
      } else {
        _attendanceMap[id] = 'present';
      }
    });
  }

  void _markAllPresent() {
    setState(() {
      for (var s in _students) {
        _attendanceMap[s.id] = 'present';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked all students as Present!')));
  }

  Future<void> _commitAttendance() async {
    final records = _students.map((s) {
      return AttendanceRecord(
        id: '',
        studentId: s.id,
        studentName: s.fullName,
        rollNo: s.rollNo,
        parentPhone: s.parentPhone,
        status: _attendanceMap[s.id] ?? 'present',
        date: DateTime.now(),
      );
    }).toList();

    final result = await SupabaseService.saveAttendance(
      schoolId: widget.school.id,
      classId: _students.first.classId ?? 'c2222222-2222-2222-2222-222222222222',
      records: records,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Attendance Finalized'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s roll call for $_selectedClass is committed to Supabase.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.mark_chat_read, color: AppTheme.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${result['absentCount']} Absentee alert(s) dispatched to parents via WhatsApp.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendanceMap.values.where((v) => v == 'present').length;
    final absentCount = _attendanceMap.values.where((v) => v == 'absent').length;
    final lateCount = _attendanceMap.values.where((v) => v == 'late').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.school.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Text('Teacher Mobile Portal • Attendance & WhatsApp', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.school, color: AppTheme.primary),
            tooltip: 'Academic Hub (Timetable, Logs, PTM, Notices)',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AcademicHubDialog(
                  school: widget.school,
                  classes: const [],
                  staff: const [],
                  students: _students,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Class and Date Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(_selectedClass, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _markAllPresent,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('All Present'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _scannerActive = !_scannerActive);
                              if (_scannerActive) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ID Barcode Scanner Active. Scan student QR/barcode on ID card.')),
                                );
                              }
                            },
                            icon: Icon(_scannerActive ? Icons.camera_alt : Icons.qr_code_scanner, size: 16),
                            label: Text(_scannerActive ? 'Scanning...' : 'Scan ID'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _scannerActive ? AppTheme.warning : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Attendance Metric Chips
                  Row(
                    children: [
                      _buildMiniBadge('Present', '$presentCount', AppTheme.success, AppTheme.successLight),
                      const SizedBox(width: 8),
                      _buildMiniBadge('Absent', '$absentCount', AppTheme.danger, AppTheme.dangerLight),
                      const SizedBox(width: 8),
                      _buildMiniBadge('Late', '$lateCount', AppTheme.warning, AppTheme.warningLight),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Roll Call Student List
                  Expanded(
                    child: ListView.separated(
                      itemCount: _students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final status = _attendanceMap[student.id] ?? 'present';
                        final isAbsent = status == 'absent';
                        final isLate = status == 'late';

                        return InkWell(
                          onTap: () => _toggleStatus(student.id),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isAbsent ? AppTheme.dangerLight : (isLate ? AppTheme.warningLight : AppTheme.surface),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isAbsent ? AppTheme.danger : (isLate ? AppTheme.warning : AppTheme.borderSubtle),
                                width: isAbsent || isLate ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isAbsent ? AppTheme.danger : AppTheme.primary,
                                  child: Text(student.rollNo, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(
                                        'Parent: ${student.parentName ?? "Guardian"} • ${student.parentPhone ?? "No WhatsApp"}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isAbsent ? AppTheme.danger : (isLate ? AppTheme.warning : AppTheme.success),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Commit Button
                  ElevatedButton.icon(
                    onPressed: _commitAttendance,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text('Save Roll & Trigger $absentCount WhatsApp Notices'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMiniBadge(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
