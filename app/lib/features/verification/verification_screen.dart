import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supa.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<XFile> _images = [];
  String? _status; // pending / approved / rejected / null
  bool _loading = true;
  bool _busy = false;

  String get _me => supa.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    try {
      final rows = await supa
          .from('verification_requests')
          .select('status')
          .eq('user_id', _me)
          .order('created_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (!mounted) return;
      setState(() {
        _status = list.isEmpty ? null : list.first['status'] as String;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (files.isEmpty) return;
    setState(() {
      _images.addAll(files);
      if (_images.length > 5) _images.removeRange(5, _images.length);
    });
  }

  Future<void> _submit() async {
    if (_images.length < 2) {
      _toast('أرفق نموذجين على الأقل من أعمالك');
      return;
    }
    setState(() => _busy = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final paths = <String>[];
      for (var i = 0; i < _images.length; i++) {
        final bytes = await _images[i].readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) {
          _toast('حجم إحدى الصور أكبر من 2 ميغا');
          setState(() => _busy = false);
          return;
        }
        final n = _images[i].name.toLowerCase();
        final mime = n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        final ext = mime == 'image/png' ? 'png' : (mime == 'image/webp' ? 'webp' : 'jpg');
        final path = '$_me/${stamp}_$i.$ext';
        await supa.storage.from('verification-samples').uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: mime));
        paths.add(path);
      }
      await supa.from('verification_requests').insert({'user_id': _me, 'samples': paths});
      _images.clear();
      _toast('تم إرسال الطلب للمراجعة');
      await _load();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر إرسال الطلب');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_status == 'pending') {
      body = const Center(child: Text('طلبك قيد المراجعة من الإدارة.'));
    } else if (_status == 'approved') {
      body = const Center(child: Text('حسابك موثق ✅'));
    } else {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status == 'rejected')
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('تم رفض الطلب السابق، يمكنك إرسال طلب جديد بنماذج أخرى.'),
            ),
          const Text('أرفق من 2 إلى 5 صور لنماذج من أعمالك السابقة ليراجعها فريق الإدارة.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.image_outlined),
            label: Text(_images.isEmpty ? 'اختيار الصور' : 'تم اختيار ${_images.length} صورة'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? '...' : 'إرسال طلب التوثيق'),
          ),
        ],
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(appBar: AppBar(title: const Text('توثيق الحساب')), body: body),
    );
  }
}
