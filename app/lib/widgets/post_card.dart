import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/supa.dart';
import '../core/theme.dart';
import '../features/chat/open_chat.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/report_dialog.dart';
import '../models/post.dart';
import 'post_images.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool linkAuthor;
  final VoidCallback? onDeleted;
  const PostCard(
      {super.key, required this.post, this.linkAuthor = true, this.onDeleted});

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: post.body);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل المنشور'),
          content: TextField(controller: ctrl, maxLines: 6, maxLength: 1000),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || text == post.body) return;
    try {
      await supa.rpc('edit_post', params: {'p_post': post.id, 'p_body': text});
      onDeleted?.call();
    } on PostgrestException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر تعديل المنشور')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المنشور؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await supa.from('posts').delete().eq('id', post.id);
      onDeleted?.call();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حذف المنشور')));
      }
    }
  }

  static const _labels = {
    'general': 'عام',
    'request': 'طلب خدمة',
    'offer': 'تقديم خدمة',
    'awareness': 'توعية',
  };

  Color _color(String t) {
    switch (t) {
      case 'request':
        return AppColors.green;
      case 'offer':
        return AppColors.indigo;
      case 'awareness':
        return Colors.black87;
      default:
        return Colors.black45;
    }
  }

  bool get _canContact {
    final me = supa.auth.currentUser?.id;
    if (me == null || me == post.authorId) return false;
    if (post.type == 'request') return AppSession.isFreelancer;
    if (post.type == 'offer') return AppSession.isClient;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final name = (a?['display_name'] as String?)?.trim();
    final photo = a?['photo_url'] as String?;
    final verified = a?['verification'] == 'verified';
    final c = _color(post.type);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: linkAuthor
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: post.authorId)))
                : null,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            (name != null && name.isNotEmpty) ? name : 'مستخدم',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (verified)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 4),
                            child: Icon(Icons.verified,
                                size: 16, color: AppColors.indigo),
                          ),
                      ]),
                      Text(timeAgo(post.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_labels[post.type] ?? post.type,
                      style: TextStyle(
                          fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') {
                      _delete(context);
                    } else if (v == 'edit') {
                      _edit(context);
                    } else {
                      showReportDialog(context, targetId: post.authorId, postId: post.id);
                    }
                  },
                  itemBuilder: (_) => supa.auth.currentUser?.id == post.authorId
                      ? const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل المنشور')),
                          PopupMenuItem(value: 'delete', child: Text('حذف المنشور')),
                        ]
                      : const [
                          PopupMenuItem(value: 'report', child: Text('إبلاغ عن المنشور')),
                        ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(post.body, style: const TextStyle(height: 1.6)),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            PostImages(urls: post.images),
          ],
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: post.hashtags
                  .map((h) => Text('#$h',
                      style: const TextStyle(
                          color: AppColors.indigo, fontSize: 13)))
                  .toList(),
            ),
          ],
          if (_canContact) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => openChatWith(context, post.authorId),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(post.type == 'request'
                    ? 'تواصل مع طالب الخدمة'
                    : 'تواصل مع مقدم الخدمة'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
