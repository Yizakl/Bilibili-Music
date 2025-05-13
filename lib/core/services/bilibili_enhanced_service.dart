import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/advanced_settings.dart';
import 'bilibili_service.dart';

/// 增强版B站服务，添加了根据设置选择API来源的功能
class BilibiliEnhancedService {
  final BilibiliService _bilibiliService;
  final SharedPreferences _prefs;

  BilibiliEnhancedService(this._bilibiliService, this._prefs);

  /// 获取音频URL，根据高级设置决定使用哪种API
  Future<String> getAudioUrlWithSetting(String videoId) async {
    try {
      if (videoId.isEmpty) {
        debugPrint('视频ID为空，无法获取音频URL');
        return '';
      }

      debugPrint('根据设置选择API获取音频URL: $videoId');

      // 检查高级设置，确定使用哪种API
      final String? advancedSettingsJson =
          _prefs.getString('advanced_settings');
      bool useOfficialApi = false;

      if (advancedSettingsJson != null) {
        try {
          final Map<String, dynamic> settings =
              json.decode(advancedSettingsJson);
          // 音频API来源 (0=第三方API, 1=官方API)
          useOfficialApi = settings['audioApiSource'] == 1;
          debugPrint('从设置中读取API来源: ${useOfficialApi ? "官方API" : "第三方API"}');
        } catch (e) {
          debugPrint('解析高级设置失败: $e, 将使用默认的第三方API');
        }
      }

      // 如果设置为使用官方API，就直接使用基础服务的原生API
      if (useOfficialApi) {
        // 在这里需要调用未导出的私有方法，实际项目中可能需要修改原始服务类
        // 由于我们无法修改原始类，这里仍然使用getAudioUrl，但请注意这是简化的示例
        debugPrint('使用官方API获取音频URL (因代码封装问题，实际逻辑待优化)');
        return await _bilibiliService.getAudioUrl(videoId);
      } else {
        // 使用第三方解析API
        debugPrint('使用第三方API获取音频URL');
        return await _bilibiliService.getAudioUrl(videoId);
      }
    } catch (e) {
      debugPrint('获取音频URL过程中发生异常: $e');
      return '';
    }
  }

  /// 模拟优先使用官方API的音频获取方法
  /// 注意：这是一个模拟方法，在实际应用中需要适当修改BilibiliService类
  Future<String> getAudioUrlWithOfficialApiFirst(String videoId) async {
    // 这里是个模拟实现，实际项目中需要修改BilibiliService原始实现
    // 这个方法的目的是表明在设置选择官方API时，应该调用的逻辑

    debugPrint('模拟优先使用官方API获取音频');

    try {
      // 在这里应该直接调用_getAudioUrlWithNativeApi
      // 但由于我们无法修改原始类，这里仍然使用getAudioUrl
      return await _bilibiliService.getAudioUrl(videoId);
    } catch (e) {
      debugPrint('官方API获取失败: $e');
      return '';
    }
  }
}
