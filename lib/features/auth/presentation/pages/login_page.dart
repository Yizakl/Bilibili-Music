import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/auth_state.dart'; // Keep this import

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late TabController _tabController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handlePasswordLogin(AuthState authState) {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户名和密码')),
      );
      return;
    }

    authState.loginWithPassword(username, password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '扫码登录'),
            Tab(text: '密码登录'),
          ],
          onTap: (index) {
            // Initiate QR code fetch when switching to the QR tab
            if (index == 0) {
              final authState = context.read<AuthState>();
              // Only initiate if not already loading and no QR code is present/valid
              if (!authState.isLoading &&
                  authState.qrCodeUrl == null &&
                  authState.qrCodeStatus != QRCodeStatus.confirmed) {
                authState.initiateQRCodeLogin();
              }
            }
          },
        ),
      ),
      body: Consumer<AuthState>(
        // Keep using Consumer
        builder: (context, authState, child) {
          // Display loading indicator centrally, regardless of tab
          if (authState.isLoading && authState.currentUser == null) {
            // Show loading only if not logged in yet, otherwise let views handle loading state
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors globally via SnackBar
          if (authState.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(authState.error!)),
              );
              authState.clearError(); // Clear error after showing
            });
          }

          // If logged in, potentially navigate away or show a success message
          // This part depends on the desired navigation flow after login
          if (authState.isLoggedIn) {
            // Example: Navigate back or to home screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                // Handle case where login page is the root
              }
            });
            // Show a placeholder while navigating
            return const Center(child: Text('登录成功！正在跳转...'));
          }

          return TabBarView(
            controller: _tabController,
            physics:
                const NeverScrollableScrollPhysics(), // Prevent swiping between tabs
            children: [
              _buildQRCodeLoginView(context, authState),
              _buildPasswordLoginView(authState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQRCodeLoginView(BuildContext context, AuthState authState) {
    // Use a switch statement for clarity on QRCodeStatus
    Widget qrContent;
    String statusText = '';

    switch (authState.qrCodeStatus) {
      case QRCodeStatus.waiting:
        if (authState.qrCodeUrl != null) {
          qrContent = QrImageView(
            data: authState.qrCodeUrl!,
            version: QrVersions.auto,
            size: 200.0,
          );
          statusText = '请使用哔哩哔哩APP扫描二维码';
        } else if (authState.isLoading) {
          qrContent = const CircularProgressIndicator();
          statusText = '正在获取二维码...';
        } else {
          qrContent = ElevatedButton(
            onPressed: () => authState.initiateQRCodeLogin(),
            child: const Text('获取/刷新二维码'),
          );
          statusText = '点击按钮获取二维码';
        }
        break;
      case QRCodeStatus.scanned:
        qrContent = const Icon(Icons.check_circle_outline,
            size: 100, color: Colors.green);
        statusText = '扫描成功，请在手机上确认登录';
        break;
      case QRCodeStatus.confirmed:
        // This case is handled by the main builder (isLoggedIn check)
        // But we can show a temporary success message here if needed
        qrContent =
            const Icon(Icons.check_circle, size: 100, color: Colors.blue);
        statusText = '登录成功！';
        break;
      case QRCodeStatus.expired:
        qrContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 100, color: Colors.orange),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => authState.initiateQRCodeLogin(),
              child: const Text('刷新二维码'),
            ),
          ],
        );
        statusText = '二维码已过期，请刷新';
        break;
      case QRCodeStatus.error:
        qrContent = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 100, color: Colors.red),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => authState.initiateQRCodeLogin(),
              child: const Text('重试'),
            ),
          ],
        );
        statusText =
            authState.error ?? '发生错误，请重试'; // Show specific error if available
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 220, // Allocate fixed space for QR/Icon
              child: Center(child: qrContent),
            ),
            const SizedBox(height: 24.0),
            Text(statusText, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  // _buildPasswordLoginView remains largely the same, ensure it uses authState.isLoading correctly
  Widget _buildPasswordLoginView(AuthState authState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person),
            ),
            textInputAction: TextInputAction.next,
            enabled: !authState.isLoading, // Disable input when loading
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: authState.isLoading
                ? null
                : (_) => _handlePasswordLogin(authState),
            enabled: !authState.isLoading, // Disable input when loading
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            // Show progress indicator inside button when loading
            onPressed: authState.isLoading
                ? null
                : () => _handlePasswordLogin(authState),
            child: authState.isLoading && _tabController.index == 1
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('登录'),
          ),
        ],
      ),
    );
  }
}
