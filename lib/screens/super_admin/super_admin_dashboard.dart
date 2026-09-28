import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../school_admin/admin_shell_screen.dart';
import '../auth/sign_in_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  List<SchoolModel> _schools = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.fetchSchools();
    setState(() {
      _schools = list;
      _isLoading = false;
    });
  }

  void _showAddSchoolDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: '\$');
    final admPrefixCtrl = TextEditingController(text: 'SCH-2026-');
    final recPrefixCtrl = TextEditingController(text: 'REC-2026-');
    final academicYearCtrl = TextEditingController(text: '2026-2027');
    final taglineCtrl = TextEditingController(text: 'Excellence in Academic Mastery');
    int studentLimit = 250;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.add_business, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Onboard New Institution (SaaS Tenant)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Basic School Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('School Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Saint Jude Academy')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('School Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: codeCtrl, decoration: const InputDecoration(hintText: 'e.g. SJA-2026')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Pricing Tier & Admission Quota Limit *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: studentLimit,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 100, child: Text('Starter Tier (100 Students Cap)')),
                        DropdownMenuItem(value: 250, child: Text('Standard Tier (250 Students Cap)')),
                        DropdownMenuItem(value: 600, child: Text('Growth Tier (600 Students Cap)')),
                        DropdownMenuItem(value: 1500, child: Text('Pro Tier (1,500 Students Cap)')),
                        DropdownMenuItem(value: 5000, child: Text('Enterprise Tier (5,000 Students Cap)')),
                      ],
                      onChanged: (val) => setDialogState(() => studentLimit = val ?? 250),
                    ),
                    const SizedBox(height: 16),
                    const Text('Branding & Regional Customization', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Currency Symbol', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: currencyCtrl, decoration: const InputDecoration(hintText: '\$, ₹, ₨, £, €')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Academic Session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: academicYearCtrl, decoration: const InputDecoration(hintText: '2026-2027')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admission No. Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: admPrefixCtrl, decoration: const InputDecoration(hintText: 'SCH-2026-')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fee Receipt Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: recPrefixCtrl, decoration: const InputDecoration(hintText: 'REC-2026-')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Motto / Tagline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(controller: taglineCtrl, decoration: const InputDecoration(hintText: 'Excellence in Academic Mastery')),
                    const SizedBox(height: 16),
                    const Text('Contact Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: '+1 555-0199')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'admin@school.edu')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Campus Physical Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(controller: addressCtrl, decoration: const InputDecoration(hintText: '104 Education Ave, City')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill mandatory school name and code.')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  final success = await SupabaseService.createSchool(
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim(),
                    maxStudents: studentLimit,
                    currencySymbol: currencyCtrl.text.trim(),
                    admissionPrefix: admPrefixCtrl.text.trim(),
                    receiptPrefix: recPrefixCtrl.text.trim(),
                    academicYear: academicYearCtrl.text.trim(),
                    tagline: taglineCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                  );
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('School onboarded and provisioned successfully!'), backgroundColor: AppTheme.success),
                    );
                    _fetchSchools();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to onboard school. Code may already exist.'), backgroundColor: AppTheme.danger),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Provision SaaS License'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showEditSchoolDialog(SchoolModel school) {
    final nameCtrl = TextEditingController(text: school.name);
    final codeCtrl = TextEditingController(text: school.code);
    final quotaCtrl = TextEditingController(text: school.maxStudents.toString());
    final currencyCtrl = TextEditingController(text: school.currencySymbol);
    final admPrefixCtrl = TextEditingController(text: school.admissionPrefix);
    final recPrefixCtrl = TextEditingController(text: school.receiptPrefix);
    final academicYearCtrl = TextEditingController(text: school.academicYear);
    final taglineCtrl = TextEditingController(text: school.tagline);
    final feeDueDayCtrl = TextEditingController(text: school.feeDueDay.toString());
    final phoneCtrl = TextEditingController(text: school.phone ?? '');
    final emailCtrl = TextEditingController(text: school.email ?? '');
    final addressCtrl = TextEditingController(text: school.address ?? '');
    bool isActive = school.isActive;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.tune, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Customize Tenant: ${school.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Subscription & Student Capacity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('School Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: nameCtrl),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('School Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: codeCtrl),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Student Quota Limit *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: quotaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(helperText: 'Hard ceiling on active students'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Fee Due Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: feeDueDayCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'e.g. 10'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Regional & Branding Customization', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Currency Symbol', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: currencyCtrl),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Academic Session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: academicYearCtrl),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admission Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: admPrefixCtrl),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Receipt Prefix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: recPrefixCtrl),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Motto / Tagline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(controller: taglineCtrl),
                    const SizedBox(height: 16),
                    const Text('Contact & License Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: phoneCtrl),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(controller: emailCtrl),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Campus Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(controller: addressCtrl),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('License Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(isActive ? 'School is active and operational' : 'School is suspended (portal access blocked)', style: const TextStyle(fontSize: 11)),
                      value: isActive,
                      activeColor: AppTheme.success,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () async {
                  final quota = int.tryParse(quotaCtrl.text) ?? school.maxStudents;
                  final feeDue = int.tryParse(feeDueDayCtrl.text) ?? school.feeDueDay;

                  Navigator.pop(context);
                  final res = await SupabaseService.updateSchool(
                    id: school.id,
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim(),
                    maxStudents: quota,
                    currencySymbol: currencyCtrl.text.trim(),
                    admissionPrefix: admPrefixCtrl.text.trim(),
                    receiptPrefix: recPrefixCtrl.text.trim(),
                    academicYear: academicYearCtrl.text.trim(),
                    tagline: taglineCtrl.text.trim(),
                    feeDueDay: feeDue,
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    isActive: isActive,
                  );
                  if (res['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('School customized and updated successfully!'), backgroundColor: AppTheme.success),
                    );
                    _fetchSchools();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update school configuration.'), backgroundColor: AppTheme.danger),
                    );
                  }
                },
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Customizations'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showDeleteConfirmation(SchoolModel school) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Institution?', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to permanently delete "${school.name}" (${school.code})?\n\nThis will remove all classes, student records, fee collections and attendance for this institution.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () async {
                Navigator.pop(context);
                final success = await SupabaseService.deleteSchool(school.id);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted institution ${school.name}')),
                  );
                  _fetchSchools();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete school.')),
                  );
                }
              },
              child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSchools = _schools.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.code.toLowerCase().contains(q);
    }).toList();

    final totalCapacity = _schools.fold<int>(0, (prev, s) => prev + s.maxStudents);
    final activeCount = _schools.where((s) => s.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.hub, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('ISKOOL Master SaaS Portal (Super Admin)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchSchools,
            tooltip: 'Refresh Institutes',
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
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Overview Cards
                  Row(
                    children: [
                      _buildMetricCard('Total Institutes', '${_schools.length}', Icons.business, AppTheme.primary),
                      const SizedBox(width: 16),
                      _buildMetricCard('Active Licenses', '$activeCount', Icons.check_circle, AppTheme.success),
                      const SizedBox(width: 16),
                      _buildMetricCard('Aggregated Quota Capacity', '$totalCapacity Seats', Icons.group, AppTheme.info),
                      const SizedBox(width: 16),
                      _buildMetricCard('Platform Est. MRR', '\$${_schools.length * 150}', Icons.payments, Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions & Table Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Institutions & Subscription Quotas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Customize tenant quotas, currency, prefixes, branding, or launch into admin workspace', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 240,
                            height: 38,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by name or code...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _showAddSchoolDialog,
                            icon: const Icon(Icons.add_business, size: 18),
                            label: const Text('Onboard School'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Schools Table
                  Expanded(
                    child: Card(
                      child: filteredSchools.isEmpty
                          ? const Center(
                              child: Text('No institutions found. Click "Onboard School" to create one.'),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Institution Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Student Quota', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Branding & Currency', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('License Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions & Admin Launch', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: filteredSchools.map((school) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: AppTheme.primaryLight,
                                              child: Text(
                                                school.name.isNotEmpty ? school.name.substring(0, 1).toUpperCase() : 'S',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(school.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                Text(school.tagline, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(school.code, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: AppTheme.surfaceSubtle, borderRadius: BorderRadius.circular(4)),
                                          child: Text('${school.maxStudents} Students Max', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ),
                                      DataCell(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Currency: ${school.currencySymbol} • Due: Day ${school.feeDueDay}', style: const TextStyle(fontSize: 11)),
                                            Text('${school.admissionPrefix} • ${school.receiptPrefix}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: school.isActive ? AppTheme.successLight : AppTheme.dangerLight,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            school.isActive ? 'Active' : 'Suspended',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: school.isActive ? AppTheme.success : AppTheme.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            // 1. Launch into School Admin Workspace directly!
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              ),
                                              icon: const Icon(Icons.open_in_new, size: 14),
                                              label: const Text('Open Admin', style: TextStyle(fontSize: 12)),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AdminShellScreen(school: school),
                                                  ),
                                                ).then((_) => _fetchSchools());
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            // 2. Customize School settings
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              icon: const Icon(Icons.tune, size: 14),
                                              label: const Text('Customize', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showEditSchoolDialog(school),
                                            ),
                                            const SizedBox(width: 4),
                                            // 3. Delete School
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                              onPressed: () => _showDeleteConfirmation(school),
                                              tooltip: 'Delete School',
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
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
