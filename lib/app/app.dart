import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/bilibili_service.dart';
import '../core/services/audio_service.dart';
import '../core/router/app_router.dart';
import 'theme/app_theme.dart';

class BilibiliMusicApp extends StatelessWidget {
  const BilibiliMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bilibili Music',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
