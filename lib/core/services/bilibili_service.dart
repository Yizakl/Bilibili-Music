import 'package:dio/dio.dart';
import '../../features/player/models/audio_item.dart' as player_models;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/video_item.dart';

class BilibiliService {
  final Dio _dio;
  final SharedPreferences _prefs;
  final Random _random = Random();
  static const String _cookieKey = 'bilibili_cookies';
  static const String _csrfKey = 'bilibili_csrf';

  // API地址
  static const String _apiBaseUrl = 'https://api.bilibili.com';
  static const String _passportApiUrl = 'https://passport.bilibili.com';
  static const String _loginApiUrl =
      'https://passport.bilibili.com/x/passport-login/web';

  // 添加新接口URI常量
  static const String _mir6ApiBaseUrl = 'https://api.mir6.com/api/bzjiexi';

  // 历史记录键
  static const String _searchHistoryKey = 'search_history';
  static const String _playHistoryKey = 'play_history';
  static const String _favoriteKey = 'favorites';

  BilibiliService(this._prefs) : _dio = Dio() {
    _initDio();
  }

  void _initDio() {
    _dio.options.baseUrl = 'https://api.bilibili.com';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': 'https://www.bilibili.com',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Origin': 'https://www.bilibili.com',
      'Sec-Ch-Ua':
          '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
      'Sec-Fetch-Site': 'same-site',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Dest': 'empty',
    };

