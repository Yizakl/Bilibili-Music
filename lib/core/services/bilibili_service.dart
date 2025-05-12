import 'package:dio/dio.dart';
import '../../features/player/models/audio_item.dart' as player_models;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/video_item.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class BilibiliService extends ChangeNotifier {
  final Dio _dio;
  final _logger = Logger('BilibiliService');
  final _apiBaseUrl = 'https://api.bilibili.com';
  late SharedPreferences _prefs;

  // API地址
  static const String _mir6ApiBaseUrl = 'https://api.mir6.com/api/bzjiexi';

  // 本地存储键
  static const String _playHistoryKey = 'play_history';
  static const String _favoriteKey = 'favorites';
  static const String _searchHistoryKey = 'search_history';
  static const String _csrfKey = 'bili_csrf';
  static const String _cookieKey = 'bili_cookie';

  // Cookie相关常量
  static const String _sessdataKey = 'sessdata';
  static const String _biliJctKey = 'bili_jct';
  static const String _dedeUserIDKey = 'dede_user_id';
  static const String _userNameKey = 'user_name';
  static const String _userAvatarKey = 'user_avatar';

  BilibiliService(this._prefs) : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _initDio();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCookies();
  }

  void _loadCookies() {
    final sessdata = _prefs.getString(_sessdataKey);
    final biliJct = _prefs.getString(_biliJctKey);
    final dedeUserID = _prefs.getString(_dedeUserIDKey);

    if (sessdata != null && biliJct != null && dedeUserID != null) {
      _dio.options.headers['Cookie'] =
          'SESSDATA=$sessdata; bili_jct=$biliJct; DedeUserID=$dedeUserID';
    }
  }

  Future<void> saveCookies({
    required String sessdata,
    required String biliJct,
    required String dedeUserID,
    String? userName,
    String? userAvatar,
  }) async {
    await _prefs.setString(_sessdataKey, sessdata);
    await _prefs.setString(_biliJctKey, biliJct);
    await _prefs.setString(_dedeUserIDKey, dedeUserID);
    if (userName != null) {
      await _prefs.setString(_userNameKey, userName);
    }
    if (userAvatar != null) {
      await _prefs.setString(_userAvatarKey, userAvatar);
    }
    _dio.options.headers['Cookie'] =
        'SESSDATA=$sessdata; bili_jct=$biliJct; DedeUserID=$dedeUserID';
    notifyListeners();
  }

  Future<void> clearCookies() async {
    await _prefs.remove(_sessdataKey);
    await _prefs.remove(_biliJctKey);
    await _prefs.remove(_dedeUserIDKey);
    await _prefs.remove(_userNameKey);
    await _prefs.remove(_userAvatarKey);
    _dio.options.headers.remove('Cookie');
    notifyListeners();
  }

  Future<Map<String, String?>> getSavedCookies() async {
    return {
      'sessdata': _prefs.getString(_sessdataKey),
      'bili_jct': _prefs.getString(_biliJctKey),
      'dede_user_id': _prefs.getString(_dedeUserIDKey),
      'user_name': _prefs.getString(_userNameKey),
      'user_avatar': _prefs.getString(_userAvatarKey),
    };
  }

  Future<bool> isLoggedIn() async {
    final cookies = await getSavedCookies();
    return cookies['sessdata'] != null &&
        cookies['bili_jct'] != null &&
        cookies['dede_user_id'] != null;
  }

  void _initDio() {
    _dio.options.baseUrl = _apiBaseUrl;
    _dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': 'https://www.bilibili.com',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Origin': 'https://www.bilibili.com',
    };

    // 添加日志拦截器
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
          logPrint: (object) => debugPrint('BilibiliService: $object'),
        ),
      );
    }

    // 添加错误处理拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.queryParameters['t'] = DateTime.now().millisecondsSinceEpoch;
          return handler.next(options);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          debugPrint('BilibiliService请求错误: ${e.message}');
          debugPrint('请求URL: ${e.requestOptions.uri}');
          if (e.response != null) {
            debugPrint('响应状态码: ${e.response?.statusCode}');
            debugPrint('响应数据: ${e.response?.data}');
          }
          return handler.next(e);
        },
      ),
    );
  }

  // 搜索视频
  Future<List<VideoItem>> searchVideos(String keyword) async {
    try {
      // 生成随机buvid和uuid
      final buvid = _generateRandomBuvid();
      final uuid = _generateRandomUuid();

      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/search/all/v2',
        queryParameters: {
          'keyword': keyword,
          'page': 1,
          'page_size': 20,
          't': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com',
            'Origin': 'https://www.bilibili.com',
            'Cookie': 'buvid3=$buvid; _uuid=$uuid;',
            'Accept': 'application/json, text/plain, */*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final List<dynamic> results = response.data['data']['result'];
        final List<VideoItem> videos = [];

        for (var result in results) {
          if (result['result_type'] == 'video') {
            for (var video in result['data']) {
              videos.add(VideoItem.fromJson(video));
            }
          }
        }

        return videos;
      }
      return [];
    } catch (e) {
      debugPrint('搜索视频失败: $e');
      return [];
    }
  }

  // 生成随机buvid
  String _generateRandomBuvid() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // 生成随机uuid
  String _generateRandomUuid() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // 辅助方法：移除HTML标签
  String _removeHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  // 辅助方法：格式化搜索结果的时长
  String _formatSearchDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 辅助方法：格式化播放量
  String _formatPlayCount(String count) {
    try {
      final num numCount = num.parse(count.replaceAll(',', ''));
      if (numCount >= 10000) {
        return '${(numCount / 10000).toStringAsFixed(1)}万';
      } else {
        return count;
      }
    } catch (e) {
      return count;
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

  // 获取音频URL (优先使用解析API)
  Future<String> getAudioUrl(String videoId) async {
    try {
      if (videoId.isEmpty) {
        debugPrint('视频ID为空，无法获取音频URL');
        return '';
      }

      debugPrint('开始获取音频URL: $videoId (尝试多种API)');

      // 尝试第一种解析API
      final result1 = await getAudioUrlWithMir6Api(videoId);
      if (result1 != null && result1.isNotEmpty) {
        debugPrint('成功获取解析API音频URL (方式1)');
        return result1;
      }

      // 尝试第二种解析API
      String result2 = await getAudioUrlWithBackupApi(videoId);
      if (result2.isNotEmpty) {
        debugPrint('成功获取解析API音频URL (方式2)');
        return result2;
      }

      // 如果解析API都失败，尝试使用官方API作为备选
      debugPrint('解析API失败，尝试使用官方API获取音频URL');
      String nativeResult = await _getAudioUrlWithNativeApi(videoId);
      if (nativeResult.isNotEmpty) {
        debugPrint('成功通过官方API获取音频URL');
        return nativeResult;
      }

      // 都失败了，返回空字符串
      debugPrint('所有方法获取音频URL都失败，请检查网络连接或更新API');
      return '';
    } catch (e) {
      debugPrint('获取音频URL过程中发生异常: $e');
      return '';
    }
  }

  // 使用B站官方API获取音频URL
  Future<String> _getAudioUrlWithNativeApi(String videoId) async {
    try {
      if (videoId.isEmpty) {
        return '';
      }

      // 标准化视频ID
      String standardizedId = videoId;
      if (!videoId.startsWith('BV') && !videoId.startsWith('av')) {
        standardizedId = 'BV$videoId';
      }

      debugPrint('使用官方API获取音频URL，视频ID: $standardizedId');

      // 步骤1: 获取视频详情以获取cid
      final dio = Dio()
        ..options.connectTimeout = const Duration(seconds: 15)
        ..options.receiveTimeout = const Duration(seconds: 15);

      final response = await dio.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': standardizedId},
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com',
            'Origin': 'https://www.bilibili.com',
            'Cookie':
                'buvid3=${_generateRandomBuvid()}; _uuid=${_generateRandomUuid()};',
          },
        ),
      );

      if (response.statusCode != 200 || response.data['code'] != 0) {
        debugPrint('获取视频详情失败: ${response.data['message']}');
        return '';
      }

      final String cid = response.data['data']['cid'].toString();
      debugPrint('获取到视频CID: $cid');

      // 步骤2: 获取音频流URL
      final playUrlResponse = await dio.get(
        'https://api.bilibili.com/x/player/playurl',
        queryParameters: {
          'bvid': standardizedId,
          'cid': cid,
          'fnval': '16', // 请求dash格式
          'fnver': '0',
          'fourk': '1',
        },
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com/video/$standardizedId',
            'Origin': 'https://www.bilibili.com',
            'Cookie':
                'buvid3=${_generateRandomBuvid()}; _uuid=${_generateRandomUuid()};',
          },
        ),
      );

      if (playUrlResponse.statusCode != 200 ||
          playUrlResponse.data['code'] != 0) {
        debugPrint('获取音频URL失败: ${playUrlResponse.data['message']}');
        return '';
      }

      // 步骤3: 从dash格式中提取音频流URL
      final dashData = playUrlResponse.data['data']['dash'];
      if (dashData == null ||
          dashData['audio'] == null ||
          dashData['audio'].isEmpty) {
        debugPrint('未找到音频流');

        // 尝试备用方法：从非dash格式中获取
        if (playUrlResponse.data['data']['durl'] != null &&
            playUrlResponse.data['data']['durl'].isNotEmpty) {
          final String backupUrl =
              playUrlResponse.data['data']['durl'][0]['url'];
          debugPrint('使用备用方法获取到URL');
          return backupUrl;
        }

        return '';
      }

      // 获取码率最高的音频
      final List<dynamic> audioList = dashData['audio'];
      audioList.sort(
        (a, b) => (b['bandwidth'] ?? 0).compareTo(a['bandwidth'] ?? 0),
      );

      final String audioUrl = audioList.first['baseUrl'] ?? '';
      debugPrint(
          '获取到音频URL: ${audioUrl.length > 50 ? audioUrl.substring(0, 50) + "..." : audioUrl}');

      return audioUrl;
    } catch (e) {
      debugPrint('使用官方API获取音频URL失败: $e');
      return '';
    }
  }

  // 使用mir6 API获取音频URL
  Future<String?> getAudioUrlWithMir6Api(String videoId) async {
    try {
      final videoUrl = 'https://www.bilibili.com/video/$videoId';
      final apiUrl = 'https://api.mir6.com/api/bzjiexi?url=$videoUrl&type=json';

      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null && data['data'].isNotEmpty) {
          final videoUrl = data['data'][0]['video_url'];
          if (videoUrl != null && videoUrl.isNotEmpty) {
            return videoUrl;
          }
        }
      }
      return null;
    } catch (e) {
      _logger.severe('Failed to get audio URL with Mir6 API: $e');
      return null;
    }
  }

  // 使用备用API获取音频URL
  Future<String> getAudioUrlWithBackupApi(String videoId) async {
    try {
      if (videoId.isEmpty) {
        return '';
      }

      // 确保有正确的BV号格式
      String standardizedId = videoId;
      if (!videoId.startsWith('BV') && !videoId.startsWith('av')) {
        standardizedId = 'BV$videoId';
      }

      // 构造视频URL
      final videoUrl = Uri.encodeFull(
        'https://www.bilibili.com/video/$standardizedId',
      );

      // 使用另一个备用解析API
      final apiUrl = 'https://jiexi.t7g.cn/?url=$videoUrl';
      debugPrint('使用备用解析API: $apiUrl');

      return apiUrl;
    } catch (e) {
      debugPrint('构建备用API链接失败: $e');
      return '';
    }
  }

  // 丰富视频信息
  Future<player_models.AudioItem?> enrichVideoWithMir6Api(
    player_models.AudioItem audioItem,
  ) async {
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
  Future<List<VideoItem>> getPopularVideos({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      // 构建请求参数
      final Map<String, dynamic> params = {'ps': pageSize, 'pn': page};

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
  Future<List<VideoItem>> getCategoryVideos(
    int tid, {
    int page = 1,
    int pageSize = 20,
  }) async {
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
  Future<List<VideoItem>> getUploaderVideos(
    String mid, {
    int page = 1,
    int pageSize = 30,
  }) async {
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

  // 将关键词添加到搜索历史
  void _addToSearchHistory(String keyword) {
    if (keyword.isEmpty) return;

    try {
      List<String> history = _prefs.getStringList('search_history') ?? [];

      // 如果已经存在，先移除旧的
      history.remove(keyword);

      // 添加到最前面
      history.insert(0, keyword);

      // 限制历史记录数量
      if (history.length > 10) {
        history = history.sublist(0, 10);
      }

      // 保存到本地
      _prefs.setStringList('search_history', history);

      debugPrint('添加到搜索历史: $keyword，当前历史: $history');
    } catch (e) {
      debugPrint('添加搜索历史失败: $e');
    }
  }

  // 获取搜索历史
  List<String> getSearchHistory() {
    try {
      return _prefs.getStringList('search_history') ?? [];
    } catch (e) {
      debugPrint('获取搜索历史失败: $e');
      return [];
    }
  }

  // 清除搜索历史
  Future<void> clearSearchHistory() async {
    try {
      await _prefs.remove('search_history');
      debugPrint('已清除搜索历史');
    } catch (e) {
      debugPrint('清除搜索历史失败: $e');
    }
  }

  // 获取播放历史
  Future<List<VideoItem>> getPlayHistory() async {
    try {
      // 尝试从本地存储获取播放历史
      final historyJson = _prefs.getString(_playHistoryKey);
      if (historyJson == null || historyJson.isEmpty) {
        debugPrint('本地没有播放历史记录');
        return [];
      }

      try {
        final List<dynamic> historyList = json.decode(historyJson);
        final List<VideoItem> videos = [];

        for (var item in historyList) {
          try {
            final video = VideoItem.fromJson(item);
            videos.add(video);
          } catch (e) {
            debugPrint('解析历史记录项失败: $e');
            // 继续处理下一项
          }
        }

        return videos;
      } catch (e) {
        debugPrint('解析播放历史JSON失败: $e');
        // 如果解析失败，清除可能损坏的历史记录
        await _prefs.remove(_playHistoryKey);
        return [];
      }
    } catch (e) {
      debugPrint('获取播放历史失败: $e');
      return [];
    }
  }

  // 获取收藏列表
  Future<List<VideoItem>> getFavorites() async {
    try {
      // 检查登录状态
      final authCookies = _prefs.getString(_cookieKey);
      if (authCookies == null || authCookies.isEmpty) {
        return [];
      }

      // 尝试获取远程收藏
      final response = await _dio.get(
        '$_apiBaseUrl/x/v3/fav/resource/list',
        queryParameters: {
          'media_id': 'default',
          'pn': 1,
          'ps': 20,
          'keyword': '',
          'order': 'mtime',
          'type': 0,
        },
      );

      if (response.statusCode == 200 &&
          response.data['code'] == 0 &&
          response.data['data'] != null) {
        final List<dynamic> items = response.data['data']['medias'] ?? [];
        return items.map((item) => VideoItem.fromJson(item)).toList();
      }

      // 如果远程获取失败，尝试从本地获取
      final favJson = _prefs.getString(_favoriteKey);
      if (favJson == null || favJson.isEmpty) {
        return [];
      }

      final List<dynamic> favList = json.decode(favJson);
      return favList.map((json) => VideoItem.fromJson(json)).toList();
    } catch (e) {
      debugPrint('获取收藏失败: $e');

      // 如果远程获取失败，尝试从本地获取
      try {
        final favJson = _prefs.getString(_favoriteKey);
        if (favJson == null || favJson.isEmpty) {
          return [];
        }

        final List<dynamic> favList = json.decode(favJson);
        return favList.map((json) => VideoItem.fromJson(json)).toList();
      } catch (e) {
        debugPrint('获取本地收藏失败: $e');
        return [];
      }
    }
  }

  // 添加到播放历史的辅助方法
  void _addToPlayHistory(VideoItem video) async {
    try {
      final List<VideoItem> history = await getPlayHistory();

      // 移除已存在的相同视频（如果有）
      history.removeWhere((item) => item.id == video.id);

      // 添加到历史开头
      history.insert(0, video);

      // 限制历史记录数量
      final List<VideoItem> limitedHistory = history.take(100).toList();

      // 保存到本地
      final List<Map<String, dynamic>> historyJson =
          limitedHistory.map((video) => video.toJson()).toList();
      await _prefs.setString(_playHistoryKey, json.encode(historyJson));
    } catch (e) {
      debugPrint('添加到播放历史失败: $e');
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

  // 添加到收藏
  Future<bool> addToFavorites(VideoItem video) async {
    try {
      String favoritesJson = _prefs.getString(_favoriteKey) ?? '[]';
      List<dynamic> favorites = jsonDecode(favoritesJson);

      // 检查是否已存在
      if (!favorites.any((item) => item['id'] == video.id)) {
        favorites.add(video.toJson());
        await _prefs.setString(_favoriteKey, jsonEncode(favorites));
        notifyListeners();
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
      String favoritesJson = _prefs.getString(_favoriteKey) ?? '[]';
      List<dynamic> favorites = jsonDecode(favoritesJson);

      favorites.removeWhere((item) => item['id'] == videoId);
      await _prefs.setString(_favoriteKey, jsonEncode(favorites));
      notifyListeners();
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
        return {'isLogin': false, 'username': '', 'avatar': ''};
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

      return {'isLogin': false, 'username': '', 'avatar': ''};
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

  Future<bool> checkLogin() async {
    try {
      final response = await _dio.get('$_apiBaseUrl/x/web-interface/nav');
      final data = response.data;
      return data['code'] == 0 && data['data']['isLogin'] == true;
    } catch (e) {
      debugPrint('检查登录状态失败: $e');
      return false;
    }
  }

  // 使用Cookie登录
  Future<bool> loginWithCookies(
      String sessdata, String biliJct, String dedeUserID) async {
    try {
      // 设置Cookie
      _dio.options.headers['Cookie'] =
          'SESSDATA=$sessdata; bili_jct=$biliJct; DedeUserID=$dedeUserID';

      // 验证登录状态
      final response = await _dio.get('$_apiBaseUrl/x/web-interface/nav');

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final userData = response.data['data'];
        if (userData['isLogin'] == true) {
          _logger.info('登录成功: ${userData['uname']}');

          // 保存Cookie和用户信息
          await saveCookies(
            sessdata: sessdata,
            biliJct: biliJct,
            dedeUserID: dedeUserID,
            userName: userData['uname'],
            userAvatar: userData['face'],
          );

          return true;
        }
      }

      _logger.warning('登录失败: ${response.data['message']}');
      return false;
    } catch (e) {
      _logger.severe('登录出错: $e');
      return false;
    }
  }

  // 获取登录二维码
  Future<Map<String, String>> getQRCode() async {
    try {
      final response =
          await _dio.get('$_apiBaseUrl/x/passport-login/web/qrcode/generate');

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final data = response.data['data'];
        return {
          'url': data['url'],
          'key': data['qrcode_key'],
        };
      }

      throw Exception('获取二维码失败: ${response.data['message']}');
    } catch (e) {
      _logger.severe('获取二维码失败: $e');
      rethrow;
    }
  }

  // 检查二维码状态
  Future<Map<String, dynamic>> checkQRCodeStatus(String qrcodeKey) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/x/passport-login/web/qrcode/poll',
        queryParameters: {'qrcode_key': qrcodeKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0) {
          final status = data['data']['code'];
          if (status == 0) {
            // 登录成功，获取Cookie
            final cookies = data['data']['cookie_info']['cookies'];
            final cookieMap = {
              for (var cookie in cookies) cookie['name']: cookie['value']
            };

            // 保存Cookie
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('sessdata', cookieMap['SESSDATA'] ?? '');
            await prefs.setString('bili_jct', cookieMap['bili_jct'] ?? '');
            await prefs.setString(
                'dede_user_id', cookieMap['DedeUserID'] ?? '');

            // 设置Dio的Cookie
            _dio.options.headers['Cookie'] =
                cookies.map((c) => '${c['name']}=${c['value']}').join('; ');

            return {'status': true, 'message': '登录成功'};
          } else if (status == 86038) {
            return {'status': false, 'message': '二维码已失效'};
          } else if (status == 86090) {
            return {'status': false, 'message': '二维码已扫码，请在手机上确认'};
          } else if (status == 86101) {
            return {'status': false, 'message': '未扫码'};
          }
        }
      }

      return {'status': false, 'message': '未知状态'};
    } catch (e) {
      _logger.severe('检查二维码状态失败: $e');
      return {'status': false, 'message': '检查失败: $e'};
    }
  }
}

class _searchHistoryKey {}
