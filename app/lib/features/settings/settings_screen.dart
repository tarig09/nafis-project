import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../verification/verification_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = supa.auth.currentUser?.email ?? '';
    final role = AppSession.isFreelancer ? 'مقدم خدمة' : (AppSession.isClient ? 'طالب خدمة' : '');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('تعديل الملف الشخصي'),
              subtitle: const Text('الاسم والصورة ورابط المعرض'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            ),
            if (AppSession.isFreelancer)
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('توثيق الحساب'),
                subtitle: const Text('أرسل نماذج أعمالك للمراجعة'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const VerificationScreen())),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('البريد الإلكتروني'),
              subtitle: Text(email, textDirection: TextDirection.ltr),
            ),
            if (role.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('نوع الحساب'),
                subtitle: Text(role),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.pop(context);
                supa.auth.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
