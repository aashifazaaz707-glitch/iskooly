import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'screens/auth/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Multi-Tenant Connection
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const IskoolApp());
}

class IskoolApp extends StatelessWidget {
  const IskoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISKOOL — Intelligent School Operating System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SignInScreen(),
    );
  }
}
