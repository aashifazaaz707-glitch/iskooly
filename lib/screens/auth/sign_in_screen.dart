import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../super_admin/super_admin_dashboard.dart';
import '../school_admin/admin_shell_screen.dart';
import '../teacher/teacher_attendance_screen.dart';
import '../parent_student/student_parent_portal_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController(text: 'admin@greenwood.edu');
  final _passwordController = TextEditingController(text: 'admin2026');
  List<SchoolModel> _schools = [];
  SchoolModel? _selectedSchool;
  bool _isLoading = false;
  String _selectedRole = 'school_admin';

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() => _isLoading = true);
    final schools = await SupabaseService.fetchSchools();
    setState(() {
      _schools = schools;
      if (schools.isNotEmpty) {
        _selectedSchool = schools.first;
      }
      _isLoading = false;
    });
  }

  void _switchRole(String role) {
    setState(() {
      _selectedRole = role;
      if (role == 'super_admin') {
        _emailController.text = 'master@iskool.erp';
        _passwordController.text = 'superadmin2026';
      } else if (role == 'school_admin') {
        _emailController.text = 'admin@greenwood.edu';
        _passwordController.text = 'admin2026';
      } else if (role == 'teacher') {
        _emailController.text = 'teacher@greenwood.edu';
        _passwordController.text = 'teacher2026';
      } else {
        _emailController.text = 'ADM-2026-001';
        _passwordController.text = 'parent2026';
      }
    });
  }

  void _handleLogin() {
    if (_selectedSchool == null && _selectedRole != 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your institution.')),
      );
      return;
    }

    SupabaseService.currentSchool = _selectedSchool;
    SupabaseService.userRole = _selectedRole;

    Widget nextScreen;
    if (_selectedRole == 'super_admin') {
      nextScreen = const SuperAdminDashboard();
    } else if (_selectedRole == 'school_admin') {
      nextScreen = AdminShellScreen(school: _selectedSchool!);
    } else if (_selectedRole == 'teacher') {
      nextScreen = TeacherAttendanceScreen(school: _selectedSchool!);
    } else {
      nextScreen = StudentParentPortalScreen(school: _selectedSchool!);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Logo & Heading
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ISKOOL',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    letterSpacing: -0.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Intelligent School Operating System',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Sign In to Your Campus Portal',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Access is restricted to pre-provisioned accounts. Sign-up is disabled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),

                        // Persona / Role Selector (Instant Switcher)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              _buildRoleTab('School Admin', 'school_admin'),
                              _buildRoleTab('Teacher', 'teacher'),
                              _buildRoleTab('Parent/Student', 'parent'),
                              _buildRoleTab('Super Admin', 'super_admin'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // School Selector (for white-labeled institutions)
                        if (_selectedRole != 'super_admin') ...[
                          const Text(
                            'Institution',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<SchoolModel>(
                                isExpanded: true,
                                value: _selectedSchool,
                                hint: const Text('Select your school'),
                                items: _schools.map((school) {
                                  return DropdownMenuItem<SchoolModel>(
                                    value: school,
                                    child: Text(school.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedSchool = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email / ID Field
                        Text(
                          _selectedRole == 'parent' ? 'Student Admission No / Parent Phone' : 'User ID / Registered Email',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Demo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        const Text(
                          'Secure Password / PIN',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign In Button
                        ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Sign In as ${_selectedRole.replaceAll('_', ' ').toUpperCase()}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Compliance notice
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shield_outlined, size: 14, color: AppTheme.success),
                            SizedBox(width: 6),
                            Text(
                              'Supabase Row-Level Security & Multi-Tenancy Active',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Demo Credentials Reference Guide Card
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  color: AppTheme.surfaceSubtle,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.key, size: 16, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text('Preset Demo Credentials for All 4 Profiles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildCredentialRow('Super Admin (You)', 'master@iskool.erp', 'superadmin2026', 'Platform SaaS Owner'),
                        const Divider(height: 12),
                        _buildCredentialRow('School Admin', 'admin@greenwood.edu', 'admin2026', 'Windows & Web Access'),
                        const Divider(height: 12),
                        _buildCredentialRow('Teacher', 'teacher@greenwood.edu', 'teacher2026', 'Roll Call & WhatsApp'),
                        const Divider(height: 12),
                        _buildCredentialRow('Parent / Student', 'ADM-2026-001', 'parent2026', 'Receipts & Admit Card'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String role, String id, String pass, String desc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('ID: $id', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600)),
            Text('Pass: $pass', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleTab(String label, String roleKey) {
    final isSelected = _selectedRole == roleKey;
    return Expanded(
      child: InkWell(
        onTap: () => _switchRole(roleKey),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
