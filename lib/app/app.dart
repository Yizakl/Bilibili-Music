import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/bilibili_service.dart';
import '../core/services/audio_service.dart';
import '../core/services/audio_player_manager.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/player/presentation/pages/player_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/favorites/presentation/pages/favorites_page.dart';
import '../features/history/presentation/pages/history_page.dart';
import 'theme/app_theme.dart';
import '../features/player/models/audio_item.dart';

class BilibiliMusicApp extends StatefulWidget {
  final SharedPreferences prefs;

  const BilibiliMusicApp({super.key, required this.prefs});

  @override
  State<BilibiliMusicApp> createState() => _BilibiliMusicAppState();
}

class _BilibiliMusicAppState extends State<BilibiliMusicApp> {
  late final GoRouter _router;
  late final BilibiliService _bilibiliService;
  late final AudioPlayerService _audioPlayerService;
  late final AudioPlayerManager _audioPlayerManager;
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();

    // 初始化服务
    _bilibiliService = BilibiliService(widget.prefs);
    _audioPlayerService = AudioPlayerService();
    _audioPlayerManager = AudioPlayerManager();

    // 主题模式
    final savedThemeMode = widget.prefs.getString('theme_mode') ?? 'system';
    _themeMode = ValueNotifier<ThemeMode>(savedThemeMode == 'dark'
        ? ThemeMode.dark
        : savedThemeMode == 'light'
            ? ThemeMode.light
            : ThemeMode.system);

    // 配置路由
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        // 主页
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => _buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const HomePage(),
          ),
        ),

        // 搜索页面
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => _buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const SearchPage(),
          ),
        ),

        // 播放页面
        GoRoute(
          path: '/player',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final audioItem = extra?['audio_item'] as AudioItem?;

            if (audioItem == null) {
              // 如果没有提供音频项，返回主页
              return _buildPageWithDefaultTransition(
                context: context,
                state: state,
                child: const HomePage(),
              );
            }

            return _buildPlayerPageTransition(
              context: context,
              state: state,
              child: PlayerPage(
                audioItem: audioItem,
              ),
            );
          },
        ),

        // 设置页面
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const SettingsPage(),
          ),
        ),

        // 收藏页面
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) => _buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const FavoritesPage(),
          ),
        ),

        // 历史记录页面
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => _buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const HistoryPage(),
          ),
        ),
      ],
    );

    // 初始化播放器
    _audioPlayerService.initialize();
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    _audioPlayerManager.dispose();
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
          create: (_) => BilibiliService(widget.prefs),
        ),
        ChangeNotifierProvider<AudioPlayerManager>.value(
          value: _audioPlayerManager,
        ),
        Provider<AudioPlayerService>.value(value: _audioPlayerService),
        Provider<SharedPreferences>.value(value: widget.prefs),
        Provider<GoRouter>.value(value: _router),
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
            routerConfig: _router,
          );
        },
      ),
    );
  }

  // 定义自定义页面过渡动画
  CustomTransitionPage<void> _buildPageWithDefaultTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // 播放页面特殊过渡动画
  CustomTransitionPage<void> _buildPlayerPageTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeIn).animate(animation),
          child: child,
        );
      },
    );
  }
}
