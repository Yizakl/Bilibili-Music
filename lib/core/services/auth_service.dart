import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'bilibili_api.dart';

class AuthService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final BilibiliApi _bilibiliApi;

  User? _currentUser;
  bool _isLoading = false;
  String _error = '';
  bool _isGeneratingQRCode = false;
  String _qrCodeUrl = '';
  String _qrCodeKey = '';

  // 构造函数
  AuthService(this._prefs, this._bilibiliApi) {
    _loadUserFromPrefs();
  }

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isGeneratingQRCode => _isGeneratingQRCode;
  String get qrCodeUrl => _qrCodeUrl;
  String get qrCodeKey => _qrCodeKey;

  // 从本地存储加载用户
  Future<void> _loadUserFromPrefs() async {
    try {
      final userJson = _prefs.getString('user');
      if (userJson != null) {
        _currentUser = User.fromJson(json.decode(userJson));
        // 检查登录状态
        checkLoginStatus();
      }
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  // 保存用户到本地存储
  Future<void> _saveUserToPrefs(User user) async {
    try {
      await _prefs.setString('user', json.encode(user.toJson()));
    } catch (e) {
      debugPrint('保存用户信息失败: $e');
    }
  }

  // 检查登录状态
  Future<void> checkLoginStatus() async {
    if (_currentUser == null) return;

    try {
      final isLoggedIn = await _bilibiliApi.checkLoginStatus();
      if (!isLoggedIn) {
        await logout();
      }
    } catch (e) {
      debugPrint('检查登录状态失败: $e');
    }
  }

  // 生成登录二维码
  Future<Map<String, String>> generateLoginQRCode() async {
    _isGeneratingQRCode = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _bilibiliApi.generateQRCode();
      _qrCodeUrl = result['url'] ?? '';
      _qrCodeKey = result['key'] ?? '';
      debugPrint('获取到二维码URL: $_qrCodeUrl');
      debugPrint('获取到二维码KEY: $_qrCodeKey');

      return {
        'url': _qrCodeUrl,
        'key': _qrCodeKey,
      };
    } catch (e) {
      _error = '生成二维码失败: $e';
      debugPrint(_error);
      return {
        'url': '',
        'key': '',
      };
    } finally {
      _isGeneratingQRCode = false;
      notifyListeners();
    }
  }

  // 检查二维码登录状态
  Future<Map<String, dynamic>> checkLoginQRCodeStatus(String qrKey) async {
    if (qrKey.isEmpty) return {'status': 0, 'message': '二维码密钥为空'};

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _bilibiliApi.checkQRCodeStatus(qrKey);
      final int status = result['status'] ?? 0;
      final String message = result['message'] ?? '';

      debugPrint('二维码状态: $status');
      debugPrint('二维码返回信息: $message');

      // 如果登录成功，获取用户信息
      if (status == 2) {
        await getUserInfo();
      }

      return {
        'status': status,
        'message': message,
      };
    } catch (e) {
      _error = '检查二维码状态失败: $e';
      debugPrint(_error);
      return {
        'status': 0,
        'message': '检查二维码状态失败: $e',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 使用Cookie登录
  Future<bool> loginWithCookies(Map<String, String> cookies) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // 设置Cookie
      final success = await _bilibiliApi.setCookies(cookies);
      if (!success) {
        _error = '设置Cookie失败';
        return false;
      }

      // 获取用户信息
      return await getUserInfo();
    } catch (e) {
      _error = '登录失败: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 使用浏览器URL登录
  Future<bool> loginWithBrowserUrl(String url) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // 解析URL并设置Cookie
      final success = await _bilibiliApi.parseBrowserCookies(url);
      if (!success) {
        _error = '从URL解析Cookie失败';
        return false;
      }

      // 获取用户信息
      return await getUserInfo();
    } catch (e) {
      _error = '登录失败: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 获取用户信息
  Future<bool> getUserInfo() async {
    try {
      final userInfo = await _bilibiliApi.getUserInfo();
      debugPrint('获取到用户信息: $userInfo');

      if (userInfo.isNotEmpty && userInfo['data'] != null) {
        final userData = userInfo['data'];
        _currentUser = User.fromJson(userData);
        await _saveUserToPrefs(_currentUser!);
        notifyListeners();
        return true;
      } else {
        _error = '获取用户信息失败: ${userInfo['message'] ?? '未知错误'}';
        return false;
      }
    } catch (e) {
      _error = '获取用户信息失败: $e';
      debugPrint(_error);
      return false;
    }
  }

  // 登出
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _bilibiliApi.logout();
      _currentUser = null;
      await _prefs.remove('user');
    } catch (e) {
      debugPrint('登出失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
