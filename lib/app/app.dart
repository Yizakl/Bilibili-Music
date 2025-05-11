import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/bilibili_service.dart';
import '../core/services/audio_service.dart';
import '../core/router/app_router.dart';
import 'theme/app_theme.dart';

class BilibiliMusicApp extends StatefulWidget {
  final SharedPreferences prefs;

  const BilibiliMusicApp({super.key, required this.prefs});

  @override
  State<BilibiliMusicApp> createState() => _BilibiliMusicAppState();
}

class _BilibiliMusicAppState extends State<BilibiliMusicApp> {
  late final BilibiliService _bilibiliService;
  late final AudioPlayerService _audioPlayerService;
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();

    // 初始化服务
    _bilibiliService = BilibiliService();
    _audioPlayerService = AudioPlayerService();

    // 主题模式
    final savedThemeMode = widget.prefs.getString('theme_mode') ?? 'system';
    _themeMode = ValueNotifier<ThemeMode>(savedThemeMode == 'dark'
        ? ThemeMode.dark
        : savedThemeMode == 'light'
            ? ThemeMode.light
            : ThemeMode.system);

    // 初始化播放器
    _audioPlayerService.initialize();
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  void _changeThemeMode(ThemeMode mode) {
    _themeMode.value = mode;
    widget.prefs.setString(
        'theme_mode',
        mode == ThemeMode.dark
            ? 'dark'
            : mode == ThemeMode.light
                ? 'light'
                : 'system');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BilibiliService>(
          create: (_) => _bilibiliService,
        ),
        Provider<AudioPlayerService>.value(value: _audioPlayerService),
        Provider<SharedPreferences>.value(value: widget.prefs),
        Provider<Function(ThemeMode)>.value(value: _changeThemeMode),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeMode,
        builder: (context, themeMode, child) {
          return MaterialApp.router(
            title: 'Bilibili Music',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            debugShowCheckedModeBanner: false,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
