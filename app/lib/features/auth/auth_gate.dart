import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../home/home_shell.dart';
import 'auth_screens.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supa.auth.onAuthStateChange,
      builder: (context, snap) {
        final session = supa.auth.currentSession;
        if (session == null) {
          Session.me = null;
          return const LoginScreen();
        }
        return ProfileGate(key: ValueKey(session.user.id));
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final p = await supa
        .from('profiles')
        .select()
        .eq('id', supa.auth.currentUser!.id)
        .single();
    return Map<String, dynamic>.from(p);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر تحميل حسابك'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                  TextButton(
                      onPressed: () => supa.auth.signOut(),
                      child: const Text('تسجيل الخروج')),
                ],
              ),
            ),
          );
        }
        final p = snap.data!;
        Session.me = p;
        if (p['status'] == 'banned') return const BannedScreen();
        if (p['role'] == null) return RoleScreen(onDone: _reload);
        return const HomeShell();
      },
    );
  }
}
