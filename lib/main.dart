import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pgbxuhxgailvjrfihnlm.supabase.co',
    anonKey: 'sb_publishable_5eGf2Hl0JyQ18FkBgU-81A_mw_i7PzP',
  );
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TransPayy',
      home: AuthRedirector(),
    );
  }
}

class AuthRedirector extends StatelessWidget {
  const AuthRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const HomeScreen() : const LoginScreen();
  }
}
