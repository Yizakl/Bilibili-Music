import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/favorites/presentation/pages/favorites_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/player/presentation/pages/player_page.dart';
import '../core/services/audio_player_manager.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: '搜索',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: '收藏',
              ),
            ],
            selectedIndex: _calculateSelectedIndex(state),
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/search');
                  break;
                case 2:
                  context.go('/favorites');
                  break;
              }
            },
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        // 获取传递的参数
        final extra = state.extra as Map<String, dynamic>?;
        final audioItem = extra?['audio_item'];

        if (audioItem != null) {
          return PlayerPage(audioItem: audioItem);
        }

        // 如果没有传递音频项，则使用当前正在播放的音频
        final audioManager =
            Provider.of<AudioPlayerManager>(context, listen: false);
        final currentAudio = audioManager.currentAudio;

        // 如果没有正在播放的音频，则回到首页
        if (currentAudio == null) {
          return const HomePage();
        }

        return PlayerPage(audioItem: currentAudio);
      },
    ),
  ],
);

int _calculateSelectedIndex(GoRouterState state) {
  final String location = state.uri.path;
  if (location.startsWith('/search')) {
    return 1;
  } else if (location.startsWith('/favorites')) {
    return 2;
  }
  return 0;
}
