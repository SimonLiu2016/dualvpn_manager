import 'package:dualvpn_manager/l10n/app_fr.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:dualvpn_manager/models/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:dualvpn_manager/l10n/app_localizations_delegate.dart';
import 'package:dualvpn_manager/l10n/app_en.dart';
import 'package:dualvpn_manager/l10n/app_zh.dart';
import 'package:flutter/material.dart';

class DualVPNTrayManager with TrayListener {
  bool _isInitialized = false;
  VoidCallback? _showWindowCallback;
  AppState? _appState; // 添加AppState引用
  BuildContext? _context; // 添加BuildContext引用用于国际化
  String _currentLanguage = 'en'; // 默认语言设置为英文

  // 设置当前语言
  void setCurrentLanguage(String languageCode) {
    _currentLanguage = languageCode;
  }

  // 设置BuildContext引用
  void setContext(BuildContext context) {
    _context = context;
  }

  // 设置AppState引用
  void setAppState(AppState appState) {
    print('设置AppState引用: ${appState != null}');
    _appState = appState;
    if (_appState != null) {
      print(
        'AppState状态 - isStarting: ${_appState!.isStarting}, isGoProxyRunning: ${_appState!.isGoProxyRunning}',
      );
    }
  }

  // 设置显示窗口的回调函数
  void setShowWindowCallback(VoidCallback callback) {
    print('设置显示窗口回调函数: ${callback != null}');
    _showWindowCallback = callback;
  }

  // 获取本地化文本的安全方法，不依赖context
  String _getLocalizedText(String key, String fallback) {
    try {
      // 首先尝试通过context获取本地化文本
      if (_context != null) {
        try {
          return AppLocalizations.of(_context!).get(key);
        } catch (e) {
          print('通过context获取本地化文本失败: $e');
        }
      }

      // 如果context不可用或获取失败，使用内部本地化映射
      final Map<String, Map<String, String>> localizedValues = {
        'en': AppLocalizationsEn.localizedValues,
        'zh': AppLocalizationsZh.localizedValues,
        'fr': AppLocalizationsFr.localizedValues,
      };

      final values =
          localizedValues[_currentLanguage] ??
          AppLocalizationsEn.localizedValues;
      return values[key] ?? fallback;
    } catch (e) {
      print('获取本地化文本失败: $e');
    }
    return fallback; // 默认返回英文文本
  }

  Future<void> initTray() async {
    print('开始初始化托盘');
    if (_isInitialized) {
      print('托盘已初始化，跳过');
      return;
    }

    try {
      // 初始化系统托盘，使用PNG图标
      await trayManager.setIcon('assets/icons/app_icon_32.png');
      print('托盘图标设置完成');

      // 创建托盘菜单
      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'toggle_proxy',
            label: _getLocalizedText('tray_toggle_start', 'Start'),
            icon: _getIconPath('assets/icons/go_proxy_running.png'),
          ),
          MenuItem(
            key: 'show_window',
            label: _getLocalizedText('tray_show_window', 'Show Window'),
          ),
          MenuItem(key: 'separator1', label: ''),
          MenuItem(
            key: 'exit_app',
            label: _getLocalizedText('tray_exit_app', 'Exit App'),
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
      print('托盘菜单设置完成');

      // 先移除可能存在的旧监听器，再添加新的监听器
      trayManager.removeListener(this);
      trayManager.addListener(this);
      print('托盘事件监听器添加完成');

      _isInitialized = true;
      print('托盘初始化完成');
    } catch (e, stackTrace) {
      // 如果托盘初始化失败，不抛出异常，应用仍可正常运行
      print('托盘初始化失败: $e');
      print('堆栈跟踪: $stackTrace');
    }
  }

  // 获取图标的绝对路径
  String _getIconPath(String relativePath) {
    if (kIsWeb) return relativePath;

    // 对于桌面应用，尝试获取绝对路径
    try {
      // 获取可执行文件的目录
      String executableDir = path.dirname(Platform.resolvedExecutable);
      // 构建资源路径
      String assetPath = path.joinAll([
        executableDir,
        'data/flutter_assets',
        relativePath,
      ]);

      // 检查文件是否存在
      if (File(assetPath).existsSync()) {
        print('找到图标文件: $assetPath');
        return assetPath;
      } else {
        print('图标文件不存在: $assetPath');
      }
    } catch (e) {
      print('获取图标路径时出错: $e');
    }

    // 如果无法获取绝对路径，返回相对路径
    return relativePath;
  }

