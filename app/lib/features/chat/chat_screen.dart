import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/posts_repo.dart';
import 'order_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> other;
  const ChatScreen({super.key, required this.conversationId, required this.other});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  bool _sending = false;
  bool _otherTyping = false;
  bool _otherOnline = false;
  bool _following = false;
  Timer? _poll;
  Timer? _typingReset;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  // الدردشة الحية (Realtime) تعمل كتسريع فقط، والاستطلاع الدوري يضمن وصول الرسائل دائماً
  dynamic _channel;

  String get _me => supa.auth.currentUser!.id;
  String get _otherId => widget.other['id'] as String;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFollow();
    _setupRealtime();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refreshRecent());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _typingReset?.cancel();
    _input.dispose();
    try {
      supa.removeChannel(_channel);
    } catch (_) {}
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _merge(List<Map<String, dynamic>> rows) {
    final byId = {for (final m in _msgs) m['id'] as String: m};
    for (final r in rows) {
      byId[r['id'] as String] = r;
    }
    final list = byId.values.toList()
      ..sort((a, b) => DateTime.parse(a['created_at'] as String)
          .compareTo(DateTime.parse(b['created_at'] as String)));
    _msgs
      ..clear()
      ..addAll(list);
  }

  Future<void> _load() async {
    try {
      final rows = await supa
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _merge(asRows(rows));
        _loading = false;
      });
      _markSeen();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshRecent() async {
    try {
      final rows = await supa
          .from('messages')
          .select()
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: false)
          .limit(30);
      if (!mounted) return;
      setState(() => _merge(asRows(rows)));
      _markSeen();
    } catch (_) {}
  }

  Future<void> _markSeen() async {
    final unseen = _msgs.where((m) => m['sender_id'] != _me && m['seen_at'] == null);
    if (unseen.isEmpty) return;
    try {
      await supa.rpc('mark_conversation_seen', params: {'p_conv': widget.conversationId});
      final now = DateTime.now().toUtc().toIso8601String();
      for (final m in _msgs) {
        if (m['sender_id'] != _me && m['seen_at'] == null) m['seen_at'] = now;
      }
    } catch (_) {}
  }

  Future<void> _loadFollow() async {
    if (!AppSession.isFreelancer) return;
    try {
      final f = await supa
          .from('follows')
          .select()
          .eq('follower_id', _me)
          .eq('followee_id', _otherId)
          .maybeSingle();
      if (mounted) setState(() => _following = f != null);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    try {
      if (_following) {
        await supa
            .from('follows')
            .delete()
            .eq('follower_id', _me)
            .eq('followee_id', _otherId);
      } else {
        await supa.from('follows').insert({'follower_id': _me, 'followee_id': _otherId});
      }
      if (mounted) setState(() => _following = !_following);
    } catch (_) {
      _toast('تعذر تنفيذ العملية');
    }
  }

  void _setupRealtime() {
    try {
      final dynamic ch = supa.channel('chat:${widget.conversationId}');
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: widget.conversationId,
        ),
        callback: (payload) {
          final dynamic rec = payload.newRecord;
          if (!mounted || rec is! Map || rec.isEmpty) return;
          setState(() => _merge([Map<String, dynamic>.from(rec)]));
          _markSeen();
        },
      );
      ch.onBroadcast(
        event: 'typing',
        callback: (payload) {
          final dynamic p = payload;
          final dynamic inner = (p is Map && p['payload'] is Map) ? p['payload'] : p;
          if (inner is Map && inner['uid'] == _otherId && mounted) {
            setState(() => _otherTyping = true);
            _typingReset?.cancel();
            _typingReset = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _otherTyping = false);
            });
          }
        },
      );
      ch.onPresenceSync((payload) => _updatePresence());
      ch.subscribe((status, error) async {
        if (status.toString().contains('subscribed')) {
          await ch.track({'uid': _me});
        }
      });
      _channel = ch;
    } catch (_) {
      _channel = null;
    }
  }

  void _updatePresence() {
    try {
      final dynamic state = _channel.presenceState();
      final Iterable<dynamic> groups = state is Map ? state.values : state;
      var online = false;
      for (final dynamic g in groups) {
        final dynamic list = g is List ? g : g.presences;
        for (final dynamic p in list) {
          final dynamic pl = p is Map ? p : p.payload;
          if (pl is Map && pl['uid'] == _otherId) online = true;
        }
      }
      if (mounted) setState(() => _otherOnline = online);
    } catch (_) {}
  }

  void _onChanged(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
    _lastTypingSent = now;
    try {
      final dynamic f = _channel?.sendBroadcastMessage(event: 'typing', payload: {'uid': _me});
      if (f is Future) f.catchError((_) {});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final row = await supa
          .from('messages')
          .insert({
            'conversation_id': widget.conversationId,
            'sender_id': _me,
            'kind': 'text',
            'body': text,
          })
          .select()
          .single();
      _input.clear();
      if (!mounted) return;
      setState(() => _merge([Map<String, dynamic>.from(row)]));
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر إرسال الرسالة');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == _me;
    final t = DateTime.parse(m['created_at'] as String).toLocal();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final seen = m['seen_at'] != null;
    return Align(
      alignment:
          mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.indigo : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m['body'] as String,
                style: TextStyle(
                    color: mine ? Colors.white : AppColors.text, height: 1.5)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: TextStyle(
                        fontSize: 10,
                        color: mine ? Colors.white70 : Colors.black45)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(seen ? Icons.done_all : Icons.done,
                      size: 14,
                      color: seen ? const Color(0xFF86EFAC) : Colors.white70),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.other['photo_url'] as String?;
    final name = (widget.other['display_name'] as String?)?.trim() ?? '';
    final status = _otherTyping ? 'يكتب الآن...' : (_otherOnline ? 'متصل الآن' : '');
    final canRequest = AppSession.isClient && widget.other['role'] == 'freelancer';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null ? const Icon(Icons.person, size: 20) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name.isEmpty ? 'مستخدم' : name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (status.isNotEmpty)
                    Text(status,
                        style: const TextStyle(fontSize: 11, color: AppColors.green)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canRequest)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: FilledButton(
                onPressed: () async {
                  final ok = await showOrderSheet(context,
                      freelancerId: _otherId, conversationId: widget.conversationId);
                  if (ok == true) _toast('تم إنشاء الطلب، خطوة الدفع قادمة');
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                child: const Text('طلب الخدمة'),
              ),
            )
          else if (AppSession.isFreelancer)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: TextButton(
                onPressed: _toggleFollow,
                child: Text(_following ? 'إلغاء المتابعة' : 'متابعة'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _msgs.isEmpty
                    ? const Center(
                        child: Text('ابدأ المحادثة بكتابة رسالتك',
                            style: TextStyle(color: Colors.black54)))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: _msgs.length,
                        itemBuilder: (context, i) => _bubble(_msgs[_msgs.length - 1 - i]),
                      ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Text(
              'نص فقط. ممنوع الصور والروابط وأرقام الهواتف، حتى تبقى الصفقة آمنة داخل المنصة.',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onChanged: _onChanged,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      buildCounter: (context,
                              {required currentLength, required isFocused, maxLength}) =>
                          null,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: AppColors.indigo),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
