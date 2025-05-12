import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/bilibili_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:animations/animations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final BilibiliService _bilibiliService;
  final _sessdataController = TextEditingController();
  final _biliJctController = TextEditingController();
  final _dedeUserIDController = TextEditingController();

  late TabController _tabController;
  String? _qrCodeUrl;
  String? _qrCodeKey;
  Timer? _qrCodeTimer;
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initBilibiliService();
    _loadSavedCookies();
  }

  Future<void> _initBilibiliService() async {
    final prefs = await SharedPreferences.getInstance();
    _bilibiliService = BilibiliService(prefs);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sessdataController.dispose();
    _biliJctController.dispose();
    _dedeUserIDController.dispose();
    _qrCodeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedCookies() async {
    final cookies = await _bilibiliService.getSavedCookies();
    setState(() {
      _sessdataController.text = cookies['sessdata'] ?? '';
      _biliJctController.text = cookies['bili_jct'] ?? '';
      _dedeUserIDController.text = cookies['dede_user_id'] ?? '';
    });
  }

  Future<void> _loginWithCookies() async {
    if (_sessdataController.text.isEmpty ||
        _biliJctController.text.isEmpty ||
        _dedeUserIDController.text.isEmpty) {
      EasyLoading.showError('请填写完整的Cookie信息');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await _bilibiliService.loginWithCookies(
        _sessdataController.text,
        _biliJctController.text,
        _dedeUserIDController.text,
      );

      if (success) {
        EasyLoading.showSuccess('登录成功');
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        EasyLoading.showError('登录失败，请检查Cookie是否正确');
      }
    } catch (e) {
      EasyLoading.showError('登录出错: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateQRCode() async {
    setState(() => _isLoading = true);
    try {
      final qrData = await _bilibiliService.getQRCode();
      setState(() {
        _qrCodeUrl = qrData['url'];
        _qrCodeKey = qrData['key'];
      });
      _startQRCodeCheck();
    } catch (e) {
      EasyLoading.showError('获取二维码失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startQRCodeCheck() {
    _qrCodeTimer?.cancel();
    _qrCodeTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_qrCodeKey == null) {
        timer.cancel();
        return;
      }

      try {
        final status = await _bilibiliService.checkQRCodeStatus(_qrCodeKey!);
        if (status['status']) {
          timer.cancel();
          EasyLoading.showSuccess('登录成功');
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else if (status['message'] == '二维码已失效') {
          timer.cancel();
          EasyLoading.showError('二维码已失效，请重新获取');
          setState(() {
            _qrCodeUrl = null;
            _qrCodeKey = null;
          });
        } else {
          EasyLoading.showInfo(status['message']);
        }
      } catch (e) {
        timer.cancel();
        EasyLoading.showError('检查二维码状态失败: $e');
      }
    });
  }

  Widget _buildCookieInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: _obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: IconButton(
            icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cookie登录'),
            Tab(text: '扫码登录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Cookie登录
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 说明卡片
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '如何获取Cookie？',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '1. 打开浏览器，访问 bilibili.com 并登录\n'
                          '2. 按F12打开开发者工具\n'
                          '3. 切换到"Application"或"应用程序"标签\n'
                          '4. 在左侧找到"Cookies"并点击\n'
                          '5. 找到并复制以下三个值：',
                          style: TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                // SESSDATA输入框
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SESSDATA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '这是您的登录凭证，用于维持登录状态',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCookieInput(
                          controller: _sessdataController,
                          label: 'SESSDATA',
                          hint: '请输入SESSDATA',
                          icon: Icons.cookie,
                        ),
                      ],
                    ),
                  ),
                ),
                // bili_jct输入框
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'bili_jct',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '这是您的CSRF令牌，用于验证操作',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCookieInput(
                          controller: _biliJctController,
                          label: 'bili_jct',
                          hint: '请输入bili_jct',
                          icon: Icons.security,
                        ),
                      ],
                    ),
                  ),
                ),
                // DedeUserID输入框
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DedeUserID',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '这是您的用户ID，用于标识身份',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCookieInput(
                          controller: _dedeUserIDController,
                          label: 'DedeUserID',
                          hint: '请输入DedeUserID',
                          icon: Icons.person,
                        ),
                      ],
                    ),
                  ),
                ),
                // 登录按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithCookies,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 16),
                // 清除按钮
                TextButton.icon(
                  onPressed: () {
                    _sessdataController.clear();
                    _biliJctController.clear();
                    _dedeUserIDController.clear();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('清除所有输入'),
                ),
              ],
            ),
          ),
          // 扫码登录
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_qrCodeUrl != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _qrCodeUrl!,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '请使用B站APP扫描二维码登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '二维码有效期为5分钟',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text('点击下方按钮获取二维码'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateQRCode,
                  icon: const Icon(Icons.qr_code),
                  label: Text(_isLoading ? '获取中...' : '获取二维码'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