  @override
  void onTrayIconMouseDown() {
    print('托盘图标被点击（左键）');
    // 点击托盘图标时显示主窗口
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    print('托盘图标右键被点击');
    // 右键点击时更新菜单项并弹出菜单
    _updateContextMenu();
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    print('托盘图标右键释放');
  }

  @override
  void onTrayIconMouseUp() {
    print('托盘图标鼠标释放');
  }

  // 更新上下文菜单
  Future<void> _updateContextMenu() async {
    try {
      String toggleLabel = _getLocalizedText('tray_toggle_start', 'Start');
      String toggleIcon = _getIconPath('assets/icons/go_proxy_running.png');

      if (_appState != null) {
        print(
          'AppState状态检查 - isStarting: ${_appState!.isStarting}, isGoProxyRunning: ${_appState!.isGoProxyRunning}',
        );
        if (_appState!.isStarting) {
          toggleLabel = _getLocalizedText(
            'tray_toggle_starting',
            'Starting...',
          );
          toggleIcon = _getIconPath('assets/icons/starting.png');
        } else if (_appState!.isGoProxyRunning) {
          toggleLabel = _getLocalizedText('tray_toggle_stop', 'Stop');
          toggleIcon = _getIconPath('assets/icons/disconnected.png');
        } else {
          toggleLabel = _getLocalizedText('tray_toggle_start', 'Start');
          toggleIcon = _getIconPath('assets/icons/go_proxy_running.png');
        }
      } else {
        print('AppState为空，使用默认标签');
      }

      print('更新托盘菜单项: $toggleLabel');

      // 创建更新后的菜单
      Menu menu = Menu(
        items: [
          MenuItem(key: 'toggle_proxy', label: toggleLabel, icon: toggleIcon),
          MenuItem(
            key: 'show_window',
            label: _getLocalizedText('tray_show_window', 'Show Window'),
          ),
          MenuItem(key: 'separator1', label: ''),
          MenuItem(
            key: 'exit_app',
            label: _getLocalizedText('tray_exit_app', 'Exit App'),
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
      print('托盘菜单更新完成');
    } catch (e, stackTrace) {
      print('更新托盘菜单失败: $e');
      print('堆栈跟踪: $stackTrace');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    print('菜单项被点击: key=${menuItem.key}, label=${menuItem.label}');
    // 使用Future.microtask确保在下一个事件循环中执行
    Future.microtask(() {
      switch (menuItem.key) {
        case 'toggle_proxy':
          // 启动/停止Go代理核心
          print('点击了启动/停止菜单项');
          _toggleProxy();
          break;
        case 'show_window':
          // 显示主窗口
          print('点击了显示主窗口菜单项');
          _showWindow();
          break;
        case 'exit_app':
          // 退出应用前关闭Go代理核心服务并清除系统代理设置
          print('点击了退出应用菜单项');
          _exitApp();
          break;
        default:
          print('未知的菜单项: ${menuItem.key}');
      }
    });
  }

  // 启动/停止Go代理核心
  void _toggleProxy() async {
    print('切换代理核心状态');
    if (_appState != null) {
      try {
        print(
          '当前AppState状态 - isGoProxyRunning: ${_appState!.isGoProxyRunning}',
        );
        if (_appState!.isGoProxyRunning) {
          print('停止Go代理核心');
          // 停止Go代理核心
          await _appState!.stopGoProxy();
        } else {
          print('启动Go代理核心');
          // 启动Go代理核心
          await _appState!.startGoProxy();
        }
        // 更新菜单
        await _updateContextMenu();
      } catch (e, stackTrace) {
        print('切换代理核心状态失败: $e');
        print('堆栈跟踪: $stackTrace');
      }
    } else {
      print('AppState为空，无法切换代理核心状态');
    }
  }

  // 退出应用
  void _exitApp() async {
    print('退出应用');
    try {
      if (_appState != null) {
        // 停止Go代理核心
        await _appState!.stopGoProxy();
      }
    } catch (e, stackTrace) {
      print('退出应用时清理资源失败: $e');
      print('堆栈跟踪: $stackTrace');
    } finally {
      // 退出应用
      exit(0);
    }
  }

  // 显示主窗口
  void _showWindow() {
    print('显示主窗口');
    print('回调函数是否存在: ${_showWindowCallback != null}');
    print('AppState是否存在: ${_appState != null}');
    // 如果设置了回调函数，优先使用回调函数
    if (_showWindowCallback != null) {
      print('使用回调函数显示窗口');
      _showWindowCallback!();
    } else {
      print('使用默认方法显示窗口');
      // 否则使用默认的窗口管理器方法
      windowManager.show();
      windowManager.focus();
    }

    // 在macOS上确保程序坞图标显示
    if (Platform.isMacOS) {
      _showDockIcon();
    }
  }

  // 显示程序坞图标 (macOS专用)
  void _showDockIcon() {
    if (Platform.isMacOS) {
      try {
        const MethodChannel macosChannel = MethodChannel(
          'dualvpn_manager/macos',
        );
        macosChannel.invokeMethod('showDockIcon');
        print('调用显示程序坞图标方法');
      } catch (e) {
        developer.log('调用显示程序坞图标方法失败: $e');
        print('调用显示程序坞图标方法失败: $e');
      }
    }
  }

  Future<void> updateTrayIcon(
    bool openVPNConnected,
    bool clashConnected, {
    bool starting = false,
  }) async {
    print(
      '更新托盘图标: openVPN=$openVPNConnected, clash=$clashConnected, starting=$starting',
    );
    print('AppState是否存在: ${_appState != null}');
    if (_appState != null) {
      print(
        'AppState状态 - isStarting: ${_appState!.isStarting}, isGoProxyRunning: ${_appState!.isGoProxyRunning}',
      );
    }
    // 根据连接状态更新托盘图标
    String iconPath = 'assets/icons/app_icon_32.png'; // 默认图标

    // 检查是否处于启动中状态
    if (starting) {
      // 启动中状态，使用启动中图标
      iconPath = 'assets/icons/starting.png';
    } else if (_appState != null && _appState!.isGoProxyRunning) {
      // 检查Go代理核心是否运行，如果运行则使用特殊的图标
      if (openVPNConnected && clashConnected) {
        iconPath = 'assets/icons/connected.png';
      } else if (openVPNConnected) {
        iconPath = 'assets/icons/go_openvpn_connected.png';
      } else if (clashConnected) {
        iconPath = 'assets/icons/go_clash_connected.png';
      } else {
        iconPath = 'assets/icons/go_proxy_running.png';
      }
    } else {
      // Go代理核心未运行，使用原来的图标逻辑
      if (openVPNConnected && clashConnected) {
        iconPath = 'assets/icons/both_connected.png';
      } else if (openVPNConnected) {
        iconPath = 'assets/icons/openvpn_connected.png';
      } else if (clashConnected) {
        iconPath = 'assets/icons/clash_connected.png';
      } else {
        iconPath = 'assets/icons/disconnected.png';
      }
    }

    try {
      // 检查图标文件是否存在
      if (await File(iconPath).exists()) {
        await trayManager.setIcon(iconPath);
      } else {
        // 如果特定图标不存在，使用默认图标
        await trayManager.setIcon('assets/icons/app_icon_32.png');
      }

      // 添加一个短暂的动画效果（仅在连接成功时）
      if (!starting &&
          (openVPNConnected ||
              clashConnected ||
              (_appState != null && _appState!.isGoProxyRunning))) {
        // 模拟连接动画
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          await trayManager.setIcon('assets/icons/app_icon_32.png');
          await Future.delayed(const Duration(milliseconds: 200));
          await trayManager.setIcon(iconPath);
        }
      }

      // 更新托盘菜单
      await _updateContextMenu();
    } catch (e, stackTrace) {
      // 如果更新托盘图标失败，不抛出异常
      print('更新托盘图标失败: $e');
      print('堆栈跟踪: $stackTrace');
    }
  }

  Future<void> destroyTray() async {
    try {
      trayManager.removeListener(this); // 移除监听器
      await trayManager.destroy();
      _isInitialized = false;
      print('托盘销毁完成');
    } catch (e, stackTrace) {
      // 如果销毁托盘失败，不抛出异常
      print('销毁托盘失败: $e');
      print('堆栈跟踪: $stackTrace');
    }
  }

  // 检查托盘是否已初始化
  bool get isInitialized => _isInitialized;
}
