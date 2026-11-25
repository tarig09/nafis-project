import 'package:flutter/material.dart';

import '../../core/supa.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  String _email = '';
  String _whatsapp = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await supa.from('app_settings').select();
      var e = '';
      var w = '';
      for (final r in (rows as List)) {
        if (r['key'] == 'contact_email') e = r['value'] as String;
        if (r['key'] == 'contact_whatsapp') w = r['value'] as String;
      }
      if (!mounted) return;
      setState(() {
        _email = e;
        _whatsapp = w;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = _email.isNotEmpty || _whatsapp.isNotEmpty;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (has) {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('البريد'),
              subtitle: SelectableText(_email, textDirection: TextDirection.ltr),
            ),
          if (_whatsapp.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('واتساب'),
              subtitle: SelectableText(_whatsapp, textDirection: TextDirection.ltr),
            ),
        ],
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'لإرسال ملاحظة أو شكوى استخدم «الشكاوى والمقترحات» من القائمة الجانبية.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(appBar: AppBar(title: const Text('تواصل معنا')), body: body),
    );
  }
}
