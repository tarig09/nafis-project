import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supa.dart';

/// إبلاغ عن مستخدم، أو عن منشور إذا مُرّر postId.
Future<void> showReportDialog(BuildContext context,
    {required String targetId, String? postId}) async {
  String cat = 'community';
  final ctrl = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(postId == null ? 'الإبلاغ عن مستخدم' : 'الإبلاغ عن منشور'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'sexual',
                groupValue: cat,
                onChanged: (v) => setS(() => cat = v!),
                title: const Text('محتوى جنسي'),
              ),
              RadioListTile<String>(
                value: 'community',
                groupValue: cat,
                onChanged: (v) => setS(() => cat = v!),
                title: const Text('مخالفة قواعد المجتمع'),
              ),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'تفاصيل (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
          ],
        ),
      ),
    ),
  );
  final details = ctrl.text.trim();
  ctrl.dispose();
  if (send != true) return;
  String msg;
  try {
    await supa.from('reports').insert({
      'reporter_id': supa.auth.currentUser!.id,
      'target_id': targetId,
      'category': cat,
      'details': postId == null ? details : 'منشور: $postId\n$details',
    });
    msg = 'تم إرسال البلاغ، شكراً لك';
  } on PostgrestException catch (e) {
    msg = e.message;
  } catch (_) {
    msg = 'تعذر إرسال البلاغ';
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
