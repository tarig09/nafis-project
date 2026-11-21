import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session.dart';
import '../../core/supa.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _portfolio = TextEditingController();
  String? _photoUrl;
  bool _busy = false;
  bool _loaded = false;

  String get _me => supa.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _portfolio.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    try {
      final p = await supa.from('profiles').select().eq('id', _me).single();
      if (!mounted) return;
      setState(() {
        _name.text = (p['display_name'] as String?) ?? '';
        _portfolio.text = (p['portfolio_url'] as String?) ?? '';
        _photoUrl = p['photo_url'] as String?;
        _loaded = true;
      });
    } catch (_) {
      _toast('تعذر تحميل البيانات');
    }
  }

  Future<void> _pickPhoto() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      _toast('حجم الصورة أكبر من 2 ميغا');
      return;
    }
    final n = img.name.toLowerCase();
    final mime = n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    final ext = mime == 'image/png' ? 'png' : (mime == 'image/webp' ? 'webp' : 'jpg');
    setState(() => _busy = true);
    try {
      final path = '$_me/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supa.storage.from('post-images').uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true));
      final url = supa.storage.from('post-images').getPublicUrl(path);
      await supa.from('profiles').update({'photo_url': url}).eq('id', _me);
      if (!mounted) return;
      setState(() => _photoUrl = url);
      _toast('تم تحديث الصورة');
    } catch (_) {
      _toast('تعذر رفع الصورة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('الاسم مطلوب');
      return;
    }
    final link = _portfolio.text.trim();
    if (link.isNotEmpty && !link.startsWith('http://') && !link.startsWith('https://')) {
      _toast('رابط المعرض يجب أن يبدأ بـ http أو https');
      return;
    }
    setState(() => _busy = true);
    try {
      final data = <String, dynamic>{'display_name': name};
      if (AppSession.isFreelancer) data['portfolio_url'] = link.isEmpty ? null : link;
      await supa.from('profiles').update(data).eq('id', _me);
      if (AppSession.me != null) AppSession.me!['display_name'] = name;
      _toast(AppSession.isFreelancer && link.isNotEmpty
          ? 'تم الحفظ، رابط المعرض بانتظار موافقة الإدارة'
          : 'تم الحفظ');
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر الحفظ');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _busy ? null : _pickPhoto,
                      child: CircleAvatar(
                        radius: 44,
                        backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null ? const Icon(Icons.person, size: 40) : null,
                      ),
                    ),
                  ),
                  TextButton(
                      onPressed: _busy ? null : _pickPhoto, child: const Text('تغيير الصورة')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  if (AppSession.isFreelancer) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portfolio,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                          labelText: 'رابط معرض الأعمال (يحتاج موافقة الإدارة)'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? '...' : 'حفظ'),
                  ),
                ],
              ),
      ),
    );
  }
}
