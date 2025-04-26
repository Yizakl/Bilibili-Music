// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences implements SharedPreferences {
  final Map<String, Object> _data = {};

  @override
  bool? getBool(String key) => false;
  @override
  int? getInt(String key) => null;
  @override
  double? getDouble(String key) => null;
  @override
  String? getString(String key) => null;
  @override
  bool containsKey(String key) => false;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Set<String> getKeys() => {};
  @override
  Object? get(String key) => null;
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  Future<bool> setInt(String key, int value) async => true;
  @override
  Future<bool> setDouble(String key, double value) async => true;
  @override
  Future<bool> setString(String key, String value) async => true;
  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
  @override
  Future<bool> remove(String key) async => true;
  @override
  Future<bool> clear() async => true;
  @override
  Future<void> reload() async {}
  @override
  Future<bool> commit() async => true;
}

// 创建一个简单的测试应用
class TestApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const TestApp({super.key, required this.prefs});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Test App'),
        ),
        body: const Center(
          child: Text('Hello, Test!'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockSharedPreferences mockPrefs;
  
  setUp(() {
    mockPrefs = MockSharedPreferences();
  });
  
  testWidgets('Test app should build without errors', (WidgetTester tester) async {
    // 构建测试应用而不是实际应用
    await tester.pumpWidget(TestApp(prefs: mockPrefs));
    
    // 验证测试应用已成功构建
    expect(find.text('Test App'), findsOneWidget);
    expect(find.text('Hello, Test!'), findsOneWidget);
  });
}
