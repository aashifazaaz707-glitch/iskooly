import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';

class AcademicHubDialog extends StatefulWidget {
  final SchoolModel school;
  final List<ClassModel> classes;
  final List<StaffModel> staff;
  final List<StudentModel> students;

  const AcademicHubDialog({
    super.key,
    required this.school,
    required this.classes,
    required this.staff,
    required this.students,
  });

  @override
  State<AcademicHubDialog> createState() => _AcademicHubDialogState();
}

class _AcademicHubDialogState extends State<AcademicHubDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Data
  List<TimetableSlotModel> _slots = [];
  List<LessonPlanModel> _plans = [];
  List<TeachingLogModel> _logs = [];
  List<PtmSlotModel> _ptmSlots = [];
  List<StudentDisciplineModel> _discipline = [];
  List<SchoolNoticeModel> _notices = [];
  List<InventoryAssetModel> _inventory = [];

  // Filter
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    if (widget.classes.isNotEmpty) {
      _selectedClassId = widget.classes.first.id;
    }
    _loadAllModules();
  }

  Future<void> _loadAllModules() async {
    setState(() => _isLoading = true);
    final schoolId = widget.school.id;
    final slots = await SupabaseService.fetchTimetable(schoolId, classId: _selectedClassId);
    final plans = await SupabaseService.fetchLessonPlans(schoolId);
    final logs = await SupabaseService.fetchTeachingLogs(schoolId);
    final ptms = await SupabaseService.fetchPtmSlots(schoolId);
    final discipline = await SupabaseService.fetchDisciplineRecords(schoolId);
    final notices = await SupabaseService.fetchNotices(schoolId);
    final inventory = await SupabaseService.fetchInventory(schoolId);

    if (mounted) {
      setState(() {
        _slots = slots;
        _plans = plans;
        _logs = logs;
        _ptmSlots = ptms;
        _discipline = discipline;
        _notices = notices;
        _inventory = inventory;
        _isLoading = false;
      });
    }
  }

  void _showFeedback(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1100,
        height: 720,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.school.name} — Academic & Campus Operations Hub',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Full Suite: Timetable Grid, Lesson Planning, Teaching Logs, PTM Slots, Discipline, Notices & Assets',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_view_week, size: 18), text: 'Timetable Grid'),
                Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Lesson Plans'),
                Tab(icon: Icon(Icons.history_edu, size: 18), text: 'Teaching Logbook'),
                Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'PTM Booking'),
                Tab(icon: Icon(Icons.gavel, size: 18), text: 'Discipline & Conduct'),
                Tab(icon: Icon(Icons.campaign, size: 18), text: 'Notice Board'),
                Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Asset Register'),
              ],
            ),
            const Divider(height: 1),
            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTimetableView(),
                        _buildLessonPlansView(),
                        _buildTeachingLogsView(),
                        _buildPtmView(),
                        _buildDisciplineView(),
                        _buildNoticesView(),
                        _buildInventoryView(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. TIMETABLE GRID VIEW
  // =========================================================================
  Widget _buildTimetableView() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Select Class: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedClassId,
                  items: widget.classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.section})'))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedClassId = val);
                    _loadAllModules();
                  },
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Period Slot'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddSlotDialog,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _slots.isEmpty
              ? _buildEmptyState('No timetable periods configured for this class.', Icons.calendar_today, _showAddSlotDialog, 'Create First Period')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.primaryLight),
                      columns: [
                        const DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Period 1\n08:00 - 08:45', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Period 2\n08:50 - 09:35', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Period 3\n09:40 - 10:25', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Period 4\n10:45 - 11:30', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Period 5\n11:35 - 12:20', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('Period 6\n12:25 - 01:10', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: days.map((day) {
                        return DataRow(
                          cells: [
                            DataCell(Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ...List.generate(6, (pIdx) {
                              final periodNum = pIdx + 1;
                              final match = _slots.where((s) => s.dayOfWeek.toLowerCase() == day.toLowerCase() && s.periodNumber == periodNum).toList();
                              if (match.isEmpty) {
                                return const DataCell(Text('—', style: TextStyle(color: Colors.grey)));
                              }
                              final s = match.first;
                              return DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary)),
                                      Text(s.roomNumber ?? 'Rm 101', style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddSlotDialog() {
    final dayCtrl = TextEditingController(text: 'Monday');
    final periodCtrl = TextEditingController(text: '1');
    final startCtrl = TextEditingController(text: '08:00');
    final endCtrl = TextEditingController(text: '08:45');
    final subjectCtrl = TextEditingController(text: 'Mathematics');
    final roomCtrl = TextEditingController(text: 'Room 101');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Timetable Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: dayCtrl.text,
              items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => dayCtrl.text = v ?? 'Monday',
              decoration: const InputDecoration(labelText: 'Day of Week'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: periodCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Period # (1-6)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room Number'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject Name (e.g. Physics, English)')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start (08:00)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End (08:45)'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_selectedClassId == null) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.addTimetableSlot(
                schoolId: widget.school.id,
                classId: _selectedClassId!,
                section: 'A',
                dayOfWeek: dayCtrl.text,
                periodNumber: int.tryParse(periodCtrl.text) ?? 1,
                startTime: startCtrl.text,
                endTime: endCtrl.text,
                subjectName: subjectCtrl.text,
                roomNumber: roomCtrl.text,
              );
              _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
              _loadAllModules();
            },
            child: const Text('Save Period'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. LESSON PLANS VIEW
  // =========================================================================
  Widget _buildLessonPlansView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Curriculum Syllabus Plans (${_plans.length} items)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Lesson Plan'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddLessonPlanDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _plans.isEmpty
              ? _buildEmptyState('No lesson plans registered.', Icons.menu_book, _showAddLessonPlanDialog, 'Create Lesson Plan')
              : ListView.builder(
                  itemCount: _plans.length,
                  itemBuilder: (ctx, idx) {
                    final p = _plans[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.status == 'Completed' ? Colors.green.withValues(alpha: 0.15) : AppTheme.primaryLight,
                          child: Icon(
                            p.status == 'Completed' ? Icons.check_circle : Icons.bookmark,
                            color: p.status == 'Completed' ? Colors.green : AppTheme.primary,
                          ),
                        ),
                        title: Text(p.topicTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p.subjectName} • Target Date: ${p.plannedDate.toLocal().toString().substring(0, 10)}\nObjectives: ${p.objectives ?? "Standard curriculum coverage"}'),
                        trailing: Chip(
                          label: Text(p.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: p.status == 'Completed' ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddLessonPlanDialog() {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(text: 'Science');
    final objectivesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Curriculum Lesson Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Topic Title (e.g. Newton Laws of Motion)')),
            const SizedBox(height: 10),
            TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject Name')),
            const SizedBox(height: 10),
            TextField(controller: objectivesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Pedagogical Objectives')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || widget.classes.isEmpty) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.addLessonPlan(
                schoolId: widget.school.id,
                classId: _selectedClassId ?? widget.classes.first.id,
                subjectName: subjectCtrl.text,
                topicTitle: titleCtrl.text,
                objectives: objectivesCtrl.text,
                plannedDate: DateTime.now().add(const Duration(days: 3)),
              );
              _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
              _loadAllModules();
            },
            child: const Text('Create Plan'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. TEACHING DAILY LOGBOOK VIEW
  // =========================================================================
  Widget _buildTeachingLogsView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Teaching Syllabus Logbook (${_logs.length} entries)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Log Daily Lecture'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddLogDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _logs.isEmpty
              ? _buildEmptyState('No teaching activity logs logged yet.', Icons.history_edu, _showAddLogDialog, 'Record Today Lecture')
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (ctx, idx) {
                    final log = _logs[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${log.subjectName} — Period ${log.periodNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                                Text(log.date.toLocal().toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Activity: ${log.activitySummary}', style: const TextStyle(fontSize: 12)),
                            if (log.homeworkAssigned != null && log.homeworkAssigned!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Homework: ${log.homeworkAssigned}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddLogDialog() {
    final activityCtrl = TextEditingController();
    final hwCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(text: 'Mathematics');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Lecture / Teaching Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject Name')),
            const SizedBox(height: 10),
            TextField(controller: activityCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Activity & Syllabus Covered')),
            const SizedBox(height: 10),
            TextField(controller: hwCtrl, decoration: const InputDecoration(labelText: 'Homework Assigned (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (activityCtrl.text.isEmpty || widget.staff.isEmpty || widget.classes.isEmpty) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.addTeachingLog(
                schoolId: widget.school.id,
                teacherId: widget.staff.first.id,
                classId: _selectedClassId ?? widget.classes.first.id,
                subjectName: subjectCtrl.text,
                date: DateTime.now(),
                periodNumber: 1,
                activitySummary: activityCtrl.text,
                homeworkAssigned: hwCtrl.text,
              );
              _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
              _loadAllModules();
            },
            child: const Text('Save Entry'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. PTM (PARENT-TEACHER MEETING) SLOTS VIEW
  // =========================================================================
  Widget _buildPtmView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Parent-Teacher Meeting Schedules (${_ptmSlots.length} slots)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Open PTM Slot'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddPtmDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _ptmSlots.isEmpty
              ? _buildEmptyState('No PTM slots available.', Icons.people_alt_outlined, _showAddPtmDialog, 'Create PTM Slot')
              : ListView.builder(
                  itemCount: _ptmSlots.length,
                  itemBuilder: (ctx, idx) {
                    final ptm = _ptmSlots[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ptm.status == 'Booked' ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                          child: Icon(
                            ptm.status == 'Booked' ? Icons.event_busy : Icons.event_available,
                            color: ptm.status == 'Booked' ? Colors.orange : Colors.green,
                          ),
                        ),
                        title: Text('Date: ${ptm.slotDate.toLocal().toString().substring(0, 10)} at ${ptm.slotTime}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Status: ${ptm.status} • Notes: ${ptm.notes ?? "General Academic Progress Discussion"}'),
                        trailing: Chip(
                          label: Text(ptm.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: ptm.status == 'Booked' ? Colors.orange.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddPtmDialog() {
    final timeCtrl = TextEditingController(text: '10:30 AM');
    final noteCtrl = TextEditingController(text: 'Quarterly academic review');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule PTM Meeting Slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Slot Timing (e.g. 10:30 AM)')),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Agenda / Purpose')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (widget.staff.isEmpty) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.addPtmSlot(
                schoolId: widget.school.id,
                teacherId: widget.staff.first.id,
                slotDate: DateTime.now().add(const Duration(days: 2)),
                slotTime: timeCtrl.text,
                notes: noteCtrl.text,
              );
              _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
              _loadAllModules();
            },
            child: const Text('Open Slot'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. STUDENT CONDUCT & DISCIPLINE VIEW
  // =========================================================================
  Widget _buildDisciplineView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Disciplinary Logs & Commendations (${_discipline.length} incidents)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Record Incident / Merit'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddDisciplineDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _discipline.isEmpty
              ? _buildEmptyState('No disciplinary records logged.', Icons.gavel, _showAddDisciplineDialog, 'Log First Entry')
              : ListView.builder(
                  itemCount: _discipline.length,
                  itemBuilder: (ctx, idx) {
                    final d = _discipline[idx];
                    final isMerit = d.category == 'Merit/Award';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMerit ? Colors.amber.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                          child: Icon(
                            isMerit ? Icons.emoji_events : Icons.warning_amber_rounded,
                            color: isMerit ? Colors.amber[800] : Colors.red,
                          ),
                        ),
                        title: Text('${d.category} (${d.severity})', style: TextStyle(fontWeight: FontWeight.bold, color: isMerit ? Colors.green[800] : Colors.red[800])),
                        subtitle: Text('Date: ${d.incidentDate.toLocal().toString().substring(0, 10)}\n${d.description}\nAction: ${d.actionTaken ?? "None"}'),
                        trailing: Text(d.reportedBy ?? 'Faculty', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddDisciplineDialog() {
    final descCtrl = TextEditingController();
    final actionCtrl = TextEditingController();
    String cat = 'Behavioral';
    String sev = 'Minor';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Log Student Incident or Merit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: cat,
                      items: ['Behavioral', 'Academic', 'Merit/Award', 'Attendance']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDState(() => cat = v ?? 'Behavioral'),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: sev,
                      items: ['Minor', 'Moderate', 'Major', 'Commendation']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setDState(() => sev = v ?? 'Minor'),
                      decoration: const InputDecoration(labelText: 'Severity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Incident / Merit Description')),
              const SizedBox(height: 10),
              TextField(controller: actionCtrl, decoration: const InputDecoration(labelText: 'Action Taken / Reward Granted')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descCtrl.text.isEmpty || widget.students.isEmpty) return;
                Navigator.pop(ctx);
                final res = await SupabaseService.addDisciplineRecord(
                  schoolId: widget.school.id,
                  studentId: widget.students.first.id,
                  incidentDate: DateTime.now(),
                  category: cat,
                  severity: sev,
                  description: descCtrl.text,
                  actionTaken: actionCtrl.text,
                  reportedBy: 'Discipline Committee',
                );
                _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
                _loadAllModules();
              },
              child: const Text('Record Incident'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 6. SCHOOL NOTICES & CIRCULARS VIEW
  // =========================================================================
  Widget _buildNoticesView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Campus Notice Board & Circulars (${_notices.length} active)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Publish Notice'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddNoticeDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _notices.isEmpty
              ? _buildEmptyState('No circulars or notices published.', Icons.campaign, _showAddNoticeDialog, 'Publish Notice')
              : ListView.builder(
                  itemCount: _notices.length,
                  itemBuilder: (ctx, idx) {
                    final n = _notices[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (n.isUrgent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Text(n.publishDate.toLocal().toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(n.content, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('Audience: ${n.targetAudience}', style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddNoticeDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isUrgent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setNState) => AlertDialog(
          title: const Text('Publish School Notice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Notice Title')),
              const SizedBox(height: 10),
              TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Circular Content / Details')),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as Urgent Alert'),
                value: isUrgent,
                onChanged: (v) => setNState(() => isUrgent = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final res = await SupabaseService.addNotice(
                  schoolId: widget.school.id,
                  title: titleCtrl.text,
                  content: contentCtrl.text,
                  targetAudience: 'All',
                  publishDate: DateTime.now(),
                  isUrgent: isUrgent,
                );
                _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
                _loadAllModules();
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 7. INVENTORY & ASSET REGISTER VIEW
  // =========================================================================
  Widget _buildInventoryView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Campus Assets & Inventory (${_inventory.length} items registered)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Register Asset'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: _showAddInventoryDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _inventory.isEmpty
              ? _buildEmptyState('No equipment or physical assets registered.', Icons.inventory_2, _showAddInventoryDialog, 'Register First Asset')
              : ListView.builder(
                  itemCount: _inventory.length,
                  itemBuilder: (ctx, idx) {
                    final item = _inventory[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.devices, color: Colors.blueGrey),
                        ),
                        title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Category: ${item.category} • Location: ${item.location ?? "Campus Store"}\nCondition: ${item.condition} • Cost: ${widget.school.currencySymbol}${item.cost.toStringAsFixed(2)}'),
                        trailing: Chip(
                          label: Text('Qty: ${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          backgroundColor: AppTheme.primaryLight,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddInventoryDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'IT Hardware');
    final qtyCtrl = TextEditingController(text: '1');
    final locCtrl = TextEditingController(text: 'Computer Lab 1');
    final costCtrl = TextEditingController(text: '450.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Campus Asset / Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name (e.g. Dell Core i5 Desktop, Chemistry Beakers)')),
            const SizedBox(height: 10),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category (IT, Furniture, Lab, Sports)')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Cost (${widget.school.currencySymbol})'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Physical Location / Room')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              final res = await SupabaseService.addInventoryAsset(
                schoolId: widget.school.id,
                itemName: nameCtrl.text,
                category: catCtrl.text,
                quantity: int.tryParse(qtyCtrl.text) ?? 1,
                location: locCtrl.text,
                cost: double.tryParse(costCtrl.text) ?? 0.0,
                purchaseDate: DateTime.now(),
              );
              _showFeedback(res['message'] ?? '', isSuccess: res['success'] == true);
              _loadAllModules();
            },
            child: const Text('Register Asset'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon, VoidCallback onAction, String actionLabel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
