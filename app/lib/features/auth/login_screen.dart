import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/supa.dart';
import '../../widgets/logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  // فعّلها (true) بعد تفعيل Google في Supabase
  final bool _googleEnabled = false;
  bool _busy = false;
  bool _signup = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _arabicError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة';
    if (m.contains('already registered')) return 'هذا البريد مسجل مسبقاً';
    if (m.contains('not confirmed')) return 'البريد لم يؤكد بعد';
    if (m.contains('password')) return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
    if (m.contains('valid email') || m.contains('invalid email')) {
      return 'صيغة البريد غير صحيحة';
    }
    return 'تعذر تنفيذ العملية';
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) return _toast('أدخل البريد وكلمة المرور');
    if (_signup && _name.text.trim().isEmpty) return _toast('أدخل اسمك');
    if (_signup && pass.length < 6) {
      return _toast('كلمة المرور 6 أحرف على الأقل');
    }
    setState(() => _busy = true);
    try {
      if (_signup) {
        final res = await supa.auth.signUp(
          email: email,
          password: pass,
          data: {'full_name': _name.text.trim()},
        );
        if (res.session == null) {
          _toast('تم إنشاء الحساب. إن لم تدخل تلقائياً فسجّل الدخول');
        }
      } else {
        await supa.auth.signInWithPassword(email: email, password: pass);
      }
    } on AuthException catch (e) {
      _toast(_arabicError(e.message));
    } catch (_) {
      _toast('تعذر الاتصال، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await supa.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Config.redirect,
      );
    } catch (_) {
      _toast('تعذر تسجيل الدخول بجوجل');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: NafisLogo(size: 56)),
                const SizedBox(height: 12),
                const Text('منصة سودانية للتواصل وسوق العمل الحر',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 32),
                if (_signup) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_signup ? 'إنشاء حساب' : 'تسجيل الدخول'),
                  ),
                ),
                TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _signup = !_signup),
                  child: Text(_signup
                      ? 'لدي حساب بالفعل'
                      : 'ليس لدي حساب؟ إنشاء حساب جديد'),
                ),
                if (_googleEnabled) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.login),
                    label: const Text('الدخول بحساب Google'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('للأفراد والفرق فقط. لا تسجيل للشركات.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
