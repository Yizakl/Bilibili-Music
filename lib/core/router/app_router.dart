import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/login/presentation/pages/login_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/player/models/audio_item.dart' as player_models;
import '../services/audio_player_manager.dart';
//import '../../features/auth/presentation/pages/login_page.dart'; // 旧的登录页面

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => GoRouter(
        navigatorKey: _rootNavigatorKey,
        initialLocation: '/',
        routes: [
          // 首页
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
          // 设置页
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          // 登录页
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          // 播放器页面
          GoRoute(
            path: '/player',
            builder: (context, state) {
              // 获取传递的音频项目数据
              final extra = state.extra as Map<String, dynamic>?;
              final homeAudioItem = extra?['audio_item'];

              // 需要将home页面的AudioItem转换为player页面需要的AudioItem
              player_models.AudioItem? playerAudioItem;
              if (homeAudioItem != null) {
                playerAudioItem = player_models.AudioItem(
                  id: homeAudioItem.id,
                  title: homeAudioItem.title,
                  uploader: homeAudioItem.uploader,
                  thumbnail: homeAudioItem.thumbnail,
                  audioUrl: homeAudioItem.audioUrl,
                  addedTime: DateTime.now(),
                );
              }

              return PlayerPage(audioItem: playerAudioItem);
            },
          ),
        ],
        // 错误处理 - 自动跳转到首页
        errorBuilder: (context, state) => const HomePage(),
      );
}
