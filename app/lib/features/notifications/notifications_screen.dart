import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/posts_repo.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await supa
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _rows = asRows(data);
        _loading = false;
      });
      // تعليم غير المقروء كمقروء بعد عرضه
      await supa
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .isFilter('read_at', null);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_rows.isEmpty) {
      body = const Center(child: Text('لا إشعارات بعد', style: TextStyle(color: Colors.black54)));
    } else {
      body = ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (context, i) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final unread = r['read_at'] == null;
          final at = DateTime.tryParse('${r['created_at']}')?.toLocal();
          return ListTile(
            tileColor: unread ? AppColors.indigo.withAlpha(18) : null,
            leading: const Icon(Icons.notifications_active_outlined, color: AppColors.indigo),
            title: Text('${r['title']}',
                style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w600)),
            subtitle: Text('${r['body'] ?? ''}'),
            trailing: at == null
                ? null
                : Text(timeAgo(at),
                    style: const TextStyle(fontSize: 11, color: Colors.black45)),
          );
        },
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('الإشعارات')), body: body);
  }
}
