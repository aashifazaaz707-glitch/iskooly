import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

class PdfPrintService {
  /// Generate A4 Sheet of ID Cards with Configurable Cards Per Page (e.g. 4, 8, 10)
  static Future<Uint8List> generateIdCardsA4({
    required SchoolModel school,
    required List<StudentModel> students,
    int cardsPerPage = 8, // 4, 8, or 10 per A4 page
  }) async {
    final pdf = pw.Document();

    // 8 cards per page: 2 columns x 4 rows
    // 4 cards per page: 2 columns x 2 rows
    final int crossAxisCount = 2;

    final chunks = <List<StudentModel>>[];
    for (var i = 0; i < students.length; i += cardsPerPage) {
      chunks.add(students.sublist(i, i + cardsPerPage > students.length ? students.length : i + cardsPerPage));
    }

    for (var chunk in chunks) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.GridView(
              crossAxisCount: crossAxisCount,
              childAspectRatio: cardsPerPage == 4 ? 1.4 : 1.7,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: chunk.map((student) {
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Header with School Name
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.indigo700,
                          borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              school.name.toUpperCase(),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(
                              'STUDENT IDENTITY CARD • AY 2026-2027',
                              style: const pw.TextStyle(color: PdfColors.indigo100, fontSize: 6),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      // Student Details & Photo Box
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            // Avatar Box
                            pw.Container(
                              width: 44,
                              height: 52,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400),
                                color: PdfColors.grey200,
                              ),
                              child: pw.Center(
                                child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            // Info Text
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(student.fullName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 2),
                                  pw.Text('Adm No: ${student.admissionNo}', style: const pw.TextStyle(fontSize: 7)),
                                  pw.Text('Roll No: ${student.rollNo}  |  Class: ${student.className ?? "10"}-${student.section ?? "A"}', style: const pw.TextStyle(fontSize: 7)),
                                  pw.Text('Blood Grp: ${student.bloodGroup ?? "O+"}', style: const pw.TextStyle(fontSize: 7)),
                                  pw.Text('Emergency: ${student.parentPhone ?? "School Office"}', style: const pw.TextStyle(fontSize: 6.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Spacer(),
                      // Bottom Auth Bar
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.BarcodeWidget(
                              data: student.admissionNo,
                              barcode: pw.Barcode.code128(),
                              width: 60,
                              height: 16,
                              drawText: false,
                            ),
                            pw.Text('Principal Sign', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Generate Cash Fee Receipt (Configurable 1, 2, or 3 per A4 sheet)
  static Future<Uint8List> generateFeeReceiptA4({
    required SchoolModel school,
    required FeeCollectionModel fee,
    int receiptsPerPage = 2, // 1, 2, or 3 per A4 page
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          final count = receiptsPerPage.clamp(1, 3);
          return pw.Column(
            children: List.generate(count, (index) {
              final label = index == 0 ? 'ORIGINAL - PARENT COPY' : (index == 1 ? 'DUPLICATE - ACCOUNTS COPY' : 'TRIPLICATE - OFFICE COPY');
              return pw.Expanded(
                child: pw.Container(
                  margin: pw.EdgeInsets.only(bottom: index == count - 1 ? 0 : 16),
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(school.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                              pw.Text('${school.address ?? "Campus Office"} • Phone: ${school.phone ?? "N/A"}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 0.8, color: PdfColors.grey400),
                      // Receipt Meta
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Receipt No: ${fee.receiptNo}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Date: ${DateFormat('dd MMM yyyy').format(fee.paymentDate)}', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('Payment Mode: CASH COUNTER', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      // Student Details
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        color: PdfColors.grey100,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Student: ${fee.studentName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Class: ${fee.studentClass}', style: const pw.TextStyle(fontSize: 8.5)),
                            pw.Text('Roll No: ${fee.studentRoll}', style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      // Amount Row
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Description: ${fee.remarks ?? "School Tuition & Academic Dues"}', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('Total Paid: \$${fee.amountPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        ],
                      ),
                      pw.Spacer(),
                      // Signatures
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Printed via ISKOOL Platform', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                          pw.Text('Authorized Cashier Signature ____________________', style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Admit Card / Hall Ticket with Exam Seating
  static Future<Uint8List> generateAdmitCardA4({
    required SchoolModel school,
    required StudentModel student,
    required String examName,
    required String roomNumber,
    required String deskNumber,
    int cardsPerPage = 2, // 2 or 4 admit cards per A4 page
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            children: List.generate(cardsPerPage.clamp(1, 2), (i) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.indigo900, width: 1.2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(school.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text('OFFICIAL EXAM HALL TICKET / ADMIT CARD', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.indigo700, fontWeight: pw.FontWeight.bold)),
                          pw.Text(examName, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Candidate: ${student.fullName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Admission No: ${student.admissionNo}', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('Roll No: ${student.rollNo}  |  Class: ${student.className ?? "Grade 10"}-${student.section ?? "A"}', style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                        ),
                        // Allocated Seating Badge
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.indigo50,
                            border: pw.Border.all(color: PdfColors.indigo300),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text('SEAT ALLOCATION', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                              pw.Text('ROOM: $roomNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.Text('DESK: $deskNumber', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text('Exam Instructions: Carry this Admit Card and your Student ID. Reporting time is 20 minutes before schedule.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    pw.SizedBox(height: 14),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Candidate Sign: __________________', style: const pw.TextStyle(fontSize: 7.5)),
                        pw.Text('Invigilator Sign: __________________', style: const pw.TextStyle(fontSize: 7.5)),
                        pw.Text('Controller of Exams', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Official A4 Student Progress Report Card
  static Future<Uint8List> generateReportCardA4({
    required SchoolModel school,
    required StudentReportCard reportCard,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final student = reportCard.student;
          return pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.indigo900, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top School Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        school.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${school.address ?? "Campus Office"} • Phone: ${school.phone ?? "N/A"}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.indigo700,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'HOLISTIC STUDENT PROGRESS REPORT CARD • ${reportCard.academicYear}',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        reportCard.examName,
                        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Student Profile Info Grid
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Student Name: ${student.fullName}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text('Admission No: ${student.admissionNo}', style: const pw.TextStyle(fontSize: 8)),
                          pw.SizedBox(height: 2),
                          pw.Text('Guardian Name: ${student.parentName ?? "Guardian"}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Class & Section: ${student.className ?? "Grade 10"}-${student.section ?? "A"}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text('Roll Number: ${student.rollNo}', style: const pw.TextStyle(fontSize: 8)),
                          pw.SizedBox(height: 2),
                          pw.Text('Blood Group: ${student.bloodGroup ?? "O+"}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Attendance', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            '${reportCard.daysPresent} / ${reportCard.totalWorkingDays} Days (${reportCard.attendancePercentage.toStringAsFixed(1)}%)',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Status: Regular', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.green800)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Academic Evaluation Marks Table
                pw.Text('Part 1: Scholastic Performance & Assessment', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(1.4),
                    4: const pw.FlexColumnWidth(1),
                    5: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                      children: [
                        _buildTableHeader('Subject'),
                        _buildTableHeader('Max Marks'),
                        _buildTableHeader('Min Pass'),
                        _buildTableHeader('Obtained'),
                        _buildTableHeader('Grade'),
                        _buildTableHeader('Evaluation Remarks'),
                      ],
                    ),
                    // Subject Rows
                    ...reportCard.subjects.map((sub) {
                      return pw.TableRow(
                        children: [
                          _buildTableCell(sub.subject, isBold: true),
                          _buildTableCell(sub.maxMarks.toStringAsFixed(0)),
                          _buildTableCell(sub.passingMarks.toStringAsFixed(0)),
                          _buildTableCell(sub.marksObtained.toStringAsFixed(1), isBold: true),
                          _buildTableCell(sub.grade, isBold: true, color: sub.grade.startsWith('A') ? PdfColors.green800 : PdfColors.black),
                          _buildTableCell(sub.remarks),
                        ],
                      );
                    }).toList(),
                    // Total Summary Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('TOTAL AGGREGATE', isBold: true),
                        _buildTableCell(reportCard.totalMaxMarks.toStringAsFixed(0), isBold: true),
                        _buildTableCell('${(reportCard.totalMaxMarks * 0.35).toStringAsFixed(0)}', isBold: true),
                        _buildTableCell(reportCard.totalMarksObtained.toStringAsFixed(1), isBold: true, color: PdfColors.indigo900),
                        _buildTableCell(reportCard.overallGrade, isBold: true, color: PdfColors.indigo900),
                        _buildTableCell('${reportCard.percentage.toStringAsFixed(1)}% (${reportCard.resultStatus})', isBold: true),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Part 2: Co-Scholastic & Behavioral Indicators
                pw.Text('Part 2: Co-Scholastic Traits & Life Skills (3-Point Scale: A - Outstanding, B - Very Good, C - Fair)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _buildTableCell('Work Habits & Punctuality'),
                        _buildTableCell('A', isBold: true, color: PdfColors.green800),
                        _buildTableCell('Discipline & School Values'),
                        _buildTableCell('A', isBold: true, color: PdfColors.green800),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildTableCell('Scientific Thinking & Curiosity'),
                        _buildTableCell('A', isBold: true, color: PdfColors.green800),
                        _buildTableCell('Sports & Physical Fitness'),
                        _buildTableCell('B', isBold: true, color: PdfColors.indigo800),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Remarks & Result Announcement Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.indigo200),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Class Teacher Remarks:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text('"${reportCard.teacherRemarks}"', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('ANNUAL RESULT', style: const pw.TextStyle(color: PdfColors.white, fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(reportCard.resultStatus, style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Grading Legend
                pw.Text('Grading Scale: A1 (91-100) • A2 (81-90) • B1 (71-80) • B2 (61-70) • C1 (51-60) • C2 (41-50) • D (33-40) • E (Needs Improvement)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
                pw.SizedBox(height: 16),

                // Signatures Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 110, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Class Teacher Signature', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 110, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Exam Controller Signature', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Principal & Institutional Seal', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
      ),
    );
  }

  static pw.Widget _buildCardLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Text('$label ', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 6.5), overflow: pw.TextOverflow.clip),
          ),
        ],
      ),
    );
  }

  /// Generate A4 Sheet of Staff ID Cards (eSkooly Staff ID Card)
  static Future<Uint8List> generateStaffIdCardsA4({
    required SchoolModel school,
    required List<StaffModel> staff,
    int cardsPerPage = 8,
  }) async {
    final pdf = pw.Document();
    final int crossAxisCount = 2;

    final chunks = <List<StaffModel>>[];
    for (var i = 0; i < staff.length; i += cardsPerPage) {
      chunks.add(staff.sublist(i, i + cardsPerPage > staff.length ? staff.length : i + cardsPerPage));
    }

    for (var chunk in chunks) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.GridView(
              crossAxisCount: crossAxisCount,
              childAspectRatio: cardsPerPage == 4 ? 1.4 : 1.7,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: chunk.map((member) {
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.indigo900, width: 1.2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Header with School Name & Badge
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.indigo900,
                          borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6.8)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              school.name.toUpperCase(),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(
                              'FACULTY & STAFF IDENTITY CARD',
                              style: const pw.TextStyle(color: PdfColors.amber300, fontSize: 6.5),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      // Avatar & Details
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 48,
                              height: 54,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey200,
                                border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  member.fullName.isNotEmpty ? member.fullName.substring(0, 1).toUpperCase() : 'E',
                                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    member.fullName.toUpperCase(),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.indigo900),
                                  ),
                                  pw.Text(
                                    '${member.designation} (${member.role})',
                                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                                  ),
                                  pw.SizedBox(height: 3),
                                  _buildCardLine('Emp Code:', member.employeeCode),
                                  _buildCardLine('Department:', member.department),
                                  if (member.phone != null) _buildCardLine('Phone:', member.phone!),
                                  if (member.bloodGroup != null) _buildCardLine('Blood Group:', member.bloodGroup!),
                                  if (member.nationalId != null) _buildCardLine('National ID:', member.nationalId!),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Spacer(),
                      // Bottom Auth Bar
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.vertical(bottom: pw.Radius.circular(6.8)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Emergency: ${school.phone ?? 'Admin Desk'}', style: const pw.TextStyle(fontSize: 5.5)),
                            pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Generate Official Job Letter / Appointment Letter (eSkooly Job Letter)
  static Future<Uint8List> generateJobLetterA4({
    required SchoolModel school,
    required StaffModel staff,
  }) async {
    final pdf = pw.Document();
    final today = DateFormat('dd MMMM yyyy').format(DateTime.now());
    final joinDateFormatted = staff.joiningDate != null ? DateFormat('dd MMMM yyyy').format(staff.joiningDate!) : today;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Letterhead Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        school.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                      pw.Text(
                        school.tagline.isNotEmpty ? school.tagline : 'Excellence in Education & Academic Leadership',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '${school.address ?? ''} • Tel: ${school.phone ?? ''}',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.indigo900, width: 1.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      'OFFICIAL APPOINTMENT',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1.2, color: PdfColors.indigo900),
              pw.SizedBox(height: 14),

              // Reference and Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ref: ${school.code}/HR/${DateTime.now().year}/${staff.employeeCode}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  pw.Text('Date: $today', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                ],
              ),
              pw.SizedBox(height: 16),

              // Recipient Address
              pw.Text('To,', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(staff.fullName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              if (staff.fatherOrHusbandName != null) pw.Text('S/O, D/O, W/O: ${staff.fatherOrHusbandName}', style: const pw.TextStyle(fontSize: 9)),
              if (staff.nationalId != null) pw.Text('National ID: ${staff.nationalId}', style: const pw.TextStyle(fontSize: 9)),
              if (staff.homeAddress != null) pw.Text('Address: ${staff.homeAddress}', style: const pw.TextStyle(fontSize: 9)),
              if (staff.phone != null) pw.Text('Contact: ${staff.phone}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 18),

              // Subject
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                color: PdfColors.grey200,
                child: pw.Text(
                  'SUBJECT: OFFICIAL LETTER OF APPOINTMENT AS ${staff.role.toUpperCase()} (${staff.designation.toUpperCase()})',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
              ),
              pw.SizedBox(height: 16),

              // Body Content
              pw.Text(
                'Dear ${staff.fullName},',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'On behalf of the Governing Body and Management of ${school.name}, we are pleased to confirm your appointment for the position of ${staff.role} in the Department of ${staff.department}, with effect from $joinDateFormatted.',
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'The key terms and conditions of your employment are outlined below:',
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
              ),
              pw.SizedBox(height: 8),

              // Terms Table
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.8)),
                child: pw.Column(
                  children: [
                    _buildLetterRow('Employee Code', staff.employeeCode),
                    _buildLetterRow('Designation', staff.designation),
                    _buildLetterRow('Department', staff.department),
                    _buildLetterRow('Monthly Remuneration', '${school.currencySymbol}${staff.salary.toStringAsFixed(2)} per calendar month'),
                    _buildLetterRow('Effective Joining Date', joinDateFormatted),
                    _buildLetterRow('Academic Session', school.academicYear),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'You will be responsible for upholding the academic excellence, student mentorship, and pedagogical integrity of ${school.name}. Please sign the duplicate copy of this letter as confirmation of your formal acceptance.',
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'We warmly welcome you to our academic community and look forward to your valuable contributions.',
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey800),
                      pw.SizedBox(height: 4),
                      pw.Text('Candidate Acceptance Signature', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Name: ${staff.fullName}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey800),
                      pw.SizedBox(height: 4),
                      pw.Text('Principal / Institutional Authority', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text(school.name, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildLetterRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 160, child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800))),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 8.5))),
        ],
      ),
    );
  }
}
