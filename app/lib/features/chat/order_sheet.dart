import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/fees.dart';
import '../../core/supa.dart';
import '../../core/theme.dart';

/// نموذج طلب الخدمة (للعميل). يعيد true عند إنشاء الطلب.
Future<bool?> showOrderSheet(BuildContext context,
    {required String freelancerId, required String conversationId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _OrderSheet(freelancerId: freelancerId, conversationId: conversationId),
    ),
  );
}

class _OrderSheet extends StatefulWidget {
  final String freelancerId;
  final String conversationId;
  const _OrderSheet({required this.freelancerId, required this.conversationId});

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  final _type = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _type.dispose();
    _desc.dispose();
    _price.dispose();
    _days.dispose();
    super.dispose();
  }

  double? get _priceVal => double.tryParse(_price.text.trim());

  Future<void> _submit() async {
    final price = _priceVal;
    final days = int.tryParse(_days.text.trim());
    if (_type.text.trim().isEmpty ||
        _desc.text.trim().isEmpty ||
        price == null ||
        price <= 0 ||
        days == null ||
        days <= 0) {
      setState(() => _error = 'أكمل كل الحقول بقيم صحيحة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supa.rpc('create_order', params: {
        'p_freelancer': widget.freelancerId,
        'p_conv': widget.conversationId,
        'p_type': _type.text.trim(),
        'p_desc': _desc.text.trim(),
        'p_price': price,
        'p_days': days,
      });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذر إنشاء الطلب');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _priceVal;
    final a = (p != null && p > 0) ? calcAmounts(p) : null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('طلب خدمة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
                controller: _type,
                decoration: const InputDecoration(labelText: 'نوع الخدمة')),
            const SizedBox(height: 8),
            TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف المطلوب')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'السعر (جنيه)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المدة (أيام)'),
                ),
              ),
            ]),
            if (a != null) ...[
              const SizedBox(height: 10),
              Text('عمولة العميل 5%: ${a.feeEach.toStringAsFixed(2)}\n'
                  'الإجمالي الذي ستدفعه: ${a.clientTotal.toStringAsFixed(2)}'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              child: Text(_busy ? '...' : 'إنشاء الطلب'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
