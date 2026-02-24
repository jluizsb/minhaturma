import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'config/router.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase requer GoogleService-Info.plist (iOS) / google-services.json (Android)
  // Será configurado quando o projeto Firebase for criado (passo 5)
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignora erro de inicialização em ambiente de desenvolvimento sem config Firebase
  }

  runApp(
    const ProviderScope(
      child: MinhaTurmaApp(),
    ),
  );
}

class MinhaTurmaApp extends ConsumerWidget {
  const MinhaTurmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
    );
  }
}
