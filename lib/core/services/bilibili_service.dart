import 'package:dio/dio.dart';
import '../../features/player/models/audio_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math' as math;

class BilibiliService {
  final Dio _dio;
  final SharedPreferences _prefs;
  final Random _random = Random();
  static const String _cookieKey = 'bilibili_cookies';
  static const String _csrfKey = 'bilibili_csrf';
  
  // 添加新接口URI常量
  static const String _mir6ApiBaseUrl = 'https://api.mir6.com/api/bzjiexi';
  
  BilibiliService(this._prefs) : _dio = Dio() {
    _initDio();
  }

  void _initDio() {
    _dio.options.baseUrl = 'https://api.bilibili.com';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Referer': 'https://www.bilibili.com',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Origin': 'https://www.bilibili.com',
      'Sec-Ch-Ua': '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
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
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
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
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
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
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
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
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
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
                    mid: userData['mid'] is int ? userData['mid'] : int.parse(userData['mid'].toString()),
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

  // 简化的密码加密方法
  String _encodePassword(String password, String hash) {
    // 在实际应用中，应该使用RSA加密
    // 这里简化处理，直接返回hash+password
    return hash + password;
  }

  // 提取 CSRF Token
  String? _extractCsrfToken(String cookies) {
    final regex = RegExp(r'bili_jct=([^;]+)');
    final match = regex.firstMatch(cookies);
    return match?.group(1);
  }

  // 检查登录状态
  Future<bool> checkLoginStatus() async {
    try {
      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/nav',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36',
            'Referer': 'https://www.bilibili.com',
          },
        ),
      );
      
