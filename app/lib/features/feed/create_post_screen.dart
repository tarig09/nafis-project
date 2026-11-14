import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _body = TextEditingController();
  final _tags = TextEditingController();
  String _type = 'general';
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<String> _parseTags() {
    final parts = _tags.text
        .split(RegExp(r'[#\s,،]+'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    return parts.length > 10 ? parts.sublist(0, 10) : parts;
  }

  Future<void> _publish() async {
    final body = _body.text.trim();
    final tags = _parseTags();
    if (body.isEmpty) return _toast('اكتب نص المنشور');
    if (tags.isEmpty) return _toast('أضف وسماً واحداً على الأقل مثل #تصميم');
    setState(() => _busy = true);
    try {
      await supa.from('posts').insert({
        'author_id': supa.auth.currentUser!.id,
        'type': _type,
        'body': body,
        'hashtags': tags,
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر النشر');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final special = Session.isClient
        ? const ButtonSegment<String>(value: 'request', label: Text('طلب خدمة'))
        : const ButtonSegment<String>(value: 'offer', label: Text('تقديم خدمة'));
    return Scaffold(
      appBar: AppBar(
        title: const Text('منشور جديد'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton(
              onPressed: _busy ? null : _publish,
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              child: const Text('نشر'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              const ButtonSegment<String>(value: 'general', label: Text('منشور عام')),
              special,
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            maxLines: 8,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'اكتب منشورك هنا...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              hintText: '#تصميم #برمجة',
              labelText: 'الوسوم (إلزامية)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ممنوع وضع أرقام هواتف أو روابط خارجية. المنشور العام للتفاعل فقط ولا بيع فيه.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
