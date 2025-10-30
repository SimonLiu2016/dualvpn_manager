import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'models/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'utils/tray_manager.dart';
import 'utils/logger.dart';
import 'utils/app_theme.dart';
import 'l10n/app_localizations_delegate.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 添加启动日志
  Logger.info('DualVPN Manager 正在启动...');

  // 初始化窗口管理器
  await _initWindowManager();

  runApp(const DualVPNAppWrapper());
}

class DualVPNAppWrapper extends StatefulWidget {
  const DualVPNAppWrapper({super.key});

  @override
  State<DualVPNAppWrapper> createState() => _DualVPNAppWrapperState();
}

class _DualVPNAppWrapperState extends State<DualVPNAppWrapper> {
  late final DualVPNTrayManager trayManager;
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    trayManager = DualVPNTrayManager();
    appState = AppState(trayManager: trayManager);

    // 延迟初始化托盘，确保所有依赖都已准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTray();
    });
  }

  Future<void> _initTray() async {
    try {
      await trayManager.initTray();
      Logger.info('系统托盘初始化完成');
    } catch (e) {
      Logger.error('系统托盘初始化失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: DualVPNApp(trayManager: trayManager),
    );
  }
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

        // 设置显示窗口的回调函数
        trayManager.setShowWindowCallback(() {
          Logger.info('通过回调函数显示窗口');
          // 使用window_manager显示窗口
          windowManager.show();
          windowManager.focus();
        });

        return MaterialApp(
          title: '双捷VPN管理器',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: appState.themeMode,
          navigatorKey: appState.navigatorKey,
          home: HomeScreen(),
          // 添加国际化支持
          locale: appState.language == 'en'
              ? const Locale('en', '')
              : appState.language == 'fr'
              ? const Locale('fr', '')
              : const Locale('zh', ''),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            // 自定义本地化代理
            _AppLocalizationsDelegate(),
            // Flutter内置的本地化代理
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // 如果设备语言不支持，则使用中文
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale != null) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
            }
            return const Locale('zh', ''); // 默认使用中文
          },
        );
      },
    );
  }
}

// 自定义本地化代理
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;

  @override
  List<Locale> get supportedLocales => const [
    Locale('zh', ''), // 简体中文
    Locale('en', ''), // 英文
    Locale('fr', ''), // 法文
  ];
}
