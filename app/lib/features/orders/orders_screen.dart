import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/session.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';
import 'deliver_sheet.dart';
import 'delivery_view.dart';

const _stateLabels = {
  'awaiting_payment': 'بانتظار الدفع',
  'payment_review': 'الدفع قيد المراجعة',
  'pending_accept': 'بانتظار موافقة مقدم الخدمة',
  'in_progress': 'قيد التنفيذ',
  'delivered': 'تم التسليم',
  'completed': 'مكتمل',
  'disputed': 'قيد التحكيم',
  'refunded': 'مُسترد',
};

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _busyId;

  String get _me => supa.auth.currentUser!.id;

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
      final rows = await supa
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('تعذر تحميل الطلبات');
    }
  }

  Future<void> _uploadProof(Map<String, dynamic> o) async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      _toast('حجم الصورة أكبر من 2 ميغا');
      return;
    }
    final name = img.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    final ext = mime == 'image/png' ? 'png' : (mime == 'image/webp' ? 'webp' : 'jpg');
    final path = '$_me/${o['id']}.$ext';
    setState(() => _busyId = o['id'] as String);
    try {
      await supa.storage.from('payment-proofs').uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true));
      await supa.rpc('submit_payment_proof', params: {'p_order': o['id'], 'p_path': path});
      _toast('تم رفع الإثبات وهو قيد المراجعة');
      await _load();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر رفع الإثبات');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _respond(Map<String, dynamic> o, bool accept) async {
    setState(() => _busyId = o['id'] as String);
    try {
      await supa.rpc('freelancer_respond', params: {'p_order': o['id'], 'p_accept': accept});
      await _load();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر تنفيذ العملية');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deliver(Map<String, dynamic> o) async {
    final ok = await showDeliverSheet(context, o['id'] as String);
    if (ok == true) {
      _toast('تم التسليم، بانتظار قبول العميل');
      await _load();
    }
  }

  Future<void> _accept(Map<String, dynamic> o) async {
    setState(() => _busyId = o['id'] as String);
    try {
      await supa.rpc('client_accept_delivery', params: {'p_order': o['id']});
      _toast('تم قبول التسليم');
      await _load();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر تنفيذ العملية');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _dispute(Map<String, dynamic> o) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('شكوى تسليم'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'اشرح المشكلة'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (reason == null || reason.isEmpty) return;
    setState(() => _busyId = o['id'] as String);
    try {
      await supa.rpc('open_dispute', params: {'p_order': o['id'], 'p_reason': reason});
      _toast('تم رفع الشكوى للإدارة');
      await _load();
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذر تنفيذ العملية');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _remaining(Map<String, dynamic> o) {
    final due = DateTime.tryParse('${o['due_at']}');
    if (due == null) return '';
    final left = due.difference(DateTime.now());
    if (left.isNegative) return 'انتهت المدة';
    if (left.inDays >= 1) return 'متبقي ${left.inDays} يوم و${left.inHours % 24} ساعة';
    return 'متبقي ${left.inHours} ساعة و${left.inMinutes % 60} دقيقة';
  }

  List<Map<String, dynamic>> _filter(List<String> states) =>
      _orders.where((o) => states.contains(o['state'])).toList();

  Widget _list(List<Map<String, dynamic>> items) {
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('لا توجد طلبات هنا')),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: items.map(_card).toList(),
            ),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final state = o['state'] as String;
    final isClient = o['client_id'] == _me;
    final busy = _busyId == o['id'];
    final amount = isClient ? o['client_total'] : o['freelancer_net'];
    final actions = <Widget>[];
    if (isClient && state == 'awaiting_payment') {
      actions.add(FilledButton(
        onPressed: busy ? null : () => _uploadProof(o),
        child: Text(busy ? '...' : 'رفع إثبات التحويل'),
      ));
    }
    if (!isClient && state == 'pending_accept') {
      actions.add(FilledButton(
        onPressed: busy ? null : () => _respond(o, true),
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        child: const Text('قبول'),
      ));
      actions.add(const SizedBox(width: 8));
      actions.add(OutlinedButton(
        onPressed: busy ? null : () => _respond(o, false),
        child: const Text('رفض'),
      ));
    }
    if (!isClient && state == 'in_progress') {
      actions.add(FilledButton(
        onPressed: busy ? null : () => _deliver(o),
        child: const Text('تسليم'),
      ));
    }
    if (state == 'delivered' || state == 'completed' || state == 'disputed') {
      actions.add(OutlinedButton(
        onPressed: () => showDeliveryView(context, o['id'] as String),
        child: const Text('عرض التسليم'),
      ));
    }
    if (isClient && state == 'delivered') {
      actions.add(const SizedBox(width: 8));
      actions.add(FilledButton(
        onPressed: busy ? null : () => _accept(o),
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        child: const Text('قبول'),
      ));
      actions.add(const SizedBox(width: 8));
      actions.add(OutlinedButton(
        onPressed: busy ? null : () => _dispute(o),
        child: const Text('شكوى'),
      ));
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o['service_type'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(o['description'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('${isClient ? 'المبلغ المطلوب' : 'صافي ربحك'}: $amount  •  المدة: ${o['duration_days']} يوم'),
            const SizedBox(height: 4),
            Text(_stateLabels[state] ?? state,
                style: const TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600)),
            if (state == 'in_progress')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_remaining(o), style: const TextStyle(color: AppColors.red)),
              ),
            if (state == 'delivered')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('يُحوَّل المبلغ تلقائياً بعد 24 ساعة إن لم يُعترض.',
                    style: TextStyle(fontSize: 12)),
              ),
            if (isClient && state == 'awaiting_payment')
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('حوّل المبلغ عبر بنكك ثم ارفع صورة الإثبات.',
                    style: TextStyle(fontSize: 12)),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 4, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClient = AppSession.isClient;
    final tabs = isClient
        ? const ['جارية', 'مكتملة']
        : const ['جديدة', 'قيد التنفيذ', 'مكتملة'];
    final views = isClient
        ? [
            _list(_filter(const [
              'awaiting_payment', 'payment_review', 'pending_accept',
              'in_progress', 'delivered', 'disputed'
            ])),
            _list(_filter(const ['completed', 'refunded'])),
          ]
        : [
            _list(_filter(const ['pending_accept'])),
            _list(_filter(const ['in_progress', 'delivered', 'disputed'])),
            _list(_filter(const ['completed', 'refunded'])),
          ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي'),
          bottom: TabBar(tabs: tabs.map((t) => Tab(text: t)).toList()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: views),
      ),
    );
  }
}
