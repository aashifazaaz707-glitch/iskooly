import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_print_service.dart';
import '../auth/sign_in_screen.dart';
import 'package:printing/printing.dart';

class StudentParentPortalScreen extends StatefulWidget {
  final SchoolModel school;
  const StudentParentPortalScreen({super.key, required this.school});

  @override
  State<StudentParentPortalScreen> createState() => _StudentParentPortalScreenState();
}

class _StudentParentPortalScreenState extends State<StudentParentPortalScreen> {
  int _currentTab = 0;
  List<StudentModel> _students = [];
  List<FeeCollectionModel> _fees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildInfo();
  }

  Future<void> _loadChildInfo() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.fetchStudents(widget.school.id);
    final fees = await SupabaseService.fetchCashFeeCollections(widget.school.id);
    setState(() {
      _students = list;
      _fees = fees;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = _students.isNotEmpty
        ? _students.first
        : StudentModel(
            id: '1',
            schoolId: widget.school.id,
            admissionNo: 'ADM-2026-001',
            rollNo: '1001',
            fullName: 'Aarav Sharma',
            className: 'Grade 10',
            section: 'A',
          );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.school.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const Text('Parent & Student Companion App (Sign-in Only)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student Identity Header Card
                  Card(
                    color: AppTheme.primaryLight,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.primary,
                            child: const Icon(Icons.person, size: 32, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                Text('Class: ${student.className ?? "Grade 10"}-${student.section ?? "A"}  |  Roll No: ${student.rollNo}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text('Admission ID: ${student.admissionNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Segmented Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPortalTab(0, 'Attendance', Icons.calendar_today),
                        const SizedBox(width: 6),
                        _buildPortalTab(1, 'Cash Receipts', Icons.receipt_long),
                        const SizedBox(width: 6),
                        _buildPortalTab(2, 'Admit Card', Icons.badge),
                        const SizedBox(width: 6),
                        _buildPortalTab(3, 'Report Card', Icons.assessment),
                        const SizedBox(width: 6),
                        _buildPortalTab(4, 'Class Timetable', Icons.calendar_view_week),
                        const SizedBox(width: 6),
                        _buildPortalTab(5, 'Notice Board', Icons.campaign),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active Tab Content
                  if (_currentTab == 0) _buildAttendanceView(),
                  if (_currentTab == 1) _buildFeeReceiptsView(),
                  if (_currentTab == 2) _buildAdmitCardView(student),
                  if (_currentTab == 3) _buildReportCardView(student),
                  if (_currentTab == 4) _buildTimetableView(),
                  if (_currentTab == 5) _buildNoticesView(),
                ],
              ),
            ),
    );
  }

  Widget _buildPortalTab(int index, String title, IconData icon) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Monthly Attendance History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('96.4% Overall', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
              ],
            ),
            const SizedBox(height: 14),
            _buildAttendanceRow('Today (Roll Call Finalized)', 'Present', AppTheme.success),
            _buildAttendanceRow('Yesterday', 'Present', AppTheme.success),
            _buildAttendanceRow('Friday, Last Week', 'Present', AppTheme.success),
            _buildAttendanceRow('Thursday, Last Week', 'Late (Recorded 08:42 AM)', AppTheme.warning),
            _buildAttendanceRow('Wednesday, Last Week', 'Present', AppTheme.success),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRow(String date, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeReceiptsView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cash Counter Payment Receipts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Text('All offline cash payments recorded at school accounts office', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            if (_fees.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No cash receipts on file yet.')))
            else
              ..._fees.map((fee) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fee.receiptNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                          Text(fee.remarks ?? 'Term Tuition Fee', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text('Paid via Cash on ${fee.paymentDate.toString().substring(0, 10)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${fee.amountPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.success)),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final pdfBytes = await PdfPrintService.generateFeeReceiptA4(
                                school: widget.school,
                                fee: fee,
                                receiptsPerPage: 1,
                              );
                              await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
                            },
                            icon: const Icon(Icons.print, size: 14),
                            label: const Text('Print PDF', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAdmitCardView(StudentModel student) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Official Exam Hall Ticket / Admit Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Text('Generated for upcoming Midterm Board Examination', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EXAM SEAT ASSIGNMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                      const Text('ROOM: HALL-A', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Text('DESK: DESK-01', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pdfBytes = await PdfPrintService.generateAdmitCardA4(
                        school: widget.school,
                        student: student,
                        examName: 'Midterm Board Examination 2026',
                        roomNumber: 'HALL-A',
                        deskNumber: 'DESK-01',
                        cardsPerPage: 1,
                      );
                      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download A4 Ticket'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCardView(StudentModel student) {
    final subjects = [
      SubjectMarks(subject: 'Mathematics', marksObtained: 94.0),
      SubjectMarks(subject: 'Science & Laboratory', marksObtained: 88.5),
      SubjectMarks(subject: 'English Language & Lit', marksObtained: 91.0),
      SubjectMarks(subject: 'Social Studies & Civics', marksObtained: 85.0),
      SubjectMarks(subject: 'Computer Science & AI', marksObtained: 98.0),
    ];

    final reportCard = StudentReportCard(
      student: student,
      examName: 'Term 1 Final Assessment 2026-2027',
      subjects: subjects,
      totalWorkingDays: 120,
      daysPresent: 116,
      teacherRemarks: 'Outstanding analytical capability. Consistently active in classroom discussions and laboratory practicals.',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Official Term Progress Report Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Term 1 Final Assessment • Published by Exam Office', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pdfBytes = await PdfPrintService.generateReportCardA4(
                      school: widget.school,
                      reportCard: reportCard,
                    );
                    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download A4 PDF'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Performance Header Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('TOTAL SCORE', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      Text('${reportCard.totalMarksObtained.toStringAsFixed(1)} / ${reportCard.totalMaxMarks.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('PERCENTAGE', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      Text('${reportCard.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('OVERALL GRADE', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      Text(reportCard.overallGrade, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.success)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('RESULT STATUS', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      const Text('PROMOTED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.success)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Subject Marks List
            const Text('Subject-wise Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...subjects.map((sub) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sub.subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Row(
                        children: [
                          Text('${sub.marksObtained.toStringAsFixed(1)} / 100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(6)),
                            child: Text(sub.grade, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableView() {
    final periods = [
      {'period': '1', 'time': '08:00 - 08:45', 'sub': 'Mathematics', 'room': 'Room 101', 'teacher': 'Dr. Sarah Jenkins'},
      {'period': '2', 'time': '08:50 - 09:35', 'sub': 'Physics', 'room': 'Lab 2', 'teacher': 'Prof. Alan Turing'},
      {'period': '3', 'time': '09:40 - 10:25', 'sub': 'English Literature', 'room': 'Room 101', 'teacher': 'Ms. Jane Austen'},
      {'period': '4', 'time': '10:45 - 11:30', 'sub': 'Chemistry', 'room': 'Lab 1', 'teacher': 'Dr. Marie Curie'},
      {'period': '5', 'time': '11:35 - 12:20', 'sub': 'Computer Science', 'room': 'Computer Lab', 'teacher': 'Mr. Charles Babbage'},
      {'period': '6', 'time': '12:25 - 01:10', 'sub': 'Physical Education', 'room': 'Sports Ground', 'teacher': 'Coach Carter'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weekly Class Routine (Grade 10-A)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                  child: const Text('TODAY (ACTIVE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...periods.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                      child: Center(child: Text(p['period']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['sub']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${p['time']} • ${p['room']} • ${p['teacher']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticesView() {
    final notices = [
      {'title': 'Annual Sports Day 2026 Registration Open', 'date': '28 Sept 2026', 'cat': 'Sports', 'content': 'All interested students can submit registration forms to the physical education department before next Friday.'},
      {'title': 'Mid-Term Examinations Timetable Released', 'date': '25 Sept 2026', 'cat': 'Academic', 'content': 'Examinations commence on 15th October. Please collect verified Hall Tickets from the class teacher.'},
      {'title': 'Science Exhibition & Robotics Fair', 'date': '20 Sept 2026', 'cat': 'General', 'content': 'Parent visitations are scheduled between 10:00 AM and 02:00 PM in the senior auditorium.'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Official Circulars & School Board', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...notices.map((n) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(n['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                        Text(n['date']!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(n['content']!, style: const TextStyle(fontSize: 12, height: 1.3)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
