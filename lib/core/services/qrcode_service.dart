import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
// 删除重复的import，因为下面已经有了相同的import语句
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class QRCodeService {
  final Dio _dio;
  final SharedPreferences _prefs;
  final String _cookieKey = 'bilibili_cookie';
  final String _csrfKey = 'bilibili_csrf';

  QRCodeService(this._dio, this._prefs) {
    _initDio();
  }

  void _initDio() {
    _dio.options.baseUrl = 'https://passport.bilibili.com/x/passport-login/web';
    final cookies = _prefs.getString(_cookieKey);
    if (cookies != null) {
      _dio.options.headers['Cookie'] = cookies;
    }
  }

  // 获取二维码登录的URL和key
  Future<Map<String, String>> getQRCode() async {
    try {
      final response = await _dio.get(
        '/qrcode/generate',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com',
            'Origin': 'https://www.bilibili.com',
          },
        ),
      );

      if (response.data['code'] == 0) {
        final data = response.data['data'];
        return {
          'url': data['url'],
          'qrcode_key': data['qrcode_key'],
        };
      }

      throw Exception(response.data['message'] ?? '获取二维码失败');
    } catch (e) {
      debugPrint('获取二维码失败: $e');
      throw Exception('获取二维码失败：${e.toString()}');
    }
  }

  // 检查二维码扫描状态
  Future<Map<String, dynamic>> checkQRCodeStatus(String qrcodeKey) async {
    try {
      final response = await _dio.get(
        '/qrcode/poll',
        queryParameters: {'qrcode_key': qrcodeKey},
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com',
            'Origin': 'https://www.bilibili.com',
          },
        ),
      );

      if (response.statusCode == 200) {
        final code = response.data['code'];
        final data = response.data['data'];

        // 处理不同的扫码状态
        switch (code) {
          case 0:
            // 扫码成功并确认登录
            if (data['code'] == 0) {
              // 保存Cookie
              final cookies = response.headers['set-cookie'];
              if (cookies != null) {
                final cookieString = cookies.join('; ');
                await _prefs.setString(_cookieKey, cookieString);
                _dio.options.headers['Cookie'] = cookieString;
              }
              return {'status': 'success', 'url': data['url']};
            }
            // 已扫码但未确认
            else if (data['code'] == 86038) {
              return {'status': 'scanned'};
            }
            // 二维码已过期
            else if (data['code'] == 86090) {
              return {'status': 'expired'};
            }
            // 等待扫码
            return {'status': 'waiting'};
          default:
            throw Exception(response.data['message'] ?? '检查二维码状态失败');
        }
      }

      throw Exception('检查二维码状态失败');
    } catch (e) {
      debugPrint('检查二维码状态失败: $e');
      throw Exception('检查二维码状态失败：${e.toString()}');
    }
  }
}
