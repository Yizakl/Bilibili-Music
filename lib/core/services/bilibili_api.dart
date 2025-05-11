import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart';

class BilibiliApi {
  // APP Key 常量
  static const String _appKey = "783bbb7264451d82";
  static const String _appSecret = "2653583c8873dea268ab9386918b1d65";

  // B站API基础URL
  static const String _baseUrl = "https://api.bilibili.com";
  static const String _passportUrl = "https://passport.bilibili.com";

  // HTTP 客户端
  final http.Client _client = http.Client();

  // 保存用户Cookie
  Map<String, String> _cookies = {};

  // 单例相关
  static BilibiliApi? _instance;

  // 获取单例实例
  static BilibiliApi getInstance(SharedPreferences prefs) {
    _instance ??= BilibiliApi._internal(prefs);
    return _instance!;
  }

  // 内部构造函数
  BilibiliApi._internal(this._prefs) {
    _checkCookieValidity();
  }

  final SharedPreferences _prefs;
  final String _cookieKey = 'bilibili_cookies';
  final String _csrfKey = 'bili_csrf';

  bool _isLoggedIn = false;

  // 构造函数 - 外部使用
  BilibiliApi(SharedPreferences prefs) : _prefs = prefs {
    _checkCookieValidity();
  }

  // Getter
  bool get isLoggedIn => _isLoggedIn;

  // 初始化检查Cookie有效性
  Future<void> _checkCookieValidity() async {
    final String? cookieStr = _prefs.getString(_cookieKey);
    if (cookieStr != null && cookieStr.isNotEmpty) {
      try {
        await checkLoginStatus();
      } catch (e) {
        debugPrint('初始化检查Cookie失败: $e');
        // 清除可能无效的Cookie
        await logout();
      }
    }
  }

  // 获取存储的Cookie
  Map<String, String> _getCookies() {
    final String? cookieStr = _prefs.getString(_cookieKey);
    if (cookieStr == null || cookieStr.isEmpty) {
      return {};
    }

    try {
      return Map<String, String>.from(json.decode(cookieStr));
    } catch (e) {
      debugPrint('Cookie解析失败: $e');
      return {};
    }
  }

  // 获取CSRF令牌
  String _getCsrfToken() {
    return _prefs.getString(_csrfKey) ?? '';
  }

  // 设置Cookie
  Future<bool> setCookies(Map<String, String> cookies) async {
    try {
      if (cookies.isEmpty) {
        debugPrint('提供的Cookie为空');
        return false;
      }

      // 保存Cookie
      await _prefs.setString(_cookieKey, json.encode(cookies));

      // 如果有bili_jct，保存为CSRF令牌
      if (cookies.containsKey('bili_jct')) {
        await _prefs.setString(_csrfKey, cookies['bili_jct']!);
      }

      // 检查登录状态
      return await checkLoginStatus();
    } catch (e) {
      debugPrint('设置Cookie失败: $e');
      return false;
    }
  }

  // 从浏览器URL解析Cookie
  Future<bool> parseBrowserCookies(String url) async {
    try {
      if (!url.contains('bilibili.com')) {
        debugPrint('URL不是Bilibili的链接');
        return false;
      }

      // 解析URL参数
      final Uri uri = Uri.parse(url);
      final Map<String, String> queryParams = uri.queryParameters;

      // 检查是否包含必要的Cookie
      final Map<String, String> cookies = {};
      bool hasImportantCookies = false;

      if (queryParams.containsKey('SESSDATA')) {
        cookies['SESSDATA'] = queryParams['SESSDATA']!;
        hasImportantCookies = true;
      }

      if (queryParams.containsKey('bili_jct')) {
        cookies['bili_jct'] = queryParams['bili_jct']!;
        hasImportantCookies = true;
      }

      if (queryParams.containsKey('DedeUserID')) {
        cookies['DedeUserID'] = queryParams['DedeUserID']!;
        hasImportantCookies = true;
      }

      if (!hasImportantCookies) {
        debugPrint('URL中没有找到必要的Cookie');
        return false;
      }

      // 保存解析到的Cookie
      return await setCookies(cookies);
    } catch (e) {
      debugPrint('解析浏览器URL失败: $e');
      return false;
    }
  }

  // 检查登录状态
  Future<bool> checkLoginStatus() async {
    try {
      final userInfo = await getUserInfo();

      if (userInfo.isNotEmpty &&
          userInfo['code'] == 0 &&
          userInfo['data'] != null) {
        _isLoggedIn = true;
      } else {
        _isLoggedIn = false;
      }

      return _isLoggedIn;
    } catch (e) {
      debugPrint('检查登录状态失败: $e');
      _isLoggedIn = false;
      return false;
    }
  }

