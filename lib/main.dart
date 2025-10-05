import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'models/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'utils/tray_manager.dart';
import 'utils/logger.dart';

void main() async {
  // 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 添加启动日志
  Logger.info('DualVPN Manager 正在启动...');

  // 初始化窗口管理器
  await _initWindowManager();

  // 初始化系统托盘
  final trayManager = DualVPNTrayManager();
  await trayManager.initTray();

  // 记录初始化完成
  Logger.info('系统托盘初始化完成');

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(trayManager: trayManager),
      child: DualVPNApp(trayManager: trayManager),
    ),
  );
}

// 初始化窗口管理器
Future<void> _initWindowManager() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    // 设置窗口关闭时的行为 - 防止窗口真正关闭
    await windowManager.setPreventClose(true);
    // 隐藏标题栏
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

    // 记录窗口管理器初始化成功
    Logger.info('窗口管理器初始化成功');
  } catch (e) {
    Logger.error('窗口管理器初始化失败: $e');
  }
}

class DualVPNApp extends StatelessWidget {
  final DualVPNTrayManager trayManager;

  const DualVPNApp({super.key, required this.trayManager});

  @override
  Widget build(BuildContext context) {
    // 添加一个简单的测试日志
    Logger.info('构建DualVPNApp widget');

    return Consumer<AppState>(
      builder: (context, appState, child) {
        // 设置AppState到托盘管理器
        trayManager.setAppState(appState);

        return MaterialApp(
          title: '双捷VPN管理器',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            // 使用更现代的视觉效果
            useMaterial3: true,
            // 自定义颜色方案
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            // 自定义按钮主题
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
              ),
            ),
            // 自定义卡片主题
            cardTheme: CardThemeData(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // 自定义底部导航栏主题
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
            ),
          ),
          themeMode: ThemeMode.system,
          navigatorKey: appState.navigatorKey,
          home: LogFilterWrapper(child: HomeScreen()),
        );
      },
    );
  }
}

// 添加日志过滤器包装器
class LogFilterWrapper extends StatefulWidget {
  final Widget child;

  const LogFilterWrapper({super.key, required this.child});

  @override
  State<LogFilterWrapper> createState() => _LogFilterWrapperState();
}

class _LogFilterWrapperState extends State<LogFilterWrapper> {
  final TextEditingController _filterController = TextEditingController();
  String? _currentFilter;

  @override
  void initState() {
    super.initState();
    // 初始化过滤器为空（显示所有日志）
    Logger.setFilterHost(null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // 添加一个浮动的操作按钮来设置日志过滤器
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: _showFilterDialog,
            child: const Icon(Icons.filter_list),
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    _filterController.text = _currentFilter ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('设置日志过滤器'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _filterController,
                decoration: const InputDecoration(
                  labelText: '主机名过滤器',
                  hintText: '例如: www.baidu.com',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '留空显示所有日志\n输入主机名只显示相关日志',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final filter = _filterController.text.trim();
                setState(() {
                  _currentFilter = filter.isEmpty ? null : filter;
                });
                Logger.setFilterHost(_currentFilter);
                Navigator.of(context).pop();
              },
              child: const Text('应用'),
            ),
          ],
        );
      },
    );
  }
}
