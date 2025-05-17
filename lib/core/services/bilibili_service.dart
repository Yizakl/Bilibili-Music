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

  BilibiliService({SharedPreferences? prefs})
      : _prefs = prefs ?? (throw ArgumentError('SharedPreferences 不能为空')),
        _dio = Dio() {
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
        try {
          final data = response.data['data'];
          if (data == null) {
            debugPrint('搜索API返回数据为空');
            return [];
          }

          // 处理搜索结果格式的可能变化
          List<dynamic> results = [];
          if (data['result'] != null && data['result'] is List) {
            results = data['result'];
          } else if (data['results'] != null && data['results'] is List) {
            results = data['results'];
          } else if (data['items'] != null && data['items'] is List) {
            results = data['items'];
          } else {
            debugPrint('未找到有效的搜索结果列表');
            return [];
          }

          final List<VideoItem> videos = [];

          for (var result in results) {
            try {
              // 检查不同的结果类型格式
              if (result['result_type'] == 'video' && result['data'] is List) {
                for (var video in result['data']) {
                  try {
                    // 预处理视频数据以确保格式一致
                    final processedVideo = _preprocessVideoData(video);
                    videos.add(VideoItem.fromJson(processedVideo));
                  } catch (e) {
                    debugPrint('解析搜索结果视频失败: $e');
                    // 继续处理下一个视频
                  }
                }
              }
              // 直接检查是否是视频数据
              else if ((result['type'] == 'video' ||
                      result['source_type'] == 'video') &&
                  result['title'] != null) {
                try {
                  // 预处理视频数据以确保格式一致
                  final processedVideo = _preprocessVideoData(result);
                  videos.add(VideoItem.fromJson(processedVideo));
                } catch (e) {
                  debugPrint('解析单个视频搜索结果失败: $e');
                }
              }
            } catch (e) {
              debugPrint('处理搜索结果项失败: $e');
              // 继续处理下一项
            }
          }

          return videos;
        } catch (e) {
          debugPrint('解析搜索响应失败: $e');
          return [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('搜索视频失败: $e');
      return [];
    }
  }

  // 预处理视频数据，确保格式一致
  Map<String, dynamic> _preprocessVideoData(Map<String, dynamic> video) {
    // 处理可能导致类型错误的字段
    Map<String, dynamic> processedVideo = Map.from(video);

    // 确保duration是整数
    if (processedVideo['duration'] != null) {
      if (processedVideo['duration'] is String) {
        // 尝试将时长字符串转为秒数，比如 "12:34" -> 754
        try {
          String durationStr = processedVideo['duration'];
          if (durationStr.contains(':')) {
            List<String> parts = durationStr.split(':');
            if (parts.length == 2) {
              int minutes = int.tryParse(parts[0]) ?? 0;
              int seconds = int.tryParse(parts[1]) ?? 0;
              processedVideo['duration'] = minutes * 60 + seconds;
            }
          } else {
            processedVideo['duration'] = int.tryParse(durationStr) ?? 0;
          }
        } catch (e) {
          processedVideo['duration'] = 0;
        }
      }
    } else {
      processedVideo['duration'] = 0;
    }

    // 确保pubdate是整数
    if (processedVideo['pubdate'] != null) {
      if (processedVideo['pubdate'] is String) {
        processedVideo['pubdate'] =
            int.tryParse(processedVideo['pubdate']) ?? 0;
      }
    } else {
      processedVideo['pubdate'] = 0;
    }

    // 确保stat字段存在
    if (processedVideo['stat'] == null) {
      processedVideo['stat'] = {'view': 0, 'like': 0, 'reply': 0};
    }

    // 处理可能的播放量、点赞量、评论量为字符串的情况
    if (processedVideo['stat'] != null) {
      var stat = processedVideo['stat'];
      if (stat is Map) {
        if (stat['view'] is String) {
          stat['view'] = int.tryParse(stat['view']) ?? 0;
        }
        if (stat['like'] is String) {
          stat['like'] = int.tryParse(stat['like']) ?? 0;
        }
        if (stat['reply'] is String) {
          stat['reply'] = int.tryParse(stat['reply']) ?? 0;
        }
      }
    }

    return processedVideo;
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

  // 获取视频详细信息
  Future<VideoItem?> getVideoDetails(String bvid) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/view',
        queryParameters: {
          'bvid': bvid,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final videoData = response.data['data'];
        return VideoItem(
          id: bvid,
          bvid: bvid,
          title: videoData['title'] ?? '',
          uploader: videoData['owner']['name'] ?? '',
          thumbnail: videoData['pic'] ?? '',
          duration: Duration(seconds: videoData['duration'] ?? 0),
          uploadTime: DateTime.fromMillisecondsSinceEpoch(
            videoData['pubdate'] * 1000,
          ),
          viewCount: videoData['stat']['view'] ?? 0,
          likeCount: videoData['stat']['like'] ?? 0,
          commentCount: videoData['stat']['reply'] ?? 0,
          cid: videoData['cid']?.toString(),
        );
      }
      return null;
    } catch (e) {
      debugPrint('获取视频详情失败: $e');
      return null;
    }
  }

  // 获取视频播放地址
  Future<String> getVideoPlayUrl(String bvid) async {
    try {
      // 使用 mir6 解析接口获取视频播放地址
      final response = await _dio.get(
        _mir6ApiBaseUrl,
        queryParameters: {
          'url': 'https://www.bilibili.com/video/$bvid',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 200 && data['data'] != null) {
          // 返回第一个可用的视频播放地址
          final videoUrl = data['data']['url'];
          if (videoUrl is String && videoUrl.isNotEmpty) {
            return videoUrl;
          }
        }
      }

      throw Exception('无法获取视频播放地址');
    } catch (e) {
      debugPrint('获取视频播放地址失败: $e');
      throw Exception('获取视频播放地址失败: $e');
    }
  }

  // 获取热门视频推荐（主要方法）
  Future<List<VideoItem>> getPopularVideos({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/popular',
        queryParameters: {
          'pn': page,
          'ps': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final List<dynamic> list = response.data['data']['list'];
        return list.map((item) {
          return VideoItem(
            id: item['bvid'] ?? '',
            bvid: item['bvid'] ?? '',
            title: item['title'] ?? '',
            uploader: item['owner']['name'] ?? '',
            thumbnail: item['pic'] ?? '',
            duration: Duration(seconds: item['duration'] ?? 0),
            uploadTime: DateTime.fromMillisecondsSinceEpoch(
              item['pubdate'] * 1000,
            ),
            viewCount: item['stat']['view'] ?? 0,
            likeCount: item['stat']['like'] ?? 0,
            commentCount: item['stat']['reply'] ?? 0,
            cid: item['cid']?.toString(),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取热门视频失败: $e');
      return [];
    }
  }

  // 获取分区热门视频
  Future<List<VideoItem>> getRegionPopularVideos(
    int tid, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/x/web-interface/ranking/region',
        queryParameters: {
          'rid': tid, // 分区ID
          'day': 3, // 3天内热门
          'pn': page,
          'ps': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 0) {
        final List<dynamic> list = response.data['data'];
        return list.map((item) {
          return VideoItem(
            id: item['bvid'] ?? '',
            bvid: item['bvid'] ?? '',
            title: item['title'] ?? '',
            uploader: item['owner']['name'] ?? '',
            thumbnail: item['pic'] ?? '',
            duration: Duration(seconds: item['duration'] ?? 0),
            uploadTime: DateTime.fromMillisecondsSinceEpoch(
              item['create'] * 1000,
            ),
            viewCount: item['play'] ?? 0,
            likeCount: item['like'] ?? 0,
            commentCount: item['video_review'] ?? 0,
            cid: item['cid']?.toString(),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取分区热门视频失败: $e');
      return [];
    }
  }

  // 分区ID常量
  static const Map<String, int> regionTids = {
    '音乐': 3, // 音乐分区
    '舞蹈': 129, // 舞蹈分区
    '游戏': 4, // 游戏分区
    '动画': 1, // 动画分区
    '娱乐': 5, // 娱乐分区
  };

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

  // 获取音频URL的增强方法，增加错误处理和日志
  Future<String> getAudioUrl(String bvid, {String? cid}) async {
    try {
      // 记录开始获取音频URL的日志
      _logger.info('开始获取音频URL: bvid=$bvid, cid=$cid');

      // 如果没有提供cid，尝试获取
      if (cid == null || cid.isEmpty) {
        final videoInfo = await getVideoInfo(bvid);
        if (videoInfo != null && videoInfo.cid != null) {
          cid = videoInfo.cid!;
        }
      }

      if (cid == null || cid.isEmpty) {
        _logger.warning('无法获取视频的CID: bvid=$bvid');
        throw Exception('无法获取视频的CID');
      }

      // 尝试多种获取音频URL的方法
      final methods = [
        () => _getAudioUrlFromMir6Api(bvid, cid!),
        () => _getAudioUrlFromBilibiliApi(bvid, cid!),
      ];

      for (var method in methods) {
        try {
          final audioUrl = await method();
          if (audioUrl != null && audioUrl.isNotEmpty) {
            _logger.info('成功获取音频URL: $audioUrl');
            return audioUrl;
          }
        } catch (e) {
          _logger.warning('音频URL获取方法失败: $e');
        }
      }

      _logger.warning('所有音频URL获取方法均失败');
      throw Exception('无法获取音频URL');
    } catch (e) {
      _logger.warning('获取音频URL时发生错误: $e');
      rethrow;
    }
  }

  // 从Mir6 API获取音频URL的私有方法
  Future<String?> _getAudioUrlFromMir6Api(String bvid, String cid) async {
    try {
      final response = await _dio.get(
        '$_mir6ApiBaseUrl/audio',
        queryParameters: {'bvid': bvid, 'cid': cid},
      );

      if (response.statusCode == 200 && response.data is String) {
        return response.data;
      }
      return null;
    } catch (e) {
      _logger.warning('Mir6 API获取音频URL失败: $e');
      return null;
    }
  }

  // 从Bilibili API获取音频URL的私有方法
  Future<String?> _getAudioUrlFromBilibiliApi(String bvid, String cid) async {
    try {
      // 实现从Bilibili API获取音频URL的逻辑
      // 这里需要根据实际的Bilibili API文档和要求实现
      return null;
    } catch (e) {
      _logger.warning('Bilibili API获取音频URL失败: $e');
      return null;
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
                bvid: video['bvid'] ?? 'av${video['aid']}',
                title: video['title'] ?? '未知标题',
                uploader: video['author'] ?? '未知UP主',
                thumbnail: video['pic'] ?? '',
                duration: Duration(
                    seconds:
                        int.tryParse(video['length']?.toString() ?? '0') ?? 0),
                uploadTime: DateTime.fromMillisecondsSinceEpoch(
                    (video['created'] ?? 0) * 1000),
                viewCount: video['play'] ?? 0,
                likeCount: video['like'] ?? 0,
                commentCount: video['comment'] ?? 0,
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
      final String? historyJson = _prefs.getString(_playHistoryKey);
      if (historyJson == null || historyJson.isEmpty) {
        return [];
      }

      final List<dynamic> historyList = json.decode(historyJson);
      final List<VideoItem> history = [];

      for (var item in historyList) {
        try {
          history.add(VideoItem.fromJson(item));
        } catch (e) {
          debugPrint('解析历史记录项失败: $e');
          // 继续处理下一项
        }
      }

      return history;
    } catch (e) {
      debugPrint('获取播放历史失败: $e');
      // 如果获取失败，清除可能已损坏的历史记录
      await _prefs.remove(_playHistoryKey);
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

  // 获取视频分P信息
  Future<List<VideoItem>> getVideoParts(String bvid) async {
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid},
        options: Options(
          headers: _getHeaders(),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data['pages'] != null) {
          final List<dynamic> pages = data['pages'];
          return pages.map((page) {
            return VideoItem(
              id: '${bvid}_${page['cid']}',
              bvid: bvid,
              title: '${data['title']} - ${page['part']}',
              uploader: data['owner']['name'],
              thumbnail: data['pic'],
              duration: Duration(seconds: page['duration']),
              uploadTime:
                  DateTime.fromMillisecondsSinceEpoch(data['pubdate'] * 1000),
              viewCount: data['stat']['view'],
              likeCount: data['stat']['like'],
              commentCount: data['stat']['reply'],
              cid: page['cid'].toString(),
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('获取视频分P失败: $e');
      return [];
    }
  }

  // 获取热门榜
  Future<List<VideoItem>> getHotVideos() async {
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/popular',
        options: Options(
          headers: _getHeaders(),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> videos = response.data['data']['list'];
        return videos.map((video) {
          return VideoItem(
            id: video['bvid'],
            bvid: video['bvid'],
            title: video['title'],
            uploader: video['owner']['name'],
            thumbnail: video['pic'],
            duration: Duration(seconds: video['duration']),
            uploadTime:
                DateTime.fromMillisecondsSinceEpoch(video['pubdate'] * 1000),
            viewCount: video['stat']['view'],
            likeCount: video['stat']['like'],
            commentCount: video['stat']['reply'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取热门榜失败: $e');
      return [];
    }
  }

  // 获取视频信息
  Future<VideoItem?> getVideoInfo(String bvid) async {
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid},
        options: Options(
          headers: _getHeaders(),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null && data['pages'] != null) {
          final List<dynamic> pages = data['pages'];
          if (pages.isNotEmpty) {
            final page = pages[0];
            return VideoItem(
              id: '${bvid}_${page['cid']}',
              bvid: bvid,
              title: '${data['title']} - ${page['part']}',
              uploader: data['owner']['name'],
              thumbnail: data['pic'],
              duration: Duration(seconds: page['duration']),
              uploadTime:
                  DateTime.fromMillisecondsSinceEpoch(data['pubdate'] * 1000),
              viewCount: data['stat']['view'],
              likeCount: data['stat']['like'],
              commentCount: data['stat']['reply'],
              cid: page['cid'].toString(),
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('获取视频信息失败: $e');
      return null;
    }
  }

  Map<String, String> _getHeaders() {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': 'https://www.bilibili.com',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Origin': 'https://www.bilibili.com',
    };
  }

  // 使用备用API获取音频URL
  Future<String?> getAudioUrlByMir6Api(String bvid) async {
    try {
      final apiUrl = Uri.parse(
          'https://api.mir6.com/api/bzjiexi?url=https://www.bilibili.com/video/$bvid/&type=json');

      final response = await Dio().get(
        apiUrl.toString(),
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com/',
            'Accept': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );

      debugPrint('备用API响应: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null && data['data'][0] != null) {
          final videoUrl = data['data'][0]['video_url'];
          if (videoUrl != null && videoUrl.isNotEmpty) {
            debugPrint('成功获取备用音频URL: $videoUrl');
            return videoUrl;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('备用API获取音频URL失败: $e');
      return null;
    }
  }
}

class _searchHistoryKey {}
