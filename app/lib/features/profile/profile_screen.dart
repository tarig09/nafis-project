import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/posts_repo.dart';
import '../../models/post.dart';
import '../../widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool embedded;
  const ProfileScreen({super.key, required this.userId, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _p;
  List<Post> _posts = [];
  bool _following = false;
  bool _loading = true;

  bool get _isMe => widget.userId == supa.auth.currentUser?.id;

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
      final p = await supa.from('profiles').select().eq('id', widget.userId).single();
      final rows = await supa
          .from('posts')
          .select()
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(50);
      final posts = await attachAuthors(asRows(rows));
      var following = false;
      if (!_isMe) {
        final f = await supa
            .from('follows')
            .select()
            .eq('follower_id', supa.auth.currentUser!.id)
            .eq('followee_id', widget.userId)
            .maybeSingle();
        following = f != null;
      }
      if (!mounted) return;
      setState(() {
        _p = Map<String, dynamic>.from(p);
        _posts = posts;
        _following = following;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final myId = supa.auth.currentUser!.id;
    try {
      if (_following) {
        await supa
            .from('follows')
            .delete()
            .eq('follower_id', myId)
            .eq('followee_id', widget.userId);
      } else {
        await supa
            .from('follows')
            .insert({'follower_id': myId, 'followee_id': widget.userId});
      }
      if (mounted) setState(() => _following = !_following);
    } catch (_) {
      _toast('تعذر تنفيذ العملية');
    }
  }

  Future<void> _editBio() async {
    final c = TextEditingController(text: (_p?['bio'] as String?) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('النبذة التعريفية'),
        content: TextField(controller: c, maxLines: 4, maxLength: 300),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supa
          .from('profiles')
          .update({'bio': c.text.trim()}).eq('id', widget.userId);
      await _load();
    } catch (_) {
      _toast('تعذر الحفظ');
    }
  }

  Widget _stars(double avg, int count) {
    final full = avg.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= full ? Icons.star : Icons.star_border,
              size: 18, color: AppColors.green),
        const SizedBox(width: 6),
        Text(count == 0 ? 'بلا تقييم' : '${avg.toStringAsFixed(1)} ($count)',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  Widget _verification(String v) {
    final map = {
      'verified': ['موثق', AppColors.indigo, Icons.verified],
      'pending': ['جاري التوثيق', Colors.orange, Icons.hourglass_bottom],
      'unverified': ['غير موثق', Colors.black45, Icons.remove_circle_outline],
    };
    final m = map[v] ?? map['unverified']!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(m[2] as IconData, size: 16, color: m[1] as Color),
      const SizedBox(width: 4),
      Text(m[0] as String, style: TextStyle(fontSize: 12, color: m[1] as Color)),
    ]);
  }

  List<Widget> _buttons(Map<String, dynamic> p) {
    if (_isMe) {
      return [OutlinedButton(onPressed: _editBio, child: const Text('تعديل النبذة'))];
    }
    return [
      FilledButton(
        onPressed: _toggleFollow,
        style: FilledButton.styleFrom(
            backgroundColor: _following ? Colors.black45 : AppColors.indigo),
        child: Text(_following ? 'إلغاء المتابعة' : 'متابعة'),
      ),
      if (p['role'] == 'freelancer' && Session.isClient) ...[
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => _toast('طلب الخدمة عبر الدردشة قريباً'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          child: const Text('طلب خدمة'),
        ),
      ],
    ];
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final p = _p;
    if (p == null) return const Center(child: Text('تعذر تحميل الملف الشخصي'));
    final photo = p['photo_url'] as String?;
    final name = (p['display_name'] as String?)?.trim() ?? '';
    final bio = (p['bio'] as String?)?.trim() ?? '';
    final isFreelancer = p['role'] == 'freelancer';
    final avg = ((p['rating_avg'] as num?) ?? 0).toDouble();
    final count = (p['rating_count'] as num?)?.toInt() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null ? const Icon(Icons.person, size: 40) : null,
              ),
              const Spacer(),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buttons(p),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(name.isEmpty ? 'مستخدم' : name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isFreelancer) _stars(avg, count),
              if (isFreelancer) _verification(p['verification'] as String? ?? 'unverified'),
              Text(isFreelancer ? 'مقدم خدمة' : 'طالب خدمة',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(bio, style: const TextStyle(height: 1.6)),
          ],
          const Divider(height: 32),
          const Text('المنشورات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('لا منشورات بعد')),
            )
          else
            ..._posts.map((e) => PostCard(post: e, linkAuthor: false)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _content();
    return Scaffold(appBar: AppBar(), body: _content());
  }
}
