import 'package:flutter/material.dart';

import '../../core/supa.dart';

/// عرض التسليم لأي من الطرفين.
Future<void> showDeliveryView(BuildContext context, String orderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _DeliveryView(orderId: orderId),
    ),
  );
}

class _DeliveryView extends StatefulWidget {
  final String orderId;
  const _DeliveryView({required this.orderId});

  @override
  State<_DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends State<_DeliveryView> {
  Map<String, dynamic>? _d;
  List<String> _urls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await supa
          .from('deliveries')
          .select()
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows as List);
      final urls = <String>[];
      if (list.isNotEmpty) {
        for (final p in List<String>.from(list.first['files'] as List)) {
          urls.add(await supa.storage.from('deliveries').createSignedUrl(p, 3600));
        }
      }
      if (!mounted) return;
      setState(() {
        _d = list.isEmpty ? null : list.first;
        _urls = urls;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : d == null
              ? const SizedBox(height: 120, child: Center(child: Text('لا يوجد تسليم')))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('التسليم',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if ((d['description'] as String?)?.isNotEmpty ?? false)
                        Text(d['description'] as String),
                      ...List<String>.from(d['links'] as List).map((l) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SelectableText(l,
                                style: const TextStyle(color: Colors.blue)),
                          )),
                      ..._urls.map((u) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(u, fit: BoxFit.cover),
                            ),
                          )),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }
}
