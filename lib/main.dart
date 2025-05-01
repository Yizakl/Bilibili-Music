import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';

Future<void> main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化后台播放
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.bilibili.music.channel.audio',
    androidNotificationChannelName: 'Bilibili Music',
    androidNotificationOngoing: false,
    androidShowNotificationBadge: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidStopForegroundOnPause: false,
    fastForwardInterval: const Duration(seconds: 10),
    rewindInterval: const Duration(seconds: 10),
    notificationColor: const Color(0xFF2196F3), // 蓝色
  );

  // 初始化WebView平台
  if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    AndroidWebViewPlatform.registerWith();
  } else if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    WebKitWebViewPlatform.registerWith();
  }

  // 初始化SharedPreferences
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('初始化SharedPreferences失败: $e');
    prefs = await _createMockPrefs();
  }

  // 运行应用，如果 prefs 为空，创建一个模拟实现
  runApp(BilibiliMusicApp(
    prefs: prefs,
  ));
}

// 创建一个模拟的 SharedPreferences 实现
Future<SharedPreferences> _createMockPrefs() async {
  // 设置模拟值
  SharedPreferences.setMockInitialValues({});
  return await SharedPreferences.getInstance();
}
