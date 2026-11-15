import 'package:flutter/material.dart';

import '../../core/supa.dart';
import '../../core/theme.dart';

class RoleScreen extends StatefulWidget {
  final VoidCallback onDone;
  const RoleScreen({super.key, required this.onDone});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  bool _busy = false;

  Future<void> _choose(String role, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد: $label'),
        content: const Text('لا يمكن تغيير نوع الحساب بعد اختياره.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await supa
          .from('profiles')
          .update({'role': role}).eq('id', supa.auth.currentUser!.id);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حفظ الاختيار')));
      }
    }
  }

  Widget _card(IconData icon, String title, String sub, String role, Color c) {
    return InkWell(
      onTap: _busy ? null : () => _choose(role, title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: c),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(sub,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('مرحباً بك في نافس',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('اختر نوع حسابك للمتابعة',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 28),
              _card(Icons.handyman_outlined, 'مقدم خدمة',
                  'أعرض مهاراتي وأنفذ المشاريع', 'freelancer', AppColors.indigo),
              const SizedBox(height: 14),
              _card(Icons.work_outline, 'طالب خدمة',
                  'أبحث عن مستقل لتنفيذ مشروعي', 'client', AppColors.green),
              const Spacer(),
              Center(
                child: TextButton(
                    onPressed: () => supa.auth.signOut(),
                    child: const Text('تسجيل الخروج')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 56, color: AppColors.red),
              const SizedBox(height: 16),
              const Text('تم حظر هذا الحساب',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('للاستفسار تواصل مع إدارة المنصة.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              OutlinedButton(
                  onPressed: () => supa.auth.signOut(),
                  child: const Text('تسجيل الخروج')),
            ],
          ),
        ),
      ),
    );
  }
}
