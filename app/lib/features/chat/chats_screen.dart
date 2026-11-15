import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/posts_repo.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _error = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await supa.rpc('my_conversations');
      if (!mounted) return;
      setState(() {
        _rows = asRows(data);
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _open(Map<String, dynamic> r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: r['id'] as String,
          other: {
            'id': r['other_id'],
            'display_name': r['other_name'],
            'photo_url': r['other_photo'],
            'role': r['other_role'],
          },
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = supa.auth.currentUser?.id;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعذر تحميل المحادثات'),
          TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ]),
      );
    } else if (_rows.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'لا محادثات بعد.\nابدأ من ملف مقدم خدمة أو من أحد المنشورات.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.7),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _rows.length,
          separatorBuilder: (context, i) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = _rows[i];
            final unread = (r['unread'] as num?)?.toInt() ?? 0;
            final photo = r['other_photo'] as String?;
            final name = (r['other_name'] as String?)?.trim() ?? '';
            final mine = r['last_sender'] == me;
            final at = DateTime.tryParse('${r['last_at']}')?.toLocal();
            return ListTile(
              onTap: () => _open(r),
              leading: CircleAvatar(
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null ? const Icon(Icons.person) : null,
              ),
              title: Text(name.isEmpty ? 'مستخدم' : name,
                  style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600)),
              subtitle: Text(
                '${mine ? 'أنت: ' : ''}${r['last_body'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (at != null)
                    Text(timeAgo(at),
                        style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.indigo,
                      child: Text('$unread',
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('الرسائل')), body: body);
  }
}
