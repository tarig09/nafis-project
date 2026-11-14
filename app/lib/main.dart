import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Config.supabaseUrl.isEmpty || Config.supabaseKey.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Missing SUPABASE_URL / SUPABASE_KEY')),
      ),
    ));
    return;
  }
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseKey,
  );
  runApp(const NafisApp());
}

class NafisApp extends StatelessWidget {
  const NafisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نافس',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