    // 添加拦截器用于日志记录
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (object) => debugPrint(object.toString()),
      ));
    }

    // 添加错误处理拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 为每个请求添加随机数，避免缓存
        options.queryParameters['t'] = DateTime.now().millisecondsSinceEpoch;
        return handler.next(options);
      },
      onError: (DioException e, ErrorInterceptorHandler handler) async {
        debugPrint('API错误: ${e.message}');
        debugPrint('请求: ${e.requestOptions.uri}');
        debugPrint('数据: ${e.requestOptions.data}');

        // 如果是412错误，尝试刷新Cookie
        if (e.response?.statusCode == 412) {
          debugPrint('遇到412错误，尝试刷新Cookie');
          try {
            // 获取新的Cookie
            final response = await Dio().get(
              'https://www.bilibili.com',
              options: Options(
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
                },
                followRedirects: false,
                validateStatus: (status) => true,
              ),
            );

            final cookies = response.headers['set-cookie'];
            if (cookies != null && cookies.isNotEmpty) {
              final cookieString = cookies.join('; ');
              await _prefs.setString(_cookieKey, cookieString);
              _dio.options.headers['Cookie'] = cookieString;

              // 重试原始请求
              final retryResponse = await _dio.fetch(e.requestOptions);
              return handler.resolve(retryResponse);
            }
          } catch (retryError) {
            debugPrint('刷新Cookie失败: $retryError');
          }
        }
        return handler.next(e);
      },
    ));

    // 恢复存储的 Cookie
    final cookies = _prefs.getString(_cookieKey);
    if (cookies != null) {
      _dio.options.headers['Cookie'] = cookies;
    }
  }

  // 登录方法
  Future<bool> login(String username, String password) async {
    try {
      debugPrint('尝试登录，用户名: $username');

      // 获取公钥和盐值
      try {
        final keyResponse = await _dio.get(
          'https://passport.bilibili.com/x/passport-login/web/key',
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              'Referer': 'https://www.bilibili.com',
              'Origin': 'https://www.bilibili.com',
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
              'Accept-Encoding': 'gzip, deflate, br',
              'Connection': 'keep-alive',
            },
            validateStatus: (status) => status! < 500,
          ),
        );

        if (keyResponse.statusCode != 200) {
          debugPrint('获取公钥失败：HTTP ${keyResponse.statusCode}');
          throw Exception('获取公钥失败：HTTP ${keyResponse.statusCode}');
        }

        if (keyResponse.data == null) {
          debugPrint('获取公钥失败：响应为空');
          throw Exception('获取公钥失败：响应为空');
        }

        if (keyResponse.data['code'] != 0) {
          debugPrint('获取公钥失败：${keyResponse.data['message']}');
          throw Exception('获取公钥失败：${keyResponse.data['message']}');
        }

        final publicKey = keyResponse.data['data']['key'];
        final hash = keyResponse.data['data']['hash'];

        debugPrint('获取到公钥和哈希值');

        // 由于加密逻辑复杂，这里简化处理
        // 在实际应用中应该正确实现RSA加密
        final encryptedPassword = _encodePassword(password, hash);

        debugPrint('密码加密完成');

        // 执行登录
        try {
          final loginResponse = await _dio.post(
            'https://passport.bilibili.com/x/passport-login/web/login',
            data: {
              'username': username,
              'password': encryptedPassword,
              'keep': true,
              'source': 'main_web',
              'go_url': 'https://www.bilibili.com',
            },
            options: Options(
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Referer': 'https://passport.bilibili.com/login',
                'Origin': 'https://passport.bilibili.com',
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
              },
              validateStatus: (status) => status! < 500,
            ),
          );

          if (loginResponse.statusCode != 200) {
            debugPrint('登录请求失败：HTTP ${loginResponse.statusCode}');
            throw Exception('登录请求失败：HTTP ${loginResponse.statusCode}');
          }

          if (loginResponse.data == null) {
            debugPrint('登录请求失败：响应为空');
            throw Exception('登录请求失败：响应为空');
          }

          debugPrint('登录请求结果: ${loginResponse.data['code']}');

          if (loginResponse.data['code'] == 0) {
            // 保存 Cookie
            final cookies = loginResponse.headers['set-cookie'];
            if (cookies != null) {
              final cookieString = cookies.join('; ');
              await _prefs.setString(_cookieKey, cookieString);
              _dio.options.headers['Cookie'] = cookieString;

              // 提取并保存 CSRF Token
              final csrfToken = _extractCsrfToken(cookieString);
              if (csrfToken != null) {
                await _prefs.setString(_csrfKey, csrfToken);
              }

              // 获取用户信息
              try {
                final userResponse = await _dio.get(
                  'https://api.bilibili.com/x/web-interface/nav',
                  options: Options(
                    headers: {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                      'Referer': 'https://www.bilibili.com',
                      'Cookie': cookieString,
                      'Accept': 'application/json, text/plain, */*',
                      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                      'Accept-Encoding': 'gzip, deflate, br',
                      'Connection': 'keep-alive',
                    },
                    validateStatus: (status) => status! < 500,
                  ),
                );

                if (userResponse.statusCode != 200) {
                  debugPrint('获取用户信息失败：HTTP ${userResponse.statusCode}');
                  return false;
                }

                if (userResponse.data == null) {
                  debugPrint('获取用户信息失败：响应为空');
                  return false;
                }

                if (userResponse.data['code'] == 0) {
                  final userData = userResponse.data['data'];
                  final user = UserModel(
                    mid: userData['mid'] is int
                        ? userData['mid']
                        : int.parse(userData['mid'].toString()),
                    uid: userData['mid'].toString(),
                    username: userData['uname'],
                    avatar: userData['face'],
                    isLoggedIn: true,
                    isVip: userData['vipStatus'] == 1,
                  );

                  await user.saveToPrefs(_prefs);
                  return true;
                }
              } catch (e) {
                debugPrint('获取用户信息失败: $e');
                return false;
              }

              return true;
            }
          }

          if (loginResponse.data['code'] == -105) {
            debugPrint('需要验证码');
            throw Exception('需要验证码，请使用浏览器登录');
          } else if (loginResponse.data['code'] == -629) {
            debugPrint('账号或密码错误');
            throw Exception('账号或密码错误');
          } else {
            debugPrint('登录失败: ${loginResponse.data['message']}');
            throw Exception(loginResponse.data['message'] ?? '登录失败');
          }
        } catch (e) {
          debugPrint('登录请求失败: $e');
          throw e;
        }
      } catch (e) {
        debugPrint('获取公钥失败: $e');
        throw e;
      }
    } catch (e) {
      debugPrint('登录失败: $e');
      throw e;
    }

    return false;
  }

  // 用于密码加密的辅助方法
  String _encodePassword(String password, String hash) {
    try {
      // 这里进行密码加密
      // 在实际实现中，需要使用RSA加密，这里简化处理
      // 实际上需要使用哈希和公钥进行加密
      return Uri.encodeComponent(password);
    } catch (e) {
      debugPrint('密码加密失败: $e');
      return password;
    }
  }

  // 提取 CSRF Token
  String? _extractCsrfToken(String cookies) {
    final regex = RegExp(r'bili_jct=([^;]+)');
    final match = regex.firstMatch(cookies);
    return match?.group(1);
  }

  // 检查登录状态
  Future<bool> checkLogin() async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/nav',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 检查API返回的状态码
        if (data != null && data['code'] == 0 && data['data'] != null) {
          final isLogin = data['data']['isLogin'] == 1;

          if (isLogin) {
            debugPrint('用户已登录');

            // 如果存在用户信息，可以保存到本地
            if (data['data']['uname'] != null) {
              await _prefs.setString('user_name', data['data']['uname']);
            }

            if (data['data']['mid'] != null) {
              await _prefs.setString('user_id', data['data']['mid'].toString());
            }

            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('检查登录状态失败: $e');
      return false;
    }
  }

  // 退出登录
  Future<bool> logout() async {
    try {
      // 清除cookies和用户信息
      await _prefs.remove(_cookieKey);
      await _prefs.remove(_csrfKey);
      _dio.options.headers.remove('Cookie');

      return true;
    } catch (e) {
      debugPrint('退出登录失败: $e');
      return false;
    }
  }

  // 搜索视频
  Future<List<VideoItem>> searchVideos(String keyword) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'keyword': keyword,
        'search_type': 'video',
        'order': 'totalrank',
        'page': 1,
        'platform': 'pc',
      };

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/search/type',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final List<dynamic> items = data['data']['result'] ?? [];

          // 解析视频项
          final List<VideoItem> videos = [];
          for (var item in items) {
            try {
              // 转换为我们需要的格式
              final Map<String, dynamic> convertedItem = {
                'bvid': item['bvid'],
                'title': item['title'],
                'author': item['author'],
                'mid': item['mid'],
                'pic': item['pic'],
                'duration': item['duration'],
                'play': item['play'],
                'pubdate': item['pubdate'],
              };

              final video = VideoItem.fromJson(convertedItem);
              videos.add(video);
            } catch (e) {
              debugPrint('解析搜索结果失败: $e');
            }
          }

          return videos;
        }
      }

      return [];
    } catch (e) {
      debugPrint('搜索视频失败: $e');
      return [];
    }
  }

  // 获取视频详情
  Future<VideoItem?> getVideoDetail(String videoId) async {
    try {
      // 移除videoId前缀
      final String id = videoId.startsWith('BV')
          ? videoId
          : videoId.startsWith('av')
              ? videoId.substring(2)
              : videoId;

      // 构建请求参数
      final Map<String, dynamic> params =
          videoId.startsWith('BV') ? {'bvid': id} : {'aid': id};

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/view',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final videoData = data['data'];

          // 创建VideoItem对象
          final video = VideoItem.fromJson(videoData);

          // 将视频添加到播放历史
          _addToPlayHistory(video);

          return video;
        }
      }

      return null;
    } catch (e) {
      debugPrint('获取视频详情失败: $e');
      return null;
    }
  }

  // 获取视频音频URL
  Future<String> getAudioUrl(String videoId) async {
    try {
      // 先尝试使用mir6 API
      final mirAudioUrl = await getAudioUrlWithMir6Api(videoId);
      if (mirAudioUrl.isNotEmpty) {
        return mirAudioUrl;
      }

      // 如果mir6 API失败，使用原生API
      return await _getAudioUrlWithNativeApi(videoId);
    } catch (e) {
      debugPrint('获取音频URL失败: $e');
      return '';
    }
  }

  // 使用mir6 API获取音频URL
  Future<String> getAudioUrlWithMir6Api(String videoId) async {
    try {
      // 标准化视频ID（移除可能的前缀）
      String standardizedId = videoId;
      if (!videoId.startsWith('BV') && !videoId.startsWith('av')) {
        standardizedId = 'BV' + videoId;
      }

      // 构造视频URL
      final videoUrl = 'https://www.bilibili.com/video/$standardizedId';

      // 尝试先获取JSON数据
      final apiUrl = 'https://api.mir6.com/api/bzjiexi';
      final jsonUrl = '$apiUrl?url=$videoUrl&type=json';

      debugPrint('尝试通过mir6 API获取视频信息: $jsonUrl');

      try {
        // 使用dio获取视频JSON信息
        final response = await Dio().get(jsonUrl,
            options: Options(
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
              },
              responseType: ResponseType.json,
              validateStatus: (status) => status! < 500,
            ));

        if (response.statusCode == 200 && response.data != null) {
          debugPrint('获取到视频信息');

          // 从JSON数据中提取直链URL
          if (response.data['data'] != null &&
              response.data['data'][0] != null &&
              response.data['data'][0]['video_url'] != null) {
            final directUrl = response.data['data'][0]['video_url'];
            debugPrint('从JSON中获取到视频直链: $directUrl');
            return directUrl;
          }
        }
      } catch (e) {
        debugPrint('获取JSON数据失败: $e');
      }

      // 如果JSON方式失败，直接使用MP4方式
      final mp4Url = '$apiUrl?url=$videoUrl&type=mp4';
      debugPrint('使用直接MP4链接: $mp4Url');
      return mp4Url;
    } catch (e) {
      debugPrint('获取音频URL失败: $e');
      return '';
    }
  }

  // 使用原生API获取音频URL
  Future<String> _getAudioUrlWithNativeApi(String videoId) async {
    try {
      // 获取视频详情，提取cid
      final videoDetail = await getVideoDetail(videoId);
      if (videoDetail == null || videoDetail.cid == null) {
        return '';
      }

      final String cid = videoDetail.cid!;

      // 构建请求参数
      final Map<String, dynamic> params = {
        'bvid': videoId.startsWith('BV') ? videoId : null,
        'aid': videoId.startsWith('av') ? videoId.substring(2) : null,
        'cid': cid,
        'fnval': 16, // 获取音频
      };

      // 移除空值
      params.removeWhere((key, value) => value == null);

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/player/playurl',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final List<dynamic> dashAudio = data['data']['dash']?['audio'] ?? [];

          if (dashAudio.isNotEmpty) {
            // 查找最高质量的音频
            dashAudio.sort(
                (a, b) => (b['bandwidth'] ?? 0).compareTo(a['bandwidth'] ?? 0));
            return dashAudio.first['baseUrl'] ?? '';
          }
        }
      }

      return '';
    } catch (e) {
      debugPrint('原生API获取音频URL失败: $e');
      return '';
    }
  }

  // 丰富视频信息
  Future<player_models.AudioItem?> enrichVideoWithMir6Api(
      player_models.AudioItem audioItem) async {
    try {
      if (audioItem.audioUrl.isNotEmpty) {
        return audioItem;
      }

      final String audioUrl = await getAudioUrl(audioItem.id);
      if (audioUrl.isEmpty) {
        return null;
      }

      return audioItem.copyWith(audioUrl: audioUrl);
    } catch (e) {
      debugPrint('丰富视频信息失败: $e');
      return null;
    }
  }

  // 获取热门视频
  Future<List<VideoItem>> getPopularVideos(
      {int page = 1, int pageSize = 20}) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'ps': pageSize,
        'pn': page,
      };

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/popular',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final List<dynamic> items = data['data']['list'] ?? [];

          // 解析视频项
          final List<VideoItem> videos = [];
          for (var item in items) {
            try {
              final video = VideoItem.fromJson(item);
              videos.add(video);
            } catch (e) {
              debugPrint('解析热门视频失败: $e');
            }
          }

          return videos;
        }
      }

      return [];
    } catch (e) {
      debugPrint('获取热门视频失败: $e');
      return [];
    }
  }

  // 获取分区视频
  Future<List<VideoItem>> getCategoryVideos(int tid,
      {int page = 1, int pageSize = 20}) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'rid': tid,
        'ps': pageSize,
        'pn': page,
      };

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/dynamic/region',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final List<dynamic> archives = data['data']['archives'] ?? [];

          // 解析视频项
          final List<VideoItem> videos = [];
          for (var archive in archives) {
            try {
              final video = VideoItem.fromJson(archive);
              videos.add(video);
            } catch (e) {
              debugPrint('解析分区视频失败: $e');
            }
          }

          return videos;
        }
      }

      return [];
    } catch (e) {
      debugPrint('获取分区视频失败: $e');
      return [];
    }
  }

  // 获取UP主的视频
  Future<List<VideoItem>> getUploaderVideos(String mid,
      {int page = 1, int pageSize = 30}) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'mid': mid,
        'ps': pageSize,
        'pn': page,
        'order': 'pubdate',
      };

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/space/arc/search',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final List<dynamic> vlist = data['data']['list']?['vlist'] ?? [];

          // 解析视频项
          final List<VideoItem> videos = [];
          for (var video in vlist) {
            try {
              // 创建VideoItem对象
              final videoItem = VideoItem(
                id: video['bvid'] ?? 'av${video['aid']}',
                title: video['title'] ?? '未知标题',
                uploader: video['author'] ?? '未知UP主',
                uploaderId: video['mid']?.toString() ?? '',
                thumbnail: video['pic'] ?? '',
                playCount: video['play'] ?? 0,
                duration: video['duration'] ?? '00:00',
                publishDate: _formatDate(video['pubdate'] ?? 0),
              );

              videos.add(videoItem);
            } catch (e) {
              debugPrint('解析UP主视频失败: $e');
            }
          }

          return videos;
        }
      }

      return [];
    } catch (e) {
      debugPrint('获取UP主视频失败: $e');
      return [];
    }
  }

  // 添加到搜索历史
  void _addToSearchHistory(String keyword) {
    try {
      if (keyword.isEmpty) return;

      // 获取现有历史
      List<String> history = _prefs.getStringList(_searchHistoryKey) ?? [];

      // 如果关键词已存在，先移除
      history.remove(keyword);

      // 添加到列表开头
      history.insert(0, keyword);

      // 限制历史记录数量
      if (history.length > 20) {
        history = history.sublist(0, 20);
      }

      // 保存历史
      _prefs.setStringList(_searchHistoryKey, history);
    } catch (e) {
      debugPrint('添加搜索历史失败: $e');
    }
  }

  // 获取搜索历史
  List<String> getSearchHistory() {
    try {
      return _prefs.getStringList(_searchHistoryKey) ?? [];
    } catch (e) {
      debugPrint('获取搜索历史失败: $e');
      return [];
    }
  }

  // 清除搜索历史
  Future<bool> clearSearchHistory() async {
    try {
      return await _prefs.remove(_searchHistoryKey);
    } catch (e) {
      debugPrint('清除搜索历史失败: $e');
      return false;
    }
  }

  // 添加到播放历史
  void _addToPlayHistory(VideoItem video) {
    try {
      // 获取现有历史
      String historyJson = _prefs.getString(_playHistoryKey) ?? '[]';
      List<dynamic> history = jsonDecode(historyJson);

      // 检查是否已存在
      int existingIndex = history.indexWhere((item) => item['id'] == video.id);
      if (existingIndex != -1) {
        // 如果存在，移除旧的
        history.removeAt(existingIndex);
      }

      // 添加到开头
      history.insert(0, video.toJson());

      // 限制历史记录数量
      if (history.length > 100) {
        history = history.sublist(0, 100);
      }

      // 保存历史
      _prefs.setString(_playHistoryKey, jsonEncode(history));
    } catch (e) {
      debugPrint('添加播放历史失败: $e');
    }
  }

  // 获取播放历史
  List<VideoItem> getPlayHistory() {
    try {
      final String historyJson = _prefs.getString(_playHistoryKey) ?? '[]';
      final List<dynamic> historyList = json.decode(historyJson);

      final List<VideoItem> history = [];
      for (final item in historyList) {
        try {
          final Map<String, dynamic> videoJson = item;
          final video = VideoItem(
            id: videoJson['id'],
            title: videoJson['title'],
            uploader: videoJson['uploader'],
            uploaderId: videoJson['uploaderId'] ?? '',
            thumbnail: videoJson['thumbnail'],
            playCount: videoJson['playCount'],
            duration: videoJson['duration'],
            publishDate: videoJson['publishDate'] ?? '',
          );
          history.add(video);
        } catch (e) {
          debugPrint('解析播放历史项失败: $e');
        }
      }

      return history;
    } catch (e) {
      debugPrint('获取播放历史失败: $e');
      return [];
    }
  }

  // 从历史记录移除
  void removeFromPlayHistory(String videoId) {
    final history = _prefs.getStringList(_playHistoryKey) ?? [];
    final updatedHistory = history.where((item) {
      try {
        final itemMap = json.decode(item);
        return itemMap['id'] != videoId;
      } catch (e) {
        return false;
      }
    }).toList();

    _prefs.setStringList(_playHistoryKey, updatedHistory);
  }

  // 清空历史记录
  void clearPlayHistory() {
    _prefs.setStringList(_playHistoryKey, []);
  }

  // 获取收藏列表
  List<VideoItem> getFavorites() {
    try {
      final favoriteList = _prefs.getStringList(_favoriteKey) ?? [];

      final List<VideoItem> favorites = [];
      for (final item in favoriteList) {
        try {
          final Map<String, dynamic> videoJson = json.decode(item);
          final video = VideoItem(
            id: videoJson['id'],
            title: videoJson['title'],
            uploader: videoJson['uploader'],
            uploaderId: videoJson['uploaderId'] ?? '',
            thumbnail: videoJson['thumbnail'],
            playCount: videoJson['playCount'],
            duration: videoJson['duration'],
            publishDate: videoJson['publishDate'] ?? '',
          );
          favorites.add(video);
        } catch (e) {
          debugPrint('解析收藏列表项失败: $e');
        }
      }

      return favorites;
    } catch (e) {
      debugPrint('获取收藏列表失败: $e');
      return [];
    }
  }

  // 添加到收藏
  Future<bool> addToFavorites(VideoItem video) async {
    try {
      final favorites = _prefs.getStringList(_favoriteKey) ?? [];

      // 检查是否已存在
      final videoJson = json.encode(video.toJson());
      if (!favorites.contains(videoJson)) {
        favorites.add(videoJson);
        await _prefs.setStringList(_favoriteKey, favorites);
      }

      return true;
    } catch (e) {
      debugPrint('添加收藏失败: $e');
      return false;
    }
  }

  // 从收藏中移除
  Future<bool> removeFromFavorites(String videoId) async {
    try {
      final favorites = _prefs.getStringList(_favoriteKey) ?? [];

      final updatedFavorites = favorites.where((item) {
        try {
          final itemMap = json.decode(item);
          return itemMap['id'] != videoId;
        } catch (e) {
          return false;
        }
      }).toList();

      await _prefs.setStringList(_favoriteKey, updatedFavorites);
      return true;
    } catch (e) {
      debugPrint('移除收藏失败: $e');
      return false;
    }
  }

  // 检查是否已收藏
  bool isFavorite(String videoId) {
    try {
      String favoritesJson = _prefs.getString(_favoriteKey) ?? '[]';
      List<dynamic> favorites = jsonDecode(favoritesJson);

      return favorites.any((item) => item['id'] == videoId);
    } catch (e) {
      debugPrint('检查收藏状态失败: $e');
      return false;
    }
  }

  // 辅助函数：格式化时长
  String _formatDuration(double duration) {
    if (duration.isFinite) {
      int minutes = duration.floor() ~/ 60;
      int remainingSeconds = (duration.floor() % 60).round();
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '00:00';
  }

  // 辅助函数：格式化日期
  String _formatDate(int timestamp) {
    if (timestamp > 0) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  // 使用浏览器Cookie登录
  Future<bool> loginWithBrowser(String cookieString) async {
    try {
      debugPrint('使用浏览器Cookie登录');

      // 提取CSRF令牌
      final csrfMatch = RegExp(r'bili_jct=([^;]+)').firstMatch(cookieString);
      if (csrfMatch != null) {
        final csrf = csrfMatch.group(1);
        await _prefs.setString(_csrfKey, csrf ?? '');
        debugPrint('保存CSRF令牌');
      }

      // 保存Cookie
      await _prefs.setString(_cookieKey, cookieString);
      _dio.options.headers['Cookie'] = cookieString;

      // 检查登录状态
      final isLoggedIn = await checkLogin();
      return isLoggedIn;
    } catch (e) {
      debugPrint('浏览器登录失败: $e');
      return false;
    }
  }

  // 获取用户信息
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final isLoggedIn = await checkLogin();

      if (!isLoggedIn) {
        return {
          'isLogin': false,
          'username': '',
          'avatar': '',
        };
      }

      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/nav',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final data = response.data['data'];

        return {
          'isLogin': true,
          'username': data['uname'] ?? '',
          'avatar': data['face'] ?? '',
          'uid': data['mid']?.toString() ?? '',
          'isVip': data['vipStatus'] == 1,
          'level': data['level'] ?? 0,
        };
      }

      return {
        'isLogin': false,
        'username': '',
        'avatar': '',
      };
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return {
        'isLogin': false,
        'username': '',
        'avatar': '',
        'error': e.toString(),
      };
    }
  }

  // 获取热门推荐
  Future<List<VideoItem>> getHotRecommendations() async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {
        'ps': 20, // 每页数量
        'pn': 1, // 页码
      };

      // 发送请求
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/popular',
        queryParameters: params,
      );

      // 检查响应
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;

        // 检查API返回的状态码
        if (data['code'] == 0 && data['data'] != null) {
          final List<dynamic> items = data['data']['list'] ?? [];

          // 解析视频项
          final List<VideoItem> videos = [];
          for (var item in items) {
            try {
              final video = VideoItem.fromJson(item);
              videos.add(video);
            } catch (e) {
              debugPrint('解析热门视频失败: $e');
            }
          }

          return videos;
        }
      }

      return [];
    } catch (e) {
      debugPrint('获取热门推荐失败: $e');
      return [];
    }
  }
}
