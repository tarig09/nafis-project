import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import '../../data/posts_repo.dart';
import '../../widgets/logo.dart';
import '../chat/chats_screen.dart';
import '../feed/create_post_screen.dart';
import '../feed/feed_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/contact_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _feedKey = GlobalKey<FeedScreenState>();
  int _tab = 0;
  int _unreadMsgs = 0;
  int _unreadNotifs = 0;
  Timer? _timer;

  String get _uid => supa.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshCounts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    try {
      final convs = asRows(await supa.rpc('my_conversations'));
      final msgs = convs.fold<int>(0, (a, c) => a + ((c['unread'] as num?)?.toInt() ?? 0));
      final notifs = await supa
          .from('notifications')
          .select('id')
          .isFilter('read_at', null)
          .limit(99);
      if (!mounted) return;
      setState(() {
        _unreadMsgs = msgs;
        _unreadNotifs = (notifs as List).length;
      });
    } catch (_) {}
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _soon(String what) => _toast('$what قريباً');

  Future<void> _openChats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatsScreen()),
    );
    _refreshCounts();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refreshCounts();
  }

  Future<void> _compose() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (ok == true) {
      setState(() => _tab = 0);
      _feedKey.currentState?.refresh();
    }
  }

  Future<void> _feedback() async {
    final c = TextEditingController();
    var kind = 'suggestion';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('الشكاوى والمقترحات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('مقترح'),
                    selected: kind == 'suggestion',
                    onSelected: (_) => setS(() => kind = 'suggestion')),
                ChoiceChip(
                    label: const Text('شكوى'),
                    selected: kind == 'complaint',
                    onSelected: (_) => setS(() => kind = 'complaint')),
              ]),
              const SizedBox(height: 8),
              TextField(controller: c, maxLines: 4, maxLength: 500),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إرسال')),
          ],
        ),
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await supa.from('feedback').insert({
        'user_id': _uid,
        'kind': kind,
        'body': c.text.trim(),
      });
      _toast('تم الإرسال، شكراً لك');
    } catch (_) {
      _toast('تعذر الإرسال');
    }
  }

  Widget _item(IconData icon, String title, VoidCallback fn) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        fn();
      },
    );
  }

  Drawer _drawer() {
    return Drawer(
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(children: [NafisLogo(size: 30)]),
            ),
            const Divider(height: 1),
            _item(Icons.assignment_outlined, 'طلباتي', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
            _item(Icons.feedback_outlined, 'الشكاوى والمقترحات', _feedback),
            _item(Icons.settings_outlined, 'الإعدادات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            _item(Icons.call_outlined, 'تواصل معنا', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen()))),
            const Spacer(),
            const Divider(height: 1),
            _item(Icons.logout, 'تسجيل الخروج', () => supa.auth.signOut()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warned = AppSession.me?['status'] == 'warned';
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        toolbarHeight: 64,
        title: const NafisLogo(size: 26),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unreadNotifs > 0,
              label: Text('$_unreadNotifs'),
              child: const Icon(Icons.notifications_none, color: AppColors.indigo),
            ),
          ),
          IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.more_horiz, color: AppColors.indigo)),
        ],
      ),
      drawer: _drawer(),
      body: Stack(
        children: [
          Column(
            children: [
              if (warned)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEF3C7),
                  padding: const EdgeInsets.all(10),
                  child: const Text(
                    'تحذير رسمي: حسابك قيد المراجعة. يمكنك طلب مراجعة يدوية من الإدارة.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    FeedScreen(key: _feedKey),
                    ProfileScreen(userId: _uid, embedded: true),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            left: 40,
            child: FloatingActionButton.small(
              heroTag: null,
              onPressed: _openChats,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.indigo,
              elevation: 3,
              child: Badge(
                isLabelVisible: _unreadMsgs > 0,
                label: Text('$_unreadMsgs'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: () => setState(() => _tab = 0),
              icon: Icon(_tab == 0 ? Icons.home : Icons.home_outlined,
                  color: AppColors.indigo, size: 28),
            ),
            const SizedBox(width: 48),
            IconButton(
              onPressed: () => setState(() => _tab = 1),
              icon: Icon(_tab == 1 ? Icons.person : Icons.person_outline,
                  color: AppColors.indigo, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
