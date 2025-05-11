import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/bilibili_api.dart';
import '../widgets/cookie_login_dialog.dart';
import '../widgets/browser_login_dialog.dart';
import '../../../../core/widgets/custom_error_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isRememberMe = false;
  bool _isQRLogin = false;

  late TabController _tabController;

  // 二维码相关变量
  String? _qrCodeUrl;
  String? _qrCodeKey;
  String _status = '正在获取二维码...';
  bool _loading = true;
  Timer? _timer;
  bool _isLoginSuccess = false;

  // Cookie登录相关
  final _cookieController = TextEditingController();
  final _browserUrlController = TextEditingController();

  // 表单键
  final _cookieFormKey = GlobalKey<FormState>();
  final _urlFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _getQRCode();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _timer?.cancel();
    _cookieController.dispose();
    _browserUrlController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && _qrCodeUrl == null) {
      _getQRCode();
    } else if (_tabController.index == 0) {
      _timer?.cancel();
    }
  }

  Future<void> _getQRCode() async {
    setState(() {
      _loading = true;
      _status = '正在获取二维码...';
    });

    try {
      // 获取SharedPreferences实例
      final prefs = await SharedPreferences.getInstance();
      final bilibiliApi = BilibiliApi(prefs); // 正确初始化BilibiliApi

      // 使用正确的方法名和参数调用
      final Map<String, dynamic> qrData = await bilibiliApi.generateQRCode();

      setState(() {
        if (qrData.containsKey('url') && qrData.containsKey('key')) {
          _qrCodeUrl = qrData['url'];
          _qrCodeKey = qrData['key'];
          _loading = false;
          _status = '请使用哔哩哔哩客户端扫描二维码';

          // 打印调试信息
          debugPrint('获取二维码成功: URL=$_qrCodeUrl, KEY=$_qrCodeKey');
        } else {
          _loading = false;
          _status = '获取二维码失败: 返回数据不完整';
          debugPrint('二维码数据不完整: $qrData');
        }
      });

      // 开始轮询检查登录状态
      _startPollingQRCodeStatus();
    } catch (e) {
      setState(() {
        _loading = false;
        _status = '获取二维码失败: $e';
      });
      debugPrint('获取二维码出错: $e');
    }
  }

  void _startPollingQRCodeStatus() {
    // 取消现有的计时器
    _timer?.cancel();

    // 创建新的计时器，每3秒检查一次状态
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_qrCodeKey == null || _qrCodeKey!.isEmpty) {
        timer.cancel();
        debugPrint('二维码KEY为空，停止轮询');
        return;
      }

      try {
        // 获取SharedPreferences实例
        final prefs = await SharedPreferences.getInstance();
        final bilibiliApi = BilibiliApi(prefs); // 正确初始化BilibiliApi

        debugPrint('检查二维码状态: KEY=$_qrCodeKey');
        final Map<String, dynamic> result =
            await bilibiliApi.checkQRCodeStatus(_qrCodeKey!);
        debugPrint('二维码状态结果: $result');

        // 检查登录是否成功
        if (result.containsKey('status')) {
          final status = result['status'];

          if (status == true || status == 2) {
            // 登录成功
            _timer?.cancel();
            setState(() {
              _status = '登录成功！正在获取用户信息...';
              _isLoginSuccess = true;
            });

            // 登录成功，获取用户信息
            final authService =
                Provider.of<AuthService>(context, listen: false);
            final success = await authService.getUserInfo();

            if (mounted) {
              setState(() {
                if (success) {
                  _status = '登录成功！即将返回...';
                } else {
                  _status = '获取用户信息失败，请重试';
                  _isLoginSuccess = false;
                }
              });

              // 登录成功，延迟返回
              if (success) {
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('登录成功')),
                  );
                  context.go('/');
                }
              }
            }
          } else if (status == 1 || status == 86090) {
            // 已扫描，等待确认
            setState(() {
              _status = '已扫描，请在手机上确认登录';
            });
          } else if (status == 86038) {
            // 二维码已过期
            setState(() {
              _status = '二维码已过期，请刷新';
              _loading = false;
            });
            timer.cancel();
          } else {
            // 其他状态
            setState(() {
              _status = '等待扫描二维码 (状态: $status)';
            });
          }
        } else {
          setState(() {
            _status = '检查状态失败: 返回数据格式不正确';
          });
        }
      } catch (e) {
        // 发生错误时不停止轮询，只更新状态
        if (mounted) {
          setState(() {
            _status = '检查二维码状态出错: $e';
          });
          debugPrint('检查二维码状态出错: $e');
        }
      }
    });
  }

  void _showAdvancedLoginOptions() async {
    // 暂停轮询
    _timer?.cancel();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CookieLoginDialog(),
    );

    if (result == true) {
      if (mounted) {
        // 如果高级登录成功，直接返回
        context.go('/');
      }
    } else if (mounted) {
      // 如果取消高级登录，恢复轮询
      _startPollingQRCodeStatus();
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);

      try {
        // 这里注释掉或修改不存在的方法调用
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码登录功能暂不可用')),
        );
        // final success = await authService.loginWithPassword(
        //   _usernameController.text.trim(),
        //   _passwordController.text,
        // );

        // 暂时直接返回
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登录失败: $e')),
          );
        }
      }
    }
  }

  void _showCantLoginOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登录方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cookie_outlined),
              title: const Text('Cookie登录'),
              subtitle: const Text('手动输入B站Cookie进行登录'),
              onTap: () {
                Navigator.of(context).pop();
                _showCookieLoginDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('浏览器登录'),
              subtitle: const Text('通过浏览器登录并获取Cookie'),
              onTap: () {
                Navigator.of(context).pop();
                _showBrowserLoginDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showCookieLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const CookieLoginDialog(),
    );
  }

  void _showBrowserLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const BrowserLoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '账号登录',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: authService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '密码登录'),
                    Tab(text: '扫码登录'),
                    Tab(text: 'Cookie登录'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 密码登录页
                      _buildPasswordLoginTab(),

                      // 二维码登录页
                      _buildQRCodeLoginTab(),

                      // Cookie登录
                      _buildCookieLogin(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPasswordLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // 用户名输入
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入用户名或手机号',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // 密码输入
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),

            const SizedBox(height: 10),

            // 记住我选项
            Row(
              children: [
                Checkbox(
                  value: _isRememberMe,
                  onChanged: (value) {
                    setState(() {
                      _isRememberMe = value ?? false;
                    });
                  },
                ),
                const Text('记住我'),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // TODO: 实现忘记密码功能
                  },
                  child: const Text('忘记密码？'),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 登录按钮
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '登录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // 演示账号提示
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                '演示账号：用户名 demo，密码 password',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeLoginTab() {
    final authService = Provider.of<AuthService>(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // 二维码标题
            const Text(
              '扫描二维码登录',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // 二维码说明
            const Text(
              '请使用哔哩哔哩App扫描二维码',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            // 二维码显示
            if (_qrCodeUrl != null && !_isLoginSuccess)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.white,
                ),
                child: QrImageView(
                  data: _qrCodeUrl!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(10),
                ),
              )
            else if (_loading)
              const SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(),
              )
            else
              const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: Text('二维码已失效，请刷新')),
              ),

            const SizedBox(height: 20),

            // 二维码状态
            Text(
              _status,
              style: TextStyle(
                color: _status.contains('失败') || _status.contains('失效')
                    ? Colors.red
                    : _status.contains('成功')
                        ? Colors.green
                        : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 登录状态信息
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API登录状态: ${authService.isLoggedIn ? "已登录" : "未登录"}'),
                  Text('用户状态: ${authService.isLoggedIn ? "已登录" : "未登录"}'),
                  if (authService.currentUser != null)
                    Text('当前用户: ${authService.currentUser!.username}'),
                  if (authService.error != null)
                    Text('错误信息: ${authService.error}',
                        style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 刷新二维码按钮
            if (_status.contains('失效'))
              ElevatedButton.icon(
                onPressed: _getQRCode,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新二维码'),
              ),

            // 刷新用户信息按钮
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Provider.of<AuthService>(context, listen: false)
                      .getUserInfo(); // 使用正确的方法获取用户信息
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('用户信息已刷新')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('刷新失败: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('刷新用户信息'),
            ),

            const SizedBox(height: 40),

            // 操作说明
            const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.looks_one, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('打开哔哩哔哩App，点击右下角"我的"'),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.looks_two, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('点击左上角扫描图标，扫描此二维码'),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.looks_3, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('在手机上确认登录'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 高级登录选项
            if (!_isLoginSuccess) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _showCantLoginOptions,
                    child: const Text('无法登录？'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 构建Cookie登录界面
  Widget _buildCookieLogin() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Form(
          key: _cookieFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '输入B站Cookie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '请至少包含以下Cookie值:\nSESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _cookieController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx',
                ),
                minLines: 3,
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入Cookie';
                  }
                  if (!value.contains('SESSDATA') ||
                      !value.contains('bili_jct') ||
                      !value.contains('DedeUserID')) {
                    return '请确保包含必要的Cookie值';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loginWithCookies,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('登录'),
              ),

              const SizedBox(height: 32),

              const Divider(),

              const SizedBox(height: 16),

              // 如何获取Cookie的说明
              ExpansionTile(
                title: const Text('如何获取B站Cookie?'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('方法1: 使用浏览器开发者工具'),
                        SizedBox(height: 8),
                        Text(
                          '1. 在电脑浏览器中访问 bilibili.com 并登录\n'
                          '2. 按F12打开开发者工具，切换到"网络"(Network)标签\n'
                          '3. 刷新页面，在请求列表中找到bilibili.com的请求\n'
                          '4. 在"标头"(Headers)中找到"Cookie"字段并复制其值',
                          style: TextStyle(fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        Text('方法2: 使用浏览器扩展'),
                        SizedBox(height: 8),
                        Text(
                          '1. 安装"Cookie Editor"等浏览器扩展\n'
                          '2. 访问bilibili.com并登录\n'
                          '3. 点击扩展图标，复制所有Cookie或仅复制必要的Cookie',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建浏览器URL登录界面
  Widget _buildBrowserUrlLogin() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Form(
          key: _urlFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '通过浏览器URL登录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '在浏览器中登录B站后，复制浏览器地址栏中的完整URL',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _browserUrlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'https://www.bilibili.com/...',
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入URL';
                  }
                  if (!value.contains('bilibili.com')) {
                    return '请输入有效的哔哩哔哩URL';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loginWithBrowserUrl,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('登录'),
              ),

              const SizedBox(height: 32),

              const Divider(),

              const SizedBox(height: 16),

              // 如何获取浏览器URL的说明
              ExpansionTile(
                title: const Text('如何使用浏览器URL登录?'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('步骤说明:'),
                        SizedBox(height: 8),
                        Text(
                          '1. 在电脑浏览器中访问 bilibili.com\n'
                          '2. 登录你的B站账号\n'
                          '3. 登录成功后，复制浏览器地址栏中的完整URL\n'
                          '4. 粘贴到上面的输入框中点击登录',
                          style: TextStyle(fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        Text('注意事项:'),
                        SizedBox(height: 8),
                        Text(
                          '• 确保URL中包含了登录信息\n'
                          '• 某些浏览器可能无法获取完整的登录URL\n'
                          '• 如果登录失败，请尝试使用二维码或Cookie方式登录',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginWithCookies() async {
    if (!_cookieFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _status = '正在登录...';
    });

    try {
      // 解析Cookie字符串
      final cookieStr = _cookieController.text.trim();
      final Map<String, String> cookies = {};

      // 处理多行或分号分隔的cookie
      final cookieParts = cookieStr.replaceAll('\n', ';').split(';');
      for (var part in cookieParts) {
        part = part.trim();
        if (part.contains('=')) {
          final keyValue = part.split('=');
          if (keyValue.length >= 2) {
            final key = keyValue[0].trim();
            final value = keyValue[1].trim();
            cookies[key] = value;
          }
        }
      }

      if (cookies.isEmpty) {
        setState(() {
          _status = '无法解析Cookie，请检查格式';
          _loading = false;
        });
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.loginWithCookies(cookies);

      if (mounted) {
        if (success) {
          // 登录成功，返回首页
          context.go('/');
        } else {
          setState(() {
            _status = '登录失败，Cookie无效或已过期';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '登录出错: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginWithBrowserUrl() async {
    if (!_urlFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _status = '正在登录...';
    });

    try {
      final url = _browserUrlController.text.trim();
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.loginWithBrowserUrl(url);

      if (mounted) {
        if (success) {
          // 登录成功，返回首页
          context.go('/');
        } else {
          setState(() {
            _status = '登录失败，URL无效或已过期';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '登录出错: $e';
          _loading = false;
        });
      }
    }
  }
}
