import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/audio_player_manager.dart';
import 'core/services/bilibili_api.dart';
import 'core/services/bilibili_service.dart';
import 'core/services/favorites_service.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'app/app.dart';

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
  final bilibiliService = BilibiliService(prefs);
  final audioPlayerManager = AudioPlayerManager();
  final favoritesService = FavoritesService(prefs);

  // 运行应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => bilibiliService),
        ChangeNotifierProvider(create: (_) => audioPlayerManager),
        ChangeNotifierProvider(create: (_) => favoritesService),
      ],
      child: const BilibiliMusicApp(),
    ),
  );
  configLoading();
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = Colors.green
    ..indicatorColor = Colors.yellow
    ..textColor = Colors.yellow
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = true
    ..dismissOnTap = false;
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
