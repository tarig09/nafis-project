import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';

class _Pic {
  final String name;
  final Uint8List bytes;
  _Pic(this.name, this.bytes);
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _maxImages = 4;
  static const _maxBytes = 2 * 1024 * 1024;

  final _body = TextEditingController();
  final _tags = TextEditingController();
  final _picker = ImagePicker();
  final List<_Pic> _pics = [];
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

  String _mime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _ext(String mime) {
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    return 'jpg';
  }

  Future<void> _pick() async {
    final room = _maxImages - _pics.length;
    if (room <= 0) return _toast('الحد الأقصى $_maxImages صور');
    try {
      final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (files.isEmpty) return;
      final pics = <_Pic>[];
      var tooBig = 0;
      for (final f in files.take(room)) {
        final bytes = await f.readAsBytes();
        if (bytes.length > _maxBytes) {
          tooBig++;
          continue;
        }
        pics.add(_Pic(f.name, bytes));
      }
      if (!mounted) return;
      setState(() => _pics.addAll(pics));
      if (tooBig > 0) _toast('تم تجاهل $tooBig صورة لأنها أكبر من 2 ميغا');
      if (files.length > room) _toast('يمكن إضافة $room صور فقط');
    } catch (_) {
      _toast('تعذر اختيار الصور');
    }
  }

  Future<void> _cleanup(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await supa.storage.from('post-images').remove(paths);
    } catch (_) {}
  }

  Future<void> _publish() async {
    final body = _body.text.trim();
    final tags = _parseTags();
    if (body.isEmpty) return _toast('اكتب نص المنشور');
    if (tags.isEmpty) return _toast('أضف وسماً واحداً على الأقل مثل #تصميم');
    setState(() => _busy = true);
    final uploaded = <String>[];
    try {
      final uid = supa.auth.currentUser!.id;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final urls = <String>[];
      for (var i = 0; i < _pics.length; i++) {
        final mime = _mime(_pics[i].name);
        final path = '$uid/${stamp}_$i.${_ext(mime)}';
        await supa.storage.from('post-images').uploadBinary(
              path,
              _pics[i].bytes,
              fileOptions: FileOptions(contentType: mime),
            );
        uploaded.add(path);
        urls.add(supa.storage.from('post-images').getPublicUrl(path));
      }
      await supa.from('posts').insert({
        'author_id': uid,
        'type': _type,
        'body': body,
        'hashtags': tags,
        'images': urls,
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      await _cleanup(uploaded);
      _toast(e.message);
    } on StorageException catch (e) {
      await _cleanup(uploaded);
      _toast('تعذر رفع الصور: ${e.message}');
    } catch (_) {
      await _cleanup(uploaded);
      _toast('تعذر النشر');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final special = AppSession.isClient
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
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('نشر'),
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
            maxLines: 7,
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
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('إضافة صور (${_pics.length}/$_maxImages)'),
          ),
          if (_pics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _pics.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_pics[i].bytes,
                            width: 88, height: 88, fit: BoxFit.cover),
                      ),
                      PositionedDirectional(
                        top: 3,
                        end: 3,
                        child: GestureDetector(
                          onTap: _busy
                              ? null
                              : () => setState(() => _pics.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'صور فقط (بلا فيديو أو ملفات)، حتى 4 صور وبحد أقصى 2 ميغا للصورة. '
            'ممنوع ظهور أرقام هواتف أو روابط داخل الصور، وتُحذف المخالفات. '
            'المنشور العام للتفاعل فقط ولا بيع فيه.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
