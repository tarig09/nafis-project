import 'package:flutter/material.dart';

import '../../core/supa.dart';
import 'chat_screen.dart';

/// يفتح (أو ينشئ) محادثة مع مستخدم ثم ينتقل إليها.
Future<void> openChatWith(BuildContext context, String otherId) async {
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  try {
    final id = await supa.rpc('start_conversation', params: {'other': otherId}) as String;
    final other = await supa
        .from('profiles')
        .select('id, display_name, photo_url, role')
        .eq('id', otherId)
        .single();
    nav.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: id,
        other: Map<String, dynamic>.from(other),
      ),
    ));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذر فتح المحادثة')));
  }
}