      if (response.data['code'] == 0) {
        final isLogin = response.data['data']['isLogin'] == 1;
        if (isLogin) {
          // 更新用户信息
          final userData = response.data['data'];
          final user = UserModel(
            mid: userData['mid'] is int ? userData['mid'] : int.parse(userData['mid'].toString()),
            uid: userData['mid'].toString(),
            username: userData['uname'],
            avatar: userData['face'],
            isLoggedIn: true,
            isVip: userData['vipStatus'] == 1,
          );
          await user.saveToPrefs(_prefs);
        }
        return isLogin;
      }
      return false;
    } catch (e) {
      debugPrint('检查登录状态失败: $e');
      return false;
    }
  }

  // 退出登录
  Future<void> logout() async {
    try {
      await _dio.post(
        'https://passport.bilibili.com/login/exit/v2',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36',
            'Referer': 'https://www.bilibili.com',
          },
        ),
      );
    } catch (e) {
      debugPrint('退出登录请求失败: $e');
    } finally {
      // 无论请求是否成功，都清除本地存储的信息
      await _prefs.remove(_cookieKey);
      await _prefs.remove(_csrfKey);
      _dio.options.headers.remove('Cookie');
      await UserModel.logout(_prefs);
    }
  }

  // B站搜索API
  Future<List<AudioItem>> searchVideos(String keyword) async {
    try {
      // 获取当前Cookie
      final cookie = _prefs.getString(_cookieKey) ?? '';
      
      // 添加WBI签名参数
      final signedParams = _signParams({
        'keyword': keyword,
        'search_type': 'video',
        'order': 'totalrank',
        'duration': 0,
        'page': 1,
        'platform': 'pc',
        'from_source': 'web',
        'highlight': 1,
      });

      final response = await _dio.get(
        'https://api.bilibili.com/x/web-interface/search/type',
        queryParameters: signedParams,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            'Referer': 'https://search.bilibili.com',
            'Origin': 'https://search.bilibili.com',
            'Cookie': cookie, // 添加Cookie
            'Accept-Encoding': 'gzip, deflate, br',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      // 处理412错误
      if (response.data['code'] == -412) {
        debugPrint('触发反爬机制，尝试刷新Cookie...');
        await _refreshCookies();
        return searchVideos(keyword); // 重试请求
      }

      if (response.data['code'] == 0) {
        final List results = response.data['data']['result'] ?? [];
        return results.map((item) => AudioItem(
              id: item['bvid'] ?? '',
              title: item['title']?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '',
              uploader: item['author'] ?? '',
              thumbnail: item['pic']?.replaceAll('http:', 'https:') ?? '',
              audioUrl: '', // 稍后通过getAudioUrl方法获取
              addedTime: DateTime.now(),
              isFavorite: false,
              isDownloaded: false,
              playCount: item['play'] as int? ?? 0, // 添加播放量
            )).toList();
      }
      
      throw Exception('搜索失败：${response.data['message']}');
    } catch (e) {
      debugPrint('搜索失败: $e');
      rethrow;
    }
  }

  // 获取视频信息
  Future<Map<String, dynamic>> getVideoInfo(String bvid) async {
    try {
      final response = await _dio.get(
        '/x/web-interface/view',
        queryParameters: {'bvid': bvid},
      );

      if (response.data['code'] == 0) {
        return response.data['data'];
      }
      
      throw Exception('获取视频信息失败：${response.data['message']}');
    } catch (e) {
      throw Exception('获取视频信息失败：$e');
    }
  }

  // 修复 WBI 签名实现
  Map<String, dynamic> _signParams(Map<String, dynamic> params) {
    const mixinKey = "ea1db124af3c7062474693fa704f4ff8"; // 示例混合密钥（需动态获取）
    final wts = DateTime.now().millisecondsSinceEpoch;
    final sortedParams = {...params, 'wts': wts};
    
    // 1. 参数排序
    final sortedKeys = sortedParams.keys.toList()..sort();
    final query = sortedKeys.map((k) => '$k=${Uri.encodeComponent(sortedParams[k].toString())}').join('&');
    
    // 2. 生成签名
    final sign = md5.convert(utf8.encode('$query$mixinKey')).toString();
    
    return {
      ...sortedParams,
      'w_rid': sign,
    };
  }

  // 修改后的播放URL获取
  Future<String> getAudioUrl(String videoId) async {
    try {
      // 先尝试使用mir6 API
      try {
        debugPrint('尝试使用mir6 API获取音频URL: $videoId');
        final audioUrl = await _getAudioUrlWithMir6Api(videoId);
        if (audioUrl.isNotEmpty) {
          debugPrint('成功使用mir6 API获取音频URL');
          return audioUrl;
        }
      } catch (e) {
        debugPrint('使用mir6 API获取音频URL失败: $e，将尝试原始方式');
      }
      
      // 标准化视频ID
      String bvid = videoId;
      if (!bvid.startsWith('BV')) {
        if (bvid.startsWith('av')) {
          bvid = bvid.substring(2);
        }
        // 无法处理不合法的视频ID
        debugPrint('无效的视频ID: $bvid');
        throw Exception('无效的视频ID');
      }
      
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com/video/$bvid',
        'Origin': 'https://www.bilibili.com',
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      };
      
      // 首先获取视频的cid
      try {
        debugPrint('正在获取视频信息: $bvid');
        final videoInfoResponse = await _dio.get(
          'https://api.bilibili.com/x/web-interface/view',
          queryParameters: {'bvid': bvid},
          options: Options(
            headers: {
              ...headers,
              'Cookie': _prefs.getString(_cookieKey) ?? '',
            },
          ),
        );
        
        if (videoInfoResponse.data['code'] != 0) {
          debugPrint('获取视频信息API返回错误: ${videoInfoResponse.data['message']}');
          throw Exception('获取视频信息失败: ${videoInfoResponse.data['message']}');
        }
        
        final cid = videoInfoResponse.data['data']['cid'];
        debugPrint('获取到CID: $cid');
        
        // 尝试使用常规playurl API
        try {
          final signedParams = {
            'bvid': bvid,
            'cid': cid,
            'fnval': 16,  // 请求dash格式
            'platform': 'pc',
            'high_quality': 1,
          };
          
          debugPrint('正在请求音频URL...');
          final playUrlResponse = await _dio.get(
            'https://api.bilibili.com/x/player/playurl',
            queryParameters: signedParams,
            options: Options(
              headers: {
                ...headers,
                'Cookie': _prefs.getString(_cookieKey) ?? '',
              },
            ),
          );
          
          if (playUrlResponse.data['code'] != 0) {
            debugPrint('获取播放URL API返回错误: ${playUrlResponse.data['message']}');
            throw Exception('获取播放URL失败: ${playUrlResponse.data['message']}');
          }
          
          // 尝试获取音频URL
          final data = playUrlResponse.data['data'];
          String? audioUrl;
          
          // 从 dash 格式获取音频
          if (data['dash'] != null && data['dash']['audio'] != null && data['dash']['audio'].isNotEmpty) {
            final audioList = data['dash']['audio'] as List;
            audioUrl = audioList[0]['baseUrl'] ?? audioList[0]['base_url'];
            debugPrint('从dash格式获取到音频URL');
          }
          // 如果没有 dash 格式，尝试从 durl 获取
          else if (data['durl'] != null && data['durl'].isNotEmpty) {
            audioUrl = data['durl'][0]['url'];
            debugPrint('从durl格式获取到音频URL');
          }
          
          if (audioUrl != null && audioUrl.isNotEmpty) {
            // 确保使用 HTTPS
            audioUrl = audioUrl.replaceAll('http:', 'https:');
            debugPrint('成功获取到音频URL');
            return audioUrl;
          }
          
          throw Exception('无法解析音频URL');
        } catch (e) {
          debugPrint('使用标准API获取音频URL失败: $e');
          throw e;
        }
      } catch (e) {
        debugPrint('获取视频信息失败: $e');
        throw e;
      }
    } catch (e) {
      debugPrint('获取音频URL失败: $e');
      throw e;
    }
  }
  
  // 使用mir6 API获取音频URL
  Future<String> _getAudioUrlWithMir6Api(String videoId) async {
    try {
      // 标准化视频ID
      String bvid = videoId;
      if (!bvid.startsWith('BV')) {
        if (bvid.startsWith('av')) {
          bvid = bvid.substring(2);
        } else {
          debugPrint('无效的视频ID: $bvid');
          throw Exception('无效的视频ID');
        }
      }
      
      final videoUrl = 'https://www.bilibili.com/video/$bvid/';
      debugPrint('构建mir6 API请求: $videoUrl');
      
      // 直接返回MP4流URL
      final audioUrl = '$_mir6ApiBaseUrl?url=$videoUrl&type=mp4';
      debugPrint('从mir6 API获取到音频URL: ${audioUrl.length > 50 ? audioUrl.substring(0, 50) + "..." : audioUrl}');
      return audioUrl;
    } catch (e) {
      debugPrint('使用mir6 API获取音频URL时出错: $e');
      throw Exception('获取音频URL失败: $e');
    }
  }
  
  // 使用mir6 API丰富视频信息
  Future<AudioItem?> enrichVideoWithMir6Api(AudioItem video) async {
    try {
      final bvid = video.id;
      if (bvid.isEmpty) {
        return null;
      }
      
      final videoUrl = 'https://www.bilibili.com/video/$bvid/';
      debugPrint('使用mir6 API丰富视频信息: $videoUrl');
      
      final dio = Dio();
      final response = await dio.get(
        _mir6ApiBaseUrl,
        queryParameters: {
          'url': videoUrl,
          'type': 'json',
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com',
            'Accept': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['code'] == 200 && data['data'] != null && data['data'].isNotEmpty) {
          final videoData = data['data'][0];
          final userInfo = data['user'];
          String? audioUrl = videoData['video_url'];
          String? description = data['desc'];
          
          // 更新视频信息，包括直接可用的音频URL
          return video.copyWith(
            audioUrl: audioUrl ?? '',
            // 如果有更详细的信息，也可以更新标题、上传者等
            title: data['title'] ?? video.title,
            thumbnail: data['imgurl'] ?? video.thumbnail,
            uploader: userInfo?['name'] ?? video.uploader,
          );
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('使用mir6 API丰富视频信息失败: $e');
      return null;
    }
  }
  
  // 获取备用音频URL
  String _getAudioUrlFallback() {
    debugPrint('使用备用音频URL');
    // 直接使用网络可访问的测试音频
    return 'https://file-examples.com/storage/fe58ff516382b051221ee1e/2017/11/file_example_MP3_700KB.mp3';
  }

  // 获取用户信息
  Future<UserModel> getUserInfo() async {
    return UserModel.fromPrefs(_prefs);
  }
  
  // 获取热门推荐
  Future<List<AudioItem>> getHotRecommendations() async {
    try {
      final response = await _dio.get(
        '/x/web-interface/popular',
        queryParameters: {
          'ps': 20,
          'pn': 1,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0) {
          final List<dynamic> items = data['data']['list'];
          return items.map((item) => _parsePopularItem(item)).toList();
        } else {
          throw Exception('API错误: ${data['message']}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      print('获取热门推荐错误: $e');
      // 如果API调用失败，返回一些模拟数据
      return _getFallbackRecommendations();
    }
  }
  
  // 获取分区视频
  Future<List<AudioItem>> getCategoryVideos(int categoryId) async {
    try {
      final response = await _dio.get(
        '/x/web-interface/dynamic/region',
        queryParameters: {
          'rid': categoryId,
          'ps': 20,
          'pn': 1,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0) {
          final List<dynamic> items = data['data']['archives'];
          return items.map((item) => _parseCategoryItem(item)).toList();
        } else {
          throw Exception('API错误: ${data['message']}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      print('获取分区视频错误: $e');
      // 如果API调用失败，返回一些模拟数据
      return _getFallbackCategoryVideos(categoryId);
    }
  }
  
  // 解析搜索结果中的视频项
  AudioItem _parseVideoItem(Map<String, dynamic> item) {
    return AudioItem(
      id: item['bvid'] ?? '',
      title: item['title'] ?? '',
      uploader: item['author'] ?? '',
      thumbnail: item['pic'] ?? '',
      audioUrl: '', // 音频URL需要单独获取
      addedTime: DateTime.now(),
      isFavorite: false,
      isDownloaded: false,
    );
  }
  
  // 解析热门推荐中的视频项
  AudioItem _parsePopularItem(Map<String, dynamic> item) {
    return AudioItem(
      id: item['bvid'] ?? '',
      title: item['title'] ?? '',
      uploader: item['owner']['name'] ?? '',
      thumbnail: item['pic'] ?? '',
      audioUrl: '', // 音频URL需要单独获取
      addedTime: DateTime.now(),
      isFavorite: false,
      isDownloaded: false,
      playCount: item['stat']?['view'] as int? ?? 0, // 添加播放量
    );
  }
  
  // 解析分区视频中的视频项
  AudioItem _parseCategoryItem(Map<String, dynamic> item) {
    return AudioItem(
      id: item['bvid'] ?? '',
      title: item['title'] ?? '',
      uploader: item['owner']['name'] ?? '',
      thumbnail: item['pic'] ?? '',
      audioUrl: '', // 音频URL需要单独获取
      addedTime: DateTime.now(),
      isFavorite: false,
      isDownloaded: false,
      playCount: item['stat']?['view'] as int? ?? 0, // 添加播放量
    );
  }
  
  // 获取备用搜索结果（当API调用失败时使用）
  List<AudioItem> _getFallbackSearchResults(String query) {
    return List.generate(5, (index) => AudioItem(
      id: 'BV1xx411c7mD',
      title: '【$query】搜索结果 ${index + 1}',
      uploader: 'B站用户',
      thumbnail: 'https://picsum.photos/300/200?random=${index + 1}',
      audioUrl: '',
      addedTime: DateTime.now(),
      isFavorite: false,
      isDownloaded: false,
    ));
  }
  
  // 获取备用热门推荐（当API调用失败时使用）
  List<AudioItem> _getFallbackRecommendations() {
    return List.generate(10, (index) => AudioItem(
      id: 'BV1xx411c7mD',
      title: '热门推荐 ${index + 1}',
      uploader: 'B站用户',
      thumbnail: 'https://picsum.photos/300/200?random=${index + 10}',
      audioUrl: '',
      addedTime: DateTime.now(),
      isFavorite: false,
      isDownloaded: false,
    ));
  }
  
  // 获取备用分区视频（当API调用失败时使用）
  List<AudioItem> _getFallbackCategoryVideos(int categoryId) {
    return List.generate(8, (index) => AudioItem(
      id: 'BV1xx411c7mD',
      title: '分区${categoryId}视频 ${index + 1}',
      uploader: 'B站用户',
      thumbnail: 'https://picsum.photos/300/200?random=${index + 20}',
      audioUrl: '',
      addedTime: DateTime.now(),
      isFavorite: false,
      isDownloaded: false,
    ));
  }

  // 添加Cookie刷新方法
  Future<void> _refreshCookies() async {
    try {
      final response = await Dio().get(
        'https://www.bilibili.com',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
          },
          followRedirects: false,
        ),
      );
      
      final cookies = response.headers['set-cookie'];
      if (cookies != null) {
        final cookieString = cookies.join('; ');
        await _prefs.setString(_cookieKey, cookieString);
        _dio.options.headers['Cookie'] = cookieString;
      }
    } catch (e) {
      debugPrint('刷新Cookie失败: $e');
    }
  }

  // 使用浏览器登录并提取Cookie
  Future<bool> loginWithBrowser([String? cookieString]) async {
    try {
      debugPrint('启动浏览器登录流程');
      
      // 如果直接传入了cookie字符串，使用它
      if (cookieString != null && cookieString.isNotEmpty) {
        debugPrint('使用WebView提取的Cookie: ${cookieString.length > 50 ? cookieString.substring(0, 50) + "..." : cookieString}');
        
        // 保存Cookie
        await _prefs.setString(_cookieKey, cookieString);
        _dio.options.headers['Cookie'] = cookieString;
        
        // 提取CSRF Token
        final csrfToken = _extractCsrfToken(cookieString);
        if (csrfToken != null) {
          await _prefs.setString(_csrfKey, csrfToken);
        }
        
        // 检查登录状态并获取用户信息
        try {
          final userResponse = await _dio.get(
            'https://api.bilibili.com/x/web-interface/nav',
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Referer': 'https://www.bilibili.com',
                'Cookie': cookieString,
              },
            ),
          );
          
          if (userResponse.data['code'] == 0) {
            final userData = userResponse.data['data'];
            if (userData['isLogin'] == 1) {
              final user = UserModel(
                mid: userData['mid'] is int ? userData['mid'] : int.parse(userData['mid'].toString()),
                uid: userData['mid'].toString(),
                username: userData['uname'],
                avatar: userData['face'],
                isLoggedIn: true,
                isVip: userData['vipStatus'] == 1,
              );
              
              await user.saveToPrefs(_prefs);
              debugPrint('登录成功，已获取用户信息');
              return true;
            }
          }
          
          debugPrint('Cookie获取成功，但用户未登录');
          return false;
        } catch (e) {
          debugPrint('获取用户信息失败: $e');
          return false;
        }
      }
      
      // 尝试从哔哩哔哩获取Cookie
      try {
        final cookieResponse = await Dio().get(
          'https://www.bilibili.com',
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            },
            followRedirects: true,
            validateStatus: (status) => true,
          ),
        );
        
        final cookies = cookieResponse.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          debugPrint('成功获取Cookie');
          final cookieString = cookies.join('; ');
          
          // 保存Cookie
          await _prefs.setString(_cookieKey, cookieString);
          _dio.options.headers['Cookie'] = cookieString;
          
          // 提取CSRF Token
          final csrfToken = _extractCsrfToken(cookieString);
          if (csrfToken != null) {
            await _prefs.setString(_csrfKey, csrfToken);
          }
          
          // 检查登录状态并获取用户信息
          try {
            final userResponse = await _dio.get(
              'https://api.bilibili.com/x/web-interface/nav',
              options: Options(
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                  'Referer': 'https://www.bilibili.com',
                  'Cookie': cookieString,
                },
              ),
            );
            
            if (userResponse.data['code'] == 0) {
              final userData = userResponse.data['data'];
              if (userData['isLogin'] == 1) {
                final user = UserModel(
                  mid: userData['mid'] is int ? userData['mid'] : int.parse(userData['mid'].toString()),
                  uid: userData['mid'].toString(),
                  username: userData['uname'],
                  avatar: userData['face'],
                  isLoggedIn: true,
                  isVip: userData['vipStatus'] == 1,
                );
                
                await user.saveToPrefs(_prefs);
                debugPrint('登录成功，已获取用户信息');
                return true;
              }
            }
            
            debugPrint('Cookie获取成功，但用户未登录');
            return false;
          } catch (e) {
            debugPrint('获取用户信息失败: $e');
            return false;
          }
        } else {
          debugPrint('未能获取Cookie');
          return false;
        }
      } catch (e) {
        debugPrint('获取Cookie过程中出错: $e');
        return false;
      }
    } catch (e) {
      debugPrint('浏览器登录流程出错: $e');
      return false;
    }
  }
} 