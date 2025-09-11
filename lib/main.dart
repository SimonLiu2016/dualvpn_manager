import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'models/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'utils/tray_manager.dart';

void main() async {
  // 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  await _initWindowManager();

  // 初始化系统托盘
  final trayManager = DualVPNTrayManager();
  await trayManager.initTray();

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
  } catch (e) {
    print('窗口管理器初始化失败: $e');
  }
}

class DualVPNApp extends StatelessWidget {
  final DualVPNTrayManager trayManager;

  const DualVPNApp({super.key, required this.trayManager});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

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
      home: HomeScreen(),
    );
  }
}
