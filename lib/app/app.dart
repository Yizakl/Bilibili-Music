import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/bilibili_service.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';

class BilibiliMusicApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const BilibiliMusicApp({
    super.key,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (context) => BilibiliService(prefs),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812), // iPhone X 设计稿尺寸
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'Bilibili Music',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (context) => const HomePage(),
              '/settings': (context) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
} 