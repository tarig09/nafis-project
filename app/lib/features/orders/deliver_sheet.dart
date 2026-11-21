import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supa.dart';
import '../../core/theme.dart';

/// نافذة التسليم (للمستقل). تعيد true عند نجاح التسليم.
Future<bool?> showDeliverSheet(BuildContext context, String orderId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _DeliverSheet(orderId: orderId),
    ),
  );
}

class _DeliverSheet extends StatefulWidget {
  final String orderId;
  const _DeliverSheet({required this.orderId});

  @override
  State<_DeliverSheet> createState() => _DeliverSheetState();
}

class _DeliverSheetState extends State<_DeliverSheet> {
  final _desc = TextEditingController();
  final List<TextEditingController> _links = [TextEditingController()];
  final List<XFile> _images = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _desc.dispose();
    for (final c in _links) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1800);
    if (files.isEmpty) return;
    setState(() {
      _images.addAll(files);
      if (_images.length > 6) _images.removeRange(6, _images.length);
    });
  }

  String _mime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    final links = _links.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (_desc.text.trim().isEmpty && links.isEmpty && _images.isEmpty) {
      setState(() => _error = 'أضف وصفاً أو رابطاً أو صورة');
      return;
    }
    for (final l in links) {
      if (!l.startsWith('http://') && !l.startsWith('https://')) {
        setState(() => _error = 'الرابط يجب أن يبدأ بـ http أو https');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = supa.auth.currentUser!.id;
      final paths = <String>[];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < _images.length; i++) {
        final bytes = await _images[i].readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw 'حجم إحدى الصور أكبر من 5 ميغا';
        }
        final mime = _mime(_images[i].name);
        final ext = mime == 'image/png' ? 'png' : (mime == 'image/webp' ? 'webp' : 'jpg');
        final path = '$me/${widget.orderId}/${stamp}_$i.$ext';
        await supa.storage.from('deliveries').uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true));
        paths.add(path);
      }
      await supa.rpc('deliver_order', params: {
        'p_order': widget.orderId,
        'p_desc': _desc.text.trim(),
        'p_links': links,
        'p_files': paths,
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } on String catch (m) {
      setState(() => _error = m);
    } catch (_) {
      setState(() => _error = 'تعذر التسليم، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تسليم الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف التسليم')),
            const SizedBox(height: 8),
            ..._links.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextField(
                    controller: c,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'رابط (اختياري)'),
                  ),
                )),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _links.length >= 5
                    ? null
                    : () => setState(() => _links.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('إضافة رابط'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.image_outlined),
              label: Text(_images.isEmpty ? 'إرفاق صور' : 'تم اختيار ${_images.length} صورة'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              child: Text(_busy ? '...' : 'تسليم'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
