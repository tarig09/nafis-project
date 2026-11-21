import 'package:flutter/material.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  // عدّل هذه القيم ببيانات التواصل الرسمية للمنصة.
  static const email = '';
  static const whatsapp = '';

  @override
  Widget build(BuildContext context) {
    final has = email.isNotEmpty || whatsapp.isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تواصل معنا')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: has
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (email.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('البريد'),
                        subtitle: SelectableText(email, textDirection: TextDirection.ltr),
                      ),
                    if (whatsapp.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('واتساب'),
                        subtitle: SelectableText(whatsapp, textDirection: TextDirection.ltr),
                      ),
                  ],
                )
              : const Center(
                  child: Text(
                    'لإرسال ملاحظة أو شكوى استخدم «الشكاوى والمقترحات» من القائمة الجانبية.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }
}
