import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/models/advanced_settings.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final advancedSettings = settingsService.advancedSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('高级设置'),
      ),
      body: ListView(
        children: [
          // 音频API来源设置
          _buildSectionHeader('音频来源设置'),

          RadioListTile<AudioApiSource>(
            title: const Text('第三方解析API'),
            subtitle: const Text('使用第三方服务解析B站音频'),
            value: AudioApiSource.thirdParty,
            groupValue: advancedSettings.audioApiSource,
            onChanged: (value) {
              if (value != null) {
                settingsService.setAudioApiSource(value);
              }
            },
          ),

          RadioListTile<AudioApiSource>(
            title: const Text('官方API'),
            subtitle: const Text('直接使用B站官方API获取音频'),
            value: AudioApiSource.official,
            groupValue: advancedSettings.audioApiSource,
            onChanged: (value) {
              if (value != null) {
                settingsService.setAudioApiSource(value);
              }
            },
          ),

          // 播放设置
          _buildSectionHeader('播放设置'),

          // 新增：播放模式选择
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '播放模式',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '选择音频播放方式。\n"仅音频"会尝试直接播放音频流。\n"视频模式 (仅音频)" 会加载视频但只播放其音轨 (可能更兼容某些链接)。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          RadioListTile<PlaybackMode>(
            title: const Text('仅音频'),
            subtitle: const Text('直接播放音频流'),
            value: PlaybackMode.audioOnly,
            groupValue: advancedSettings.playbackMode,
            onChanged: (value) {
              if (value != null) {
                settingsService.setPlaybackMode(value);
              }
            },
          ),
          RadioListTile<PlaybackMode>(
            title: const Text('视频模式 (仅音频)'),
            subtitle: const Text('加载视频，但仅播放音频轨道'),
            value: PlaybackMode.videoAsAudio,
            groupValue: advancedSettings.playbackMode,
            onChanged: (value) {
              if (value != null) {
                settingsService.setPlaybackMode(value);
              }
            },
          ),

          SwitchListTile(
            title: const Text('硬件解码'),
            subtitle: const Text('启用硬件加速音频解码'),
            value: advancedSettings.useHardwareDecoding,
            onChanged: (value) {
              final newSettings = advancedSettings.copyWith(
                useHardwareDecoding: value,
              );
              settingsService.updateAdvancedSettings(newSettings);
            },
          ),

          SwitchListTile(
            title: const Text('无缝播放'),
            subtitle: const Text('消除歌曲之间的间隙'),
            value: advancedSettings.enableGaplessPlayback,
            onChanged: (value) {
              final newSettings = advancedSettings.copyWith(
                enableGaplessPlayback: value,
              );
              settingsService.updateAdvancedSettings(newSettings);
            },
          ),

          // 下载设置
          _buildSectionHeader('下载设置'),

          SwitchListTile(
            title: const Text('高品质下载'),
            subtitle: const Text('下载最高品质的音频'),
            value: advancedSettings.downloadHighQualityAudio,
            onChanged: (value) {
              final newSettings = advancedSettings.copyWith(
                downloadHighQualityAudio: value,
              );
              settingsService.updateAdvancedSettings(newSettings);
            },
          ),

          // 开发者选项
          _buildSectionHeader('开发者选项'),

          SwitchListTile(
            title: const Text('调试日志'),
            subtitle: const Text('启用详细的调试日志输出'),
            value: advancedSettings.enableDebugLogging,
            onChanged: (value) {
              final newSettings = advancedSettings.copyWith(
                enableDebugLogging: value,
              );
              settingsService.updateAdvancedSettings(newSettings);
            },
          ),

          // 还原默认设置
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                _showResetConfirmDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('恢复默认设置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('确定要将所有高级设置恢复为默认值吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 重置为默认值
              final settingsService = Provider.of<SettingsService>(
                context,
                listen: false,
              );
              settingsService.updateAdvancedSettings(const AdvancedSettings());
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已恢复默认设置')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
