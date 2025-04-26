import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../../../core/services/bilibili_service.dart';
import 'dart:async';
import 'dart:io';

class BrowserLoginPage extends StatefulWidget {
  const BrowserLoginPage({super.key});

  @override
  State<BrowserLoginPage> createState() => _BrowserLoginPageState();
}

class _BrowserLoginPageState extends State<BrowserLoginPage> {
  late WebViewController? _controller;
  bool _isLoading = true;
  String _statusMessage = '正在加载登录页面...';
  Timer? _cookieCheckTimer;
  bool _isLoginDetected = false;
  int _cookieCheckCount = 0;
  static const int _maxCookieChecks = 60;
  bool _isUnsupportedPlatform = false;
  
  // Windows登录表单控制器
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initPlatform();
  }

  @override
  void dispose() {
    _cookieCheckTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _initPlatform() {
    try {
      // Windows平台不支持WebView，但我们提供替代UI
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        setState(() {
          _isUnsupportedPlatform = true;
          _statusMessage = '当前平台不支持WebView，请使用账号密码登录';
          _isLoading = false;
        });
        return;
      }
      
      if (Platform.isAndroid) {
        AndroidWebViewPlatform.registerWith();
        _initWebView();
      } else if (Platform.isIOS) {
        WebKitWebViewPlatform.registerWith();
        _initWebView();
      } else {
        setState(() {
          _isUnsupportedPlatform = true;
          _statusMessage = '当前平台不支持WebView，请使用账号密码登录';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('初始化平台失败: $e');
      setState(() {
        _isUnsupportedPlatform = true;
        _statusMessage = '初始化WebView失败: $e';
        _isLoading = false;
      });
    }
  }

  void _initWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('页面开始加载: $url');
              setState(() {
                _isLoading = true;
                _statusMessage = '正在加载页面...';
              });
            },
            onPageFinished: (String url) {
              debugPrint('页面加载完成: $url');
              setState(() {
                _isLoading = false;
                _statusMessage = '登录页面加载完成，请登录';
              });

              // 检查是否已经登录
              if (url.contains('.bilibili.com') && !url.contains('passport.bilibili.com/login')) {
                _extractCookies();
              }
            },
            onUrlChange: (UrlChange change) {
              final url = change.url ?? '';
              debugPrint('URL改变: $url');
              
              // 检查是否已经登录
              if (url.isNotEmpty && 
                  !url.contains('passport.bilibili.com/login') && 
                  url.contains('.bilibili.com')) {
                _extractCookies();
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('资源加载错误: ${error.description}');
              setState(() {
                _statusMessage = '加载出错: ${error.description}';
                _isLoading = false;
              });
            },
          ),
        );
      
      // 设置用户代理
      _controller!.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
      );
      
      // 设置Cookie管理
      if (Platform.isAndroid) {
        final androidController = _controller!.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
      }
      
      // 加载登录页面
      _controller!.loadRequest(
        Uri.parse('https://passport.bilibili.com/login'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Site': 'none',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-User': '?1',
          'Sec-Fetch-Dest': 'document',
        },
      );
      
      debugPrint('WebView控制器初始化完成');
    } catch (e) {
      debugPrint('WebView初始化失败: $e');
      setState(() {
        _isUnsupportedPlatform = true;
        _statusMessage = '初始化WebView失败: $e';
        _isLoading = false;
      });
    }
  }

  void _onLoginSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录成功！')),
    );
    Navigator.pop(context, true);
  }

  void _onLoginTimeout() {
    setState(() {
      _statusMessage = '登录超时，请重试或使用账号密码登录';
      _isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录超时，请使用账号密码登录'), 
        duration: Duration(seconds: 3),
      ),
    );
  }

  // 直接登录功能 (在不支持WebView的平台上使用)
  Future<void> _directLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = '正在登录...';
    });
    
    try {
      final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
      final success = await bilibiliService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功！')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _statusMessage = '登录失败，请检查账号密码';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '登录失败: $e';
        _isLoading = false;
      });
    }
  }

  void _extractCookies() async {
    debugPrint('正在提取Cookie...');
    if (_isLoginDetected) return;
    
    _cookieCheckTimer?.cancel();
    
    setState(() {
      _statusMessage = '检测到页面变化，正在验证登录状态...';
    });
    
    _cookieCheckCount = 0;
    _cookieCheckTimer = Timer.periodic(
      const Duration(seconds: 1), 
      (timer) async {
        _cookieCheckCount++;
        
        if (_cookieCheckCount > _maxCookieChecks) {
          timer.cancel();
          _onLoginTimeout();
          return;
        }
        
        try {
          // 获取WebView中的Cookie
          final cookieScript = await _controller!.runJavaScriptReturningResult(
            'document.cookie'
          );
          
          debugPrint('获取到Cookie: $cookieScript');
          
          if (cookieScript != null && 
              cookieScript.toString().contains('bili_jct') && 
              cookieScript.toString().contains('SESSDATA')) {
            timer.cancel();
            
            final bilibiliService = Provider.of<BilibiliService>(context, listen: false);
            final cookieString = cookieScript.toString().replaceAll('"', '');
            
            // 调用服务处理cookie
            final success = await bilibiliService.loginWithBrowser(cookieString);
            
            if (success) {
              _isLoginDetected = true;
              _onLoginSuccess();
            } else {
              setState(() {
                _statusMessage = '登录验证失败，请重试';
                _isLoading = false;
              });
            }
          }
        } catch (e) {
          debugPrint('获取Cookie出错: $e');
        }
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B站账号登录'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (!_isUnsupportedPlatform)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                try {
                  _controller?.reload();
                } catch (e) {
                  debugPrint('重新加载失败: $e');
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            width: double.infinity,
            child: Row(
              children: [
                if (_isLoading && !_isUnsupportedPlatform)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 主内容区域
          Expanded(
            child: _isUnsupportedPlatform
                ? _buildDirectLoginForm()
                : Stack(
                    children: [
                      WebViewWidget(controller: _controller!),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
          ),
          
          // 底部按钮区域
          if (!_isUnsupportedPlatform)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('取消'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
  
  Widget _buildDirectLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            
            // Bilibili Logo
            Center(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Image.network(
                  'https://i0.hdslb.com/bfs/archive/4b195a0835fa0d029751e1be14bac862d45d56e3.png',
                  height: 60,
                  errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.video_library, size: 60, color: Colors.pink),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 用户名输入框
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '用户名',
                hintText: '请输入B站用户名',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // 密码输入框
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '请输入账号密码',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 32),
            
            // 登录按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _directLogin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 16),
            
            // 取消按钮
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: const Text('取消', style: TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 24),
            
            // 提示文本
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前平台不支持浏览器登录，请使用账号密码直接登录',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 