  // 获取用户信息
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final cookies = _getCookies();
      if (cookies.isEmpty) {
        return {'code': -1, 'message': '未登录'};
      }

      final response = await _makeRequest(
        'GET',
        'https://api.bilibili.com/x/web-interface/nav',
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return {'code': -1, 'message': e.toString()};
    }
  }

  // 生成登录二维码
  Future<Map<String, dynamic>> generateQRCode() async {
    try {
      final response = await _makeRequest(
        'GET',
        'https://passport.bilibili.com/qrcode/getLoginUrl',
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['code'] == 0 && data['data'] != null) {
        return {
          'url': data['data']['url'] ?? '',
          'key': data['data']['oauthKey'] ?? '',
        };
      } else {
        throw Exception('生成二维码失败: ${data['message']}');
      }
    } catch (e) {
      debugPrint('生成二维码失败: $e');
      throw Exception('生成二维码失败: $e');
    }
  }

  // 检查二维码登录状态
  Future<Map<String, dynamic>> checkQRCodeStatus(String qrKey) async {
    try {
      if (qrKey.isEmpty) {
        return {'status': 0, 'message': '二维码密钥为空'};
      }

      final response = await _makeRequest(
        'POST',
        'https://passport.bilibili.com/qrcode/getLoginInfo',
        body: {'oauthKey': qrKey},
      );

      final Map<String, dynamic> data = json.decode(response.body);
      debugPrint('检查二维码状态返回: $data');

      // 检查登录是否成功
      final bool isSuccess =
          data['status'] == true || data['data'] == 0 || data['status'] == 2;

      if (isSuccess && data.containsKey('data') && data['data'] is Map) {
        // 登录成功，保存Cookie
        final Map<String, String> cookies = {};

        // 检查是否有URL参数
        if (data['data']['url'] != null) {
          final String url = data['data']['url'];
          final Uri uri = Uri.parse(url);
          final Map<String, String> queryParams = uri.queryParameters;

          // 提取Cookie
          if (queryParams.containsKey('SESSDATA')) {
            cookies['SESSDATA'] = queryParams['SESSDATA']!;
          }

          if (queryParams.containsKey('bili_jct')) {
            cookies['bili_jct'] = queryParams['bili_jct']!;
          }

          if (queryParams.containsKey('DedeUserID')) {
            cookies['DedeUserID'] = queryParams['DedeUserID']!;
          }
        }

        // 检查是否从响应头中获取cookie
        if (response.headers['set-cookie'] != null) {
          final String setCookie = response.headers['set-cookie']!;

          // 解析Set-Cookie头
          final List<String> cookieParts = setCookie.split(';');
          for (final part in cookieParts) {
            if (part.contains('=')) {
              final List<String> keyValue = part.trim().split('=');
              final String key = keyValue[0];
              final String value = keyValue.length > 1 ? keyValue[1] : '';

              if (key == 'SESSDATA' ||
                  key == 'bili_jct' ||
                  key == 'DedeUserID') {
                cookies[key] = value;
              }
            }
          }
        }

        // 检查token_info字段
        if (data['data']['token_info'] != null) {
          final tokenInfo = data['data']['token_info'];
          if (tokenInfo['SESSDATA'] != null) {
            cookies['SESSDATA'] = tokenInfo['SESSDATA'];
          }
          if (tokenInfo['bili_jct'] != null) {
            cookies['bili_jct'] = tokenInfo['bili_jct'];
          }
          if (tokenInfo['DedeUserID'] != null) {
            cookies['DedeUserID'] = tokenInfo['DedeUserID'].toString();
          }
        }

        // 保存Cookie
        if (cookies.isNotEmpty) {
          await setCookies(cookies);
        }
      }

      return {
        'status': isSuccess ? 2 : data['data'],
        'message': isSuccess ? '登录成功' : '二维码未确认',
      };
    } catch (e) {
      debugPrint('检查二维码状态失败: $e');
      return {'status': 0, 'message': '检查失败: $e'};
    }
  }

  // 获取推荐视频
  Future<Map<String, dynamic>> getRecommendedVideos() async {
    try {
      final response = await _makeRequest(
        'GET',
        'https://api.bilibili.com/x/web-interface/index/top/rcmd',
        queryParams: {'fresh_type': '3'},
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('获取推荐视频失败: $e');
      return {'code': -1, 'message': e.toString()};
    }
  }

  // 获取用户收藏
  Future<Map<String, dynamic>> getUserFavorites() async {
    try {
      if (!isLoggedIn) {
        return {'code': -1, 'message': '未登录'};
      }

      final response = await _makeRequest(
        'GET',
        'https://api.bilibili.com/x/v3/fav/folder/created/list-all',
        queryParams: {'up_mid': ''},
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('获取用户收藏失败: $e');
      return {'code': -1, 'message': e.toString()};
    }
  }

  // 搜索内容
  Future<Map<String, dynamic>> searchContent(String keyword) async {
    try {
      if (keyword.isEmpty) {
        return {'code': -1, 'message': '搜索关键词为空'};
      }

      final response = await _makeRequest(
        'GET',
        'https://api.bilibili.com/x/web-interface/search/all/v2',
        queryParams: {'keyword': keyword},
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('搜索内容失败: $e');
      return {'code': -1, 'message': e.toString()};
    }
  }

  // 获取视频详情
  Future<Map<String, dynamic>> getVideoDetail(String bvid) async {
    try {
      if (bvid.isEmpty) {
        return {'code': -1, 'message': '视频ID为空'};
      }

      // 准备查询参数
      final Map<String, String> params = {};
      if (bvid.startsWith('BV')) {
        params['bvid'] = bvid;
      } else if (bvid.startsWith('av')) {
        params['aid'] = bvid.substring(2);
      } else {
        params['bvid'] = bvid;
      }

      final response = await _makeRequest(
        'GET',
        'https://api.bilibili.com/x/web-interface/view',
        queryParams: params,
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('获取视频详情失败: $e');
      return {'code': -1, 'message': e.toString()};
    }
  }

  // 获取音频URL
  Future<Map<String, dynamic>> getAudioUrl(String bvid) async {
    try {
      if (bvid.isEmpty) {
        return {'code': -1, 'message': '视频ID为空'};
      }

      // 先获取视频详情以获取cid
      final videoDetail = await getVideoDetail(bvid);
      if (videoDetail['code'] != 0 || videoDetail['data'] == null) {
        return {'code': -1, 'message': '获取视频详情失败'};
      }

      final String cid = videoDetail['data']['cid'].toString();

      // 准备查询参数
      final Map<String, String> params = {};
      if (bvid.startsWith('BV')) {
        params['bvid'] = bvid;
      } else if (bvid.startsWith('av')) {
        params['aid'] = bvid.substring(2);
      } else {
        params['bvid'] = bvid;
      }

      params['cid'] = cid;
      params['fnval'] = '16'; // 获取dash格式

      final response = await _makeRequest(
        'GET',
        'https://api.bilibili.com/x/player/playurl',
        queryParams: params,
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['code'] != 0 || data['data'] == null) {
        return {'code': -1, 'message': '获取音频URL失败'};
      }

      // 从dash格式数据中提取音频URL
      final List<dynamic>? audioList = data['data']['dash']?['audio'];
      if (audioList == null || audioList.isEmpty) {
        return {'code': -1, 'message': '未找到音频流'};
      }

      // 获取码率最高的音频
      audioList
          .sort((a, b) => (b['bandwidth'] ?? 0).compareTo(a['bandwidth'] ?? 0));
      final String audioUrl = audioList.first['baseUrl'] ?? '';

      return {
        'code': 0,
        'audio_url': audioUrl,
      };
    } catch (e) {
      debugPrint('获取音频URL失败: $e');
      return {'code': -1, 'message': e.toString()};
    }
  }

  // 登出
  Future<bool> logout() async {
    try {
      // 清除Cookie和CSRF令牌
      await _prefs.remove(_cookieKey);
      await _prefs.remove(_csrfKey);

      _isLoggedIn = false;
      return true;
    } catch (e) {
      debugPrint('登出失败: $e');
      return false;
    }
  }

  // 通用请求方法
  Future<http.Response> _makeRequest(
    String method,
    String url, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    // 获取Cookie
    final Map<String, String> cookies = _getCookies();

    // 构建请求URL
    Uri uri = Uri.parse(url);
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    // 构建请求头
    final Map<String, String> headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Referer': 'https://www.bilibili.com',
    };

    // 添加Cookie
    if (cookies.isNotEmpty) {
      final List<String> cookieParts = [];
      cookies.forEach((key, value) {
        cookieParts.add('$key=$value');
      });
      headers['Cookie'] = cookieParts.join('; ');
    }

    // 发送请求
    http.Response response;

    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else if (method == 'POST') {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';

      // 构建表单数据
      String encodedBody = '';
      if (body != null && body.isNotEmpty) {
        final List<String> bodyParts = [];
        body.forEach((key, value) {
          bodyParts.add('$key=${Uri.encodeComponent(value.toString())}');
        });
        encodedBody = bodyParts.join('&');
      }

      response = await http.post(uri, headers: headers, body: encodedBody);
    } else {
      throw Exception('不支持的请求方法: $method');
    }

    return response;
  }
}
