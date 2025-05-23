import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/services/auth_service.dart';
import 'core/services/bilibili_service.dart';
import 'core/services/bilibili_enhanced_service.dart';
import 'core/services/audio_player_manager.dart';
import 'core/services/favorites_service.dart';
import 'core/services/bilibili_api.dart';
import 'core/services/settings_service.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'features/home/presentation/pages/home_page.dart';
import 'features/home/presentation/pages/pc_home_page.dart';
import 'core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/player/pages/player_page.dart';
import 'core/models/video_item.dart';
import 'features/player/models/audio_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置音频会话，特别是对iOS设备的后台播放支持
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    avAudioSessionRouteSharingPolicy:
        AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      flags: AndroidAudioFlags.none,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: true,
  ));

  // 初始化 just_audio_background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Bilibili Music Playback',
    androidNotificationOngoing: true,
  );

  // 获取本地存储实例
  final prefs = await SharedPreferences.getInstance();

  // 初始化服务
  final bilibiliApi = BilibiliApi(prefs);
  final authService = AuthService(prefs, bilibiliApi);
  final bilibiliService = BilibiliService(prefs: prefs);
  final settingsService = SettingsService();
  final audioPlayerManager = AudioPlayerManager(settingsService);
  final favoritesService = FavoritesService(prefs);

  // 创建增强版B站服务
  final bilibiliEnhancedService =
      BilibiliEnhancedService(bilibiliService, prefs);

  // 桌面端初始化窗口和托盘
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Bilibili Music',
      minimumSize: Size(800, 600),
    );

    // 设置窗口行为
    windowManager.setPreventClose(true); // 防止直接关闭

    // 添加窗口监听器
    windowManager.addListener(AppWindowListener());

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 初始化托盘图标
    await initSystemTray(audioPlayerManager);

    // 添加音频播放状态监听，用于更新托盘菜单
    audioPlayerManager.isPlayingNotifier.addListener(() {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        updateTrayMenu(audioPlayerManager);
      }
    });
  }

  // 运行应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => bilibiliService),
        ChangeNotifierProvider(create: (_) => audioPlayerManager),
        ChangeNotifierProvider(create: (_) => favoritesService),
        ChangeNotifierProvider(create: (_) => settingsService),
        Provider<BilibiliEnhancedService>.value(value: bilibiliEnhancedService),
      ],
      child: MyApp(settingsService: settingsService),
    ),
  );
  configLoading();
}

// 系统托盘初始化
Future<void> initSystemTray(AudioPlayerManager audioPlayerManager) async {
  try {
    // 修改为使用PNG图标而不是SVG
    String iconPath =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

    // 注册托盘监听器
    trayManager.addListener(AppTrayListener(audioPlayerManager));

    // 设置图标和工具提示
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Bilibili Music');

    // 设置托盘菜单
    await updateTrayMenu(audioPlayerManager);
  } catch (e) {
    print('初始化系统托盘失败: $e');
  }
}

// 更新托盘菜单
Future<void> updateTrayMenu(AudioPlayerManager audioPlayerManager) async {
  await trayManager.setContextMenu(Menu(
    items: [
      MenuItem(
        label: '打开播放器',
        onClick: (_) async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: audioPlayerManager.isPlaying ? '暂停' : '播放',
        onClick: (_) {
          if (audioPlayerManager.isPlaying) {
            audioPlayerManager.pause();
          } else {
            audioPlayerManager.resume();
          }
          updateTrayMenu(audioPlayerManager);
        },
      ),
      MenuItem(
        label: '下一首',
        onClick: (_) {
          audioPlayerManager.playNext();
        },
      ),
      MenuItem(
        label: '上一首',
        onClick: (_) {
          audioPlayerManager.playPrevious();
        },
      ),
      MenuItem.separator(),
      MenuItem(
        label: '退出',
        onClick: (_) {
          windowManager.destroy();
        },
      ),
    ],
  ));
}

// 窗口事件监听器
class AppWindowListener with WindowListener {
  @override
  void onWindowClose() async {
    // 当用户点击关闭按钮时最小化到托盘，而不是退出应用
    await windowManager.hide();
  }
}

// 托盘事件监听器
class AppTrayListener with TrayListener {
  final AudioPlayerManager audioPlayerManager;

  AppTrayListener(this.audioPlayerManager);

  @override
  void onTrayDoubleClick() async {
    // 显示窗口
    if (await windowManager.isVisible()) {
      await windowManager.focus();
    } else {
      await windowManager.show();
    }
  }

  @override
  void onTrayIconMouseDown() {
    // 更新托盘菜单状态
    updateTrayMenu(audioPlayerManager);
  }
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.light
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.blue
    ..backgroundColor = Colors.white
    ..indicatorColor = Colors.blue
    ..textColor = Colors.black
    ..maskColor = Colors.black.withOpacity(0.1)
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;

  const MyApp({Key? key, required this.settingsService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              settingsService.isPCMode ? const PCHomePage() : const HomePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/player',
          builder: (context, state) {
            // 从路由状态中获取 VideoItem 或 AudioItem
            final item = state.extra;
            if (item is VideoItem) {
              return PlayerPage.fromVideo(item);
            } else if (item is AudioItem) {
              return PlayerPage(
                audioItem: item,
                bvid: item.bvid,
                title: item.title,
                uploader: item.uploader,
              );
            }
            // 如果没有传递有效的 item，返回首页
            return settingsService.isPCMode
                ? const PCHomePage()
                : const HomePage();
          },
        ),
      ],
    );

    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return MaterialApp.router(
          title: 'Bilibili Music',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settingsService.themeMode,
          routerConfig: router,
          builder: EasyLoading.init(),
        );
      },
    );
  }
}
