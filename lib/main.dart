import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/audio_player_manager.dart';
import 'core/services/bilibili_api.dart';
import 'core/services/bilibili_service.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化后台音频服务
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.bilibili_music.channel.audio',
    androidNotificationChannelName: 'Bilibili Music',
    androidNotificationOngoing: true,
  );

  // 获取SharedPreferences实例
  final prefs = await SharedPreferences.getInstance();

  // 初始化服务
  final bilibiliApi = BilibiliApi(prefs);
  final authService = AuthService(prefs, bilibiliApi);
  final bilibiliService = BilibiliService();
  final audioPlayerManager = AudioPlayerManager();

  // 运行应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authService),
        Provider(create: (_) => bilibiliService),
        ChangeNotifierProvider(create: (_) => audioPlayerManager),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
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